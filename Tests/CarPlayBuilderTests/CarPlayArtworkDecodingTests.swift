// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Testing
import UIKit
@testable import CarPlayBuilder

/// Checks decoder injection, off-main execution, cancellation, and caching.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayArtworkDecodingTests {

    private let url: URL
    private let size = CGSize(width: 80, height: 80)
    private let data: Data

    init() throws {

        self.url = try #require(URL(string: "https://example.com/cover.png"))
        self.data = try #require(UIImage(systemName: "music.note")?.pngData())
    }

    @Test
    func `main actor loads create and prepare images off the main thread`() async
        throws {

        try await confirmation("Both decoding operations run", expectedCount: 2) {
            decoded in

            let loader = CarPlayArtworkLoader(imageDecoder: { data in

                #expect(Thread.isMainThread == false)
                let image = try #require(UIImage(data: data))
                decoded()
                #expect(Thread.isMainThread == false)
                let prepared = try #require(image.preparingForDisplay())
                decoded()

                return prepared
            }, fetch: { _ in

                try self.response()
            })
            let image = try await loader.loadImage(from: self.url, size: self.size)
            #expect(image.cgImage != nil)
        }
    }

    @Test
    func `custom decoder failures preserve their original error`() async {

        let loader = CarPlayArtworkLoader(imageDecoder: { _ in

            throw DecodeFailure.expected
        }, fetch: { _ in

            try self.response()
        })
        await #expect(throws: DecodeFailure.expected) {

            try await loader.loadImage(from: self.url, size: self.size)
        }
    }

    @Test
    func `cancellation during decoding prevents image modification`() async {

        await confirmation("Cancelled images are not modified", expectedCount: 0) {
            modified in

            let loader = CarPlayArtworkLoader(imageDecoder: { _ in

                withUnsafeCurrentTask { $0?.cancel() }

                return UIImage()
            }, imageModifier: { image, _ in

                modified()

                return image
            }, fetch: { _ in

                try self.response()
            })
            let task = Task {

                try await loader.loadImage(from: self.url, size: self.size)
            }
            await #expect(throws: CancellationError.self) { try await task.value }
        }
    }

    @Test
    func `invalid HTTP responses never reach the custom decoder`() async {

        await confirmation("Invalid responses are not decoded", expectedCount: 0) {
            decoded in

            let loader = CarPlayArtworkLoader(imageDecoder: { _ in

                decoded()

                return UIImage()
            }, fetch: { _ in

                try self.response(status: 404)
            })
            await #expect(throws: URLError(.badServerResponse)) {

                try await loader.loadImage(from: self.url, size: self.size)
            }
        }
    }

    @Test
    func `custom decoded artwork is cached without decoding again`() async {

        let replacement = UIImage()
        await confirmation("A cached URL is decoded once") { decoded in

            let loader = CarPlayArtworkLoader(imageDecoder: { data in

                #expect(data == self.data)
                decoded()

                return replacement
            }, fetch: { _ in

                try self.response()
            })
            let store = CarPlayArtworkStore(loader: loader, size: self.size)
            await store.loadImage(from: self.url)
            await store.loadImage(from: self.url)
            #expect(store.image(for: self.url) === replacement)
        }
    }
}

private extension CarPlayArtworkDecodingTests {

    func response(status: Int = 200) throws -> (Data, URLResponse) {

        let response = try #require(HTTPURLResponse(
            url: self.url,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        ))

        return (self.data, response)
    }

    enum DecodeFailure: Error {

        case expected
    }
}
