// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Testing
@testable import CarPlayBuilder

/// Covers request coalescing, retained values, errors, and stale-result rejection.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayResourceTests {

    @Test
    func `concurrent loads share one request`() async {

        let loader = ResourceLoader()
        let resource = CarPlayResource { try await loader.load() }
        let first = Task { await resource.reload() }
        await loader.started()
        let joining = AsyncStream<Void>.makeStream()
        let second = Task {

            joining.continuation.yield(())
            await resource.loadIfNeeded()
        }
        var iterator = joining.stream.makeAsyncIterator()
        _ = await iterator.next()
        loader.finish(0, with: .success(42))
        await first.value
        await second.value
        #expect(loader.count == 1)
        #expect(resource.value == 42)
        await resource.loadIfNeeded()
        #expect(loader.count == 1)
    }

    @Test
    func `explicit cancellation discards late results from an old generation`(
    ) async {

        let loader = ResourceLoader()
        let resource = CarPlayResource { try await loader.load() }
        let first = Task { await resource.reload() }
        await loader.started()
        resource.cancel()
        let second = Task { await resource.reload() }
        await loader.started()
        loader.finish(1, with: .success(2))
        await second.value
        loader.finish(0, with: .success(1))
        await first.value
        #expect(resource.value == 2)
        if case .loaded = resource.state {} else {

            Issue.record("Late completion replaced the loaded state")
        }
    }

    @Test
    func `failures retain their error and retry explicitly`() async {

        var calls = 0
        let resource = CarPlayResource {

            calls += 1
            if calls == 1 {

                throw ResourceFailure.expired
            }
            return 7
        }
        await resource.loadIfNeeded()
        if case let .failed(error) = resource.state {

            #expect(error as? ResourceFailure == .expired)
        } else {

            Issue.record("Expected the original failure")
        }
        await resource.loadIfNeeded()
        #expect(calls == 1)
        await resource.reload()
        #expect(resource.value == 7)
        #expect(calls == 2)
    }

    @Test
    func `failed refresh retains the previous successful value`() async {

        var calls = 0
        let resource = CarPlayResource {

            calls += 1
            if calls > 1 {

                throw ResourceFailure.expired
            }
            return 9
        }
        await resource.loadIfNeeded()
        await resource.reload()
        #expect(resource.value == 9)
        resource.cancel()
        if case .loaded = resource.state {} else {

            Issue.record("Cancellation should restore the cached value state")
        }
    }

    @Test
    func `cancelling one consumer does not cancel the shared resource`() async {

        let loader = ResourceLoader()
        let resource = CarPlayResource { try await loader.load() }
        let consumer = Task { await resource.loadIfNeeded() }
        await loader.started()
        consumer.cancel()
        loader.finish(0, with: .success(8))
        await consumer.value
        #expect(resource.value == 8)
    }

    @Test(arguments: [false, true])
    func `loader cancellation restores the previous state`(cached: Bool) async {

        var attempts = 0
        let resource = CarPlayResource {

            attempts += 1
            if cached, attempts == 1 {

                return 7
            }
            throw CancellationError()
        }
        if cached {

            await resource.loadIfNeeded()
        }
        await resource.reload()
        #expect(resource.value == (cached ? 7 : nil))
        if cached {

            guard case .loaded = resource.state else {

                Issue.record("Cached state was lost")
                return
            }
        } else {

            guard case .idle = resource.state else {

                Issue.record("Cancellation became a failure")
                return
            }
        }
    }

    @Test
    func `already cancelled consumers do not start a resource request`() async {

        var calls = 0
        let resource = CarPlayResource { calls += 1
            return 1
        }
        let consumer = Task { await resource.reload() }
        consumer.cancel()
        await consumer.value
        #expect(calls == 0)
        #expect(resource.value == nil)
    }
}

private extension CarPlayResourceTests {

    @MainActor
    final class ResourceLoader {

        private var requests: [CheckedContinuation<Int, any Error>] = []
        private let events = AsyncStream<Void>.makeStream()
        var count: Int {

            self.requests.count
        }

        func load() async throws -> Int {

            try await withCheckedThrowingContinuation { continuation in

                self.requests.append(continuation)
                self.events.continuation.yield(())
            }
        }

        func started() async {

            var iterator = self.events.stream.makeAsyncIterator()
            _ = await iterator.next()
        }

        func finish(_ index: Int, with result: Result<Int, any Error>) {

            self.requests[index].resume(with: result)
        }
    }

    enum ResourceFailure: Error {

        case expired
    }
}
