// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Observation
import Testing
import UIKit
@testable import CarPlayBuilder

/// Covers observable state, placeholders, refresh sharing, and invalidation races.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayArtworkStateTests {

    @Test
    func `existing image lookup method references remain usable`() {

        let store = CarPlayArtworkStore()
        let lookup: @MainActor (URL?, UIImage?) -> UIImage? =
            store.image(for:placeholder:)
        let placeholder = UIImage()
        #expect(lookup(nil, placeholder) === placeholder)
    }

    @Test
    func `state moves from idle through loading to a cached image`() async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests)
        let url = try self.url(0)
        let image = UIImage()
        #expect(self.isIdle(store.state(for: nil)))
        #expect(self.isIdle(store.state(for: url)))
        let load = Task { await store.loadImage(from: url) }
        await requests.started()
        #expect(self.isLoading(store.state(for: url)))
        requests.finish(0, with: .success(image))
        await load.value
        #expect(self.isLoaded(store.state(for: url)))
        #expect(store.image(for: url, failurePlaceholder: UIImage()) === image)
        await store.loadImage(from: url)
        #expect(requests.count == 1)
    }

    @Test
    func `failures select their placeholder and can be retried`(
    ) async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests)
        let url = try self.url(0)
        let failure = ArtworkFailure()
        let placeholder = UIImage()
        let failed = UIImage()
        let load = Task { await store.loadImage(from: url) }
        await requests.started()
        requests.finish(0, with: .failure(failure))
        await load.value
        let error = try #require(self.failure(store.state(for: url)))
        #expect(error as? ArtworkFailure === failure)
        #expect(store.image(for: url, placeholder: placeholder) === placeholder)
        #expect(store.image(for: url, failurePlaceholder: failed) === failed)
        #expect(store.image(for: nil, failurePlaceholder: failed) == nil)
        let retry = Task { await store.loadImage(from: url) }
        await requests.started()
        #expect(self.isLoading(store.state(for: url)))
        #expect(store.image(
            for: url,
            placeholder: placeholder,
            failurePlaceholder: failed
        ) === placeholder)
        requests.finish(1, with: .success(UIImage()))
        await retry.value
        #expect(self.isLoaded(store.state(for: url)))
    }

    @Test
    func `reload refreshes artwork and shares concurrent work`() async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests)
        let url = try self.url(0)
        let first = Task { await store.loadImage(from: url) }
        await requests.started()
        requests.finish(0, with: .success(UIImage()))
        await first.value
        let reload = Task { await store.reloadImage(from: url) }
        await requests.started()
        #expect(store.image(for: url) == nil)
        let joined = await self.join(store, url: url, reload: true)
        #expect(requests.count == 2)
        let replacement = UIImage()
        requests.finish(1, with: .success(replacement))
        await reload.value
        await joined.value
        #expect(store.image(for: url) === replacement)
    }

    @Test(arguments: [false, true])
    func `invalidation resumes shared consumers and rejects stale completion`(
        all: Bool
    ) async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests, maximumConcurrentLoads: 1)
        let url = try self.url(0)
        let first = Task { await store.loadImage(from: url) }
        await requests.started()
        let shared = await self.join(store, url: url)
        if all {

            store.invalidateAllImages()
        } else {

            store.invalidateImage(for: url)
        }
        await first.value
        await shared.value
        #expect(self.isIdle(store.state(for: url)))
        let fresh = await self.join(store, url: url)
        #expect(requests.count == 1, "Cancelled loaders retain their active slot")
        requests.finish(0, with: .success(UIImage()))
        await requests.started()
        #expect(store.image(for: url) == nil)
        #expect(self.isLoading(store.state(for: url)))
        let replacement = UIImage()
        requests.finish(1, with: .success(replacement))
        await fresh.value
        #expect(store.image(for: url) === replacement)
    }

    @Test
    func `clear all removes cached failures and cancels queued work`() async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests, maximumConcurrentLoads: 1)
        let urls = try (0 ..< 4).map(self.url)
        for index in 0 ..< 2 {

            let load = Task { await store.loadImage(from: urls[index]) }
            await requests.started()
            requests.finish(
                index,
                with: index == 0
                    ? .success(UIImage()) : .failure(ArtworkFailure())
            )
            await load.value
        }
        let active = Task { await store.loadImage(from: urls[2]) }
        await requests.started()
        let queued = await self.join(store, url: urls[3])
        #expect(self.isLoading(store.state(for: urls[3])))
        store.invalidateAllImages()
        await active.value
        await queued.value
        #expect(urls.allSatisfy { self.isIdle(store.state(for: $0)) })
        #expect(urls.allSatisfy { store.image(for: $0) == nil })
        requests.finish(2, with: .success(UIImage()))
        let fresh = Task { await store.loadImage(from: urls[0]) }
        await requests.started()
        #expect(requests.count == 4, "Invalidated queued work must not start")
        requests.finish(3, with: .success(UIImage()))
        await fresh.value
    }

    @Test
    func `invalidating one cached image preserves other URLs`() async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests)
        let urls = try (0 ..< 2).map(self.url)
        for index in 0 ..< 2 {

            let task = Task { await store.loadImage(from: urls[index]) }
            await requests.started()
            requests.finish(index, with: .success(UIImage()))
            await task.value
        }
        let retained = store.image(for: urls[1])
        store.invalidateImage(for: urls[0])
        #expect(self.isIdle(store.state(for: urls[0])))
        #expect(store.image(for: urls[1]) === retained)
    }

    @Test
    func `cancelled consumers return to idle without a failure`() async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests)
        let url = try self.url(0)
        let load = Task { await store.loadImage(from: url) }
        await requests.started()
        load.cancel()
        await load.value
        #expect(self.isIdle(store.state(for: url)))
        requests.finish(0, with: .failure(ArtworkFailure()))
        let retry = Task { await store.loadImage(from: url) }
        await requests.started()
        requests.finish(1, with: .failure(CancellationError()))
        await retry.value
        #expect(self.isIdle(store.state(for: url)))
    }

    @Test
    func `cancelled reload leaves cached artwork intact`() async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests)
        let url = try self.url(0)
        let image = UIImage()
        let load = Task { await store.loadImage(from: url) }
        await requests.started()
        requests.finish(0, with: .success(image))
        await load.value
        let reload = Task { await store.reloadImage(from: url) }
        reload.cancel()
        await reload.value
        #expect(store.image(for: url) === image)
        #expect(requests.count == 1)
    }

    @Test
    func `invalidation during loading notification resumes the consumer`(
    ) async throws {

        let requests = Requests()
        let pipeline = CarPlayArtworkPipeline(loader: requests, size: .zero)
        let url = try self.url(0)
        pipeline.onChange = {

            pipeline.onChange = nil
            pipeline.invalidateImage(for: url)
        }
        await pipeline.loadImage(from: url)
        #expect(self.isIdle(pipeline.state(for: url)))
        #expect(requests.isEmpty)
    }

    @Test(arguments: [false, true])
    func `completion and invalidation notify observers`(failed: Bool) async throws {

        let requests = Requests()
        let store = CarPlayArtworkStore(loader: requests)
        let url = try self.url(0)
        let task = Task { await store.loadImage(from: url) }
        await requests.started()
        await confirmation { changed in

            withObservationTracking { _ = store.state(for: url) } onChange: {

                changed()
            }
            requests.finish(
                0,
                with: failed
                    ? .failure(ArtworkFailure()) : .success(UIImage())
            )
            await task.value
        }
        await confirmation { changed in

            withObservationTracking { _ = store.image(for: url) } onChange: {

                changed()
            }
            store.invalidateImage(for: url)
        }
    }
}

private extension CarPlayArtworkStateTests {

    func url(_ index: Int) throws -> URL {

        try #require(URL(string: "https://example.com/image/\(index)"))
    }

    func isIdle(_ state: CarPlayLoadState) -> Bool {

        if case .idle = state {
            return true
        }
        return false
    }

    func isLoading(_ state: CarPlayLoadState) -> Bool {

        if case .loading = state {
            return true
        }
        return false
    }

    func isLoaded(_ state: CarPlayLoadState) -> Bool {

        if case .loaded = state {
            return true
        }
        return false
    }

    func failure(_ state: CarPlayLoadState) -> (any Error)? {

        if case let .failed(error) = state {
            return error
        }
        return nil
    }

    func join(
        _ store: CarPlayArtworkStore,
        url: URL,
        reload: Bool = false
    ) async -> Task<Void, Never> {

        let entered = AsyncStream<Void>.makeStream()
        let task = Task {

            entered.continuation.yield(())
            if reload {

                await store.reloadImage(from: url)
            } else {

                await store.loadImage(from: url)
            }
        }
        var iterator = entered.stream.makeAsyncIterator()
        _ = await iterator.next()
        return task
    }

    final class ArtworkFailure: Error {}

    @MainActor
    final class Requests: CarPlayArtworkLoading {

        private let events = AsyncStream<Void>.makeStream()
        private var requests: [CheckedContinuation<UIImage, any Error>] = []
        var count: Int {

            self.requests.count
        }

        var isEmpty: Bool {

            self.requests.isEmpty
        }

        func loadImage(from url: URL, size: CGSize) async throws -> UIImage {

            try await withCheckedThrowingContinuation { continuation in

                self.requests.append(continuation)
                self.events.continuation.yield(())
            }
        }

        func started() async {

            var iterator = self.events.stream.makeAsyncIterator()
            _ = await iterator.next()
        }

        func finish(_ index: Int, with result: Result<UIImage, any Error>) {

            self.requests[index].resume(with: result)
        }
    }
}
