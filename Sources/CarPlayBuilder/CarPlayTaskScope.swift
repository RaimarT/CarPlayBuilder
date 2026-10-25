// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation

/// Owns visibility-bound work and selection tasks for one mounted screen.
///
/// Lifecycle tasks are keyed by modifier position and ID. Completed tasks stay
/// registered to avoid restarting on ordinary renders. Selection completion
/// runs even after failure or cancellation.
@MainActor
final class CarPlayTaskScope {

    private var lifecycle: [Int: RunningTask] = [:]
    private var actions: [UUID: Task<Void, Never>] = [:]
    private let onError: CarPlayContextualErrorHandler
    var screenID: UUID?
    var screenTitle: String?

    init(
        onError: @escaping CarPlayErrorHandler = { _ in },
        onErrorWithContext: CarPlayContextualErrorHandler? = nil
    ) {

        self.onError = onErrorWithContext ?? { error, _ in onError(error) }
    }

    isolated deinit {

        for entry in lifecycle.values {

            entry.task.cancel()
        }

        for task in actions.values {

            task.cancel()
        }
    }

    /// Reconciles task definitions against visibility, modifier position, and ID.
    func update(
        _ definitions: [CarPlayTemplateContent.LifecycleTask],
        visible: Bool
    ) {

        for index in Array(self.lifecycle.keys) {

            if !visible || !definitions.indices.contains(index) || self
                .lifecycle[index]?.id != definitions[index].id {

                self.lifecycle.removeValue(forKey: index)?.task.cancel()
            }
        }

        guard visible else {

            return
        }

        for (index, definition) in definitions.enumerated()
            where self.lifecycle[index] == nil {

            // Retain completed tasks too: re-rendering must not repeat the same task
            // ID.
            self.lifecycle[index] = RunningTask(
                id: definition.id,
                task: self.makeTask(definition)
            )
        }
    }

    /// Retains a selection action and always calls its native completion handler.
    func perform(
        _ action: @escaping CarPlayTaskAction,
        control: CarPlayErrorControl? = nil,
        controlID: AnyHashable? = nil,
        completion: @escaping CarPlayCallback = {}
    ) {

        let id = UUID()
        let context = CarPlayErrorContext(
            source: .action,
            screenID: self.screenID,
            screenTitle: self.screenTitle,
            control: control,
            controlID: controlID
        )

        self.actions[id] = Task { [weak self, onError] in

            defer {

                completion()
                self?.actions[id] = nil
            }

            do {

                try Task.checkCancellation()
                try await action()
            } catch {

                if !Task.isCancelled, !(error is CancellationError) {

                    onError(error, context)
                }
            }
        }
    }

    /// Cancels lifecycle and selection work without reporting normal cancellation.
    func cancel() {

        self.update([], visible: false)
        for task in self.actions.values {

            task.cancel()
        }
        self.actions.removeAll()
    }
}

private extension CarPlayTaskScope {

    func makeTask(
        _ definition: CarPlayTemplateContent
            .LifecycleTask
    ) -> Task<Void, Never> {

        let context = CarPlayErrorContext(
            source: .lifecycleTask,
            screenID: self.screenID,
            screenTitle: self.screenTitle,
            taskID: definition.id
        )

        return Task(priority: definition.priority) { [onError] in

            do {

                try Task.checkCancellation()
                try await definition.action()
            } catch {

                if !Task.isCancelled, !(error is CancellationError) {

                    onError(error, context)
                }
            }
        }
    }
}

private extension CarPlayTaskScope {

    /// Retains a lifecycle task’s ID after completion to suppress repeated work.
    struct RunningTask {

        let id: AnyHashable
        let task: Task<Void, Never>
    }
}
