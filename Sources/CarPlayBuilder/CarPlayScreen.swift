// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation

/// Owns a mounted root and observation registration for one navigation screen.
///
/// Evaluating content tracks dependencies. Each change schedules a main-actor
/// refresh after mutation; cancellation detaches future observation callbacks.
@MainActor
final class CarPlayScreen {

    let node: CarPlayMountedTemplate
    private let content: CarPlayContentProvider
    private let observation: ScreenObservation
    private var active = true

    init(
        content: @escaping CarPlayContentProvider,
        context: CarPlayContext,
        onError: @escaping CarPlayErrorHandler = { _ in },
        onErrorWithContext: CarPlayContextualErrorHandler? = nil
    ) throws {

        let observation = ScreenObservation()
        self.content = content
        self.observation = observation
        self.node = try CarPlayMountedTemplate(
            content: observation.track(content),
            context: context,
            onError: onError,
            onErrorWithContext: onErrorWithContext
        )
        observation.screen = self
    }

    /// Detaches observation and cancels the mounted subtree.
    func cancel() {

        self.active = false
        self.observation.screen = nil
        self.node.cancel()
    }
}

private extension CarPlayScreen {

    /// Re-evaluates observed content and routes rejected updates to the screen.
    func refresh() {

        guard self.active else {

            return
        }

        do {

            let content = self.observation.track(self.content)
            try self.node.update(content)
        } catch {

            self.node.reportError(error)
        }
    }
}

private extension CarPlayScreen {

    /// Registers the initial observation before a screen can safely capture itself.
    @MainActor
    final class ScreenObservation {

        weak var screen: CarPlayScreen?
        private var revision = 0

        func track(_ content: CarPlayContentProvider) -> CarPlayTemplateContent {

            self.revision += 1
            let revision = self.revision

            return withObservationTracking(content) { [weak self] in

                // Observation reports before mutation; read on the next actor turn.
                Task { @MainActor [weak self] in

                    guard let self, self.revision == revision else {

                        return
                    }

                    self.screen?.refresh()
                }
            }
        }
    }
}
