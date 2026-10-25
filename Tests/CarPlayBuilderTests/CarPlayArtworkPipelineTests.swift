// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Testing
import UIKit
@testable import CarPlayBuilder

/// Covers shared requests, concurrency limits, and consumer cancellation.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayArtworkPipelineTests {

    @Test(arguments: [0, 1, 2, 4])
    func `overlapping batches share requests and one concurrency limit`(
        configuredLimit: Int
    ) async throws {

        let request = try SuspendedArtworkRequest()
        let limit = max(1, configuredLimit)
        let store = CarPlayArtworkPipeline(
            loader: request.loader,
            size: CGSize(width: 80, height: 80),
            maximumConcurrentLoads: configuredLimit
        )
        let urls = try self.urls(count: 6)
        let first = Task { await store.loadImages(from: urls) }
        let second = Task { await store.loadImages(from: urls) }
        for _ in 0 ..< limit {

            await request.started()
        }
        #expect(request.count == limit)
        await self.finishRequests(request, count: 6, limit: limit)
        await first.value
        await second.value
        #expect(request.count == 6)
        #expect(request.peak == limit)
        #expect(urls.allSatisfy { store.image(for: $0) != nil })
    }

    @Test
    func `cancelled request cannot insert artwork and the URL can be retried`() async
        throws {

        let request = try SuspendedArtworkRequest()
        let store = CarPlayArtworkPipeline(
            loader: request.loader,
            size: CGSize(width: 80, height: 80)
        )
        let urls = try self.urls(count: 1)
        let first = Task { await store.loadImages(from: urls) }
        await request.started()
        first.cancel()
        await first.value
        #expect(store.image(for: urls[0]) == nil)
        let retry = Task { await store.loadImages(from: urls) }
        await request.started()
        request.finish(0 ..< 1)
        #expect(store.image(for: urls[0]) == nil)
        request.finish(1 ..< 2)
        await retry.value
        #expect(request.count == 2)
        #expect(store.image(for: urls[0]) != nil)
    }

    @Test
    func `cancelling one consumer preserves a shared request`() async throws {

        let request = try SuspendedArtworkRequest()
        let store = CarPlayArtworkPipeline(
            loader: request.loader,
            size: CGSize(width: 80, height: 80)
        )
        let urls = try self.urls(count: 1)
        let first = Task { await store.loadImage(from: urls[0]) }
        await request.started()
        let joined = AsyncStream<Void>.makeStream()
        let second = Task {

            joined.continuation.yield(())
            await store.loadImage(from: urls[0])
        }
        var iterator = joined.stream.makeAsyncIterator()
        _ = await iterator.next()
        first.cancel()
        await first.value
        request.finish(0 ..< 1)
        await second.value
        #expect(request.count == 1)
        #expect(store.image(for: urls[0]) != nil)
    }
}

private extension CarPlayArtworkPipelineTests {

    func finishRequests(
        _ request: SuspendedArtworkRequest,
        count: Int,
        limit: Int
    ) async {

        for start in stride(from: 0, to: count, by: limit) {

            request.finish(start ..< min(start + limit, count))
            let nextCount = min(limit, max(0, count - start - limit))
            for _ in 0 ..< nextCount {

                await request.started()
            }
        }
    }

    func urls(count: Int) throws -> [URL] {

        try (0 ..< count).map {

            try #require(URL(string: "https://images.example.com/asset/\($0).png"))
        }
    }
}

private extension CarPlayArtworkPipelineTests {

    @MainActor
    final class SuspendedArtworkRequest {

        private let data: Data
        private let events = AsyncStream<Void>.makeStream()
        private var requests: [CheckedContinuation<Void, Never>] = []
        private var running = 0
        private(set) var peak = 0
        var count: Int {

            self.requests.count
        }

        init() throws {

            self.data = try #require(UIImage(systemName: "music.note")?.pngData())
        }

        var loader: CarPlayArtworkLoader {

            CarPlayArtworkLoader(fetch: { request in

                guard let url = request.url else {

                    throw URLError(.badURL)
                }

                self.running += 1
                self.peak = max(self.peak, self.running)
                await withCheckedContinuation { continuation in

                    self.requests.append(continuation)
                    self.events.continuation.yield(())
                }
                self.running -= 1
                let response = try #require(HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (self.data, response)
            })
        }

        func started() async {

            var iterator = self.events.stream.makeAsyncIterator()
            _ = await iterator.next()
        }

        func finish(_ range: Range<Int>) {

            for index in range {

                self.requests[index].resume()
            }
        }
    }
}
