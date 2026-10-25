// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Testing
import UIKit
@testable import CarPlayBuilder

/// Covers request modification, size hints, transport, and decode errors.
@MainActor
struct CarPlayArtworkRequestTests {

    private let url: URL
    private let size = CGSize(width: 80, height: 80)

    init() throws {

        let source = "https://example.com/cover.png?v=1"
        self.url = try #require(URL(string: source))
    }

    @Test
    func `async modifier controls the request sent to the transport`() async throws {

        var received: URLRequest?
        let loader = CarPlayArtworkLoader(requestModifier: { request, size in

            Self.expectOffMainThread()
            #expect(request.url == self.url)
            #expect(size == self.size)
            await Task.yield()
            var request = request
            request.url = self.url.appendingPathComponent("w80")
            request.setValue("Bearer test", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            return request
        }, fetch: { request in

            received = request
            return try self.response(for: request)
        })
        _ = try await loader.loadImage(from: self.url, size: self.size)
        #expect(received?.url == self.url.appendingPathComponent("w80"))
        #expect(received?
            .value(forHTTPHeaderField: "Authorization") == "Bearer test")
        #expect(received?.timeoutInterval == 15)
        #expect(received?.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test
    func `modifier failure prevents transport and preserves the error`() async {

        var fetches = 0
        let loader = CarPlayArtworkLoader(requestModifier: { _, _ in

            throw RequestFailure.expected
        }, fetch: { request in

            fetches += 1
            return try self.response(for: request)
        })
        await #expect(throws: RequestFailure.expected) {

            try await loader.loadImage(from: self.url, size: self.size)
        }
        #expect(fetches == 0)
    }

    @Test
    func `cancellation during modification prevents transport`() async {

        var fetches = 0
        let loader = CarPlayArtworkLoader(requestModifier: { request, _ in

            withUnsafeCurrentTask { $0?.cancel() }
            return request
        }, fetch: { request in

            fetches += 1
            return try self.response(for: request)
        })
        let task = Task {

            try await loader.loadImage(from: self.url, size: self.size)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(fetches == 0)
    }
}

private extension CarPlayArtworkRequestTests {

    func response(for request: URLRequest) throws -> (Data, URLResponse) {

        let data = try #require(UIImage(systemName: "music.note")?.pngData())
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        return (data, response)
    }
}

private extension CarPlayArtworkRequestTests {

    enum RequestFailure: Error {

        case expected
    }
}

private extension CarPlayArtworkRequestTests {

    /// Samples the current executor thread before the async modifier suspends.
    nonisolated static func expectOffMainThread() {

        #expect(Thread.isMainThread == false)
    }
}
