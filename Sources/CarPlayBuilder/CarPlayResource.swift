// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation
import Observation

/// Shared loading state for app-provided asynchronous data.
/// Concurrent callers await the same request. Screen disappearance does not cancel
/// that shared request; its owner can call `cancel()` explicitly.
@MainActor
@Observable
public final class CarPlayResource<Value> {

    /// The most recent successful value, retained during refreshes and failures.
    public private(set) var value: Value?
    /// The observable request state, initially idle.
    ///
    /// Failures retain their underlying error; cancellation restores idle or loaded
    /// according to whether a successful value exists.
    public private(set) var state: CarPlayLoadState = .idle
    @ObservationIgnored
    private let loader: @MainActor () async throws -> Value
    @ObservationIgnored
    private var task: Task<Void, Never>?
    @ObservationIgnored
    private var generation = 0

    /// Creates an initially idle resource with an application-provided loader.
    ///
    /// - Parameter load: Main-actor asynchronous work returning the value. Keep
    ///   blocking work off the main actor and cooperate with cancellation.
    public init(load: @escaping @MainActor () async throws -> Value) {

        self.loader = load
    }

    isolated deinit {

        self.task?.cancel()
    }

    /// Loads once, or joins an existing request. Failures require an explicit retry.
    public func loadIfNeeded() async {

        if self.task != nil {

            await self.reload()
            return
        }

        guard case .idle = self.state else {

            return
        }

        await self.reload()
    }

    /// Refreshes the value, joining an existing request rather than duplicating it.
    public func reload() async {

        guard !Task.isCancelled else {

            return
        }

        if let task {

            await task.value
            return
        }
        self.generation += 1
        self.state = .loading
        let task = self.makeTask(generation: self.generation)
        self.task = task
        await task.value
    }

    /// Cancels the shared request and prevents its result from being published.
    ///
    /// The last successful value remains available. State becomes loaded when a
    /// value exists, or idle otherwise. Call this on the resource owner; cancelling
    /// a screen task waiting for the resource does not cancel the shared request.
    public func cancel() {

        self.generation += 1
        self.task?.cancel()
        self.task = nil
        self.state = self.value == nil ? .idle : .loaded
    }
}

private extension CarPlayResource {

    func makeTask(generation: Int) -> Task<Void, Never> {

        let loader = self.loader
        return Task { [weak self] in

            do {

                let value = try await loader()
                try Task.checkCancellation()
                self?.complete(value, generation: generation)
            } catch {

                self?.fail(error, generation: generation)
            }
        }
    }

    func complete(_ value: Value, generation: Int) {

        guard self.generation == generation else {

            return
        }

        self.value = value
        self.state = .loaded
        self.task = nil
    }

    func fail(_ error: Error, generation: Int) {

        guard self.generation == generation else {

            return
        }

        if Task.isCancelled || error is CancellationError {

            self.state = self.value == nil ? .idle : .loaded
        } else {

            self.state = .failed(error)
        }
        self.task = nil
    }
}
