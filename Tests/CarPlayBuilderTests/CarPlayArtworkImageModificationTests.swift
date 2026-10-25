// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Testing
import UIKit
@testable import CarPlayBuilder

/// Covers decoded-image processing, caching, failures, and cancellation.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayArtworkImageModificationTests {

    private let url: URL
    private let size = CGSize(width: 80, height: 80)

    init() throws {

        self.url = try #require(URL(string: "https://example.com/cover.png"))
    }

    @Test
    func `async image modifier receives decoded artwork and requested size`() async
        throws {

        let replacement = UIImage()
        let loader = CarPlayArtworkLoader(imageModifier: { image, size in

            Self.expectOffMainThread()
            #expect(image.size.width > 0)
            #expect(size == self.size)
            await Task.yield()
            return replacement
        }, fetch: { _ in

            try self.response()
        })
        let result = try await loader.loadImage(from: self.url, size: self.size)
        #expect(result === replacement)
    }

    @Test
    func `both modifiers can use an independent actor`() async throws {

        let modifiers = ArtworkModifiers()
        let loader = CarPlayArtworkLoader(
            requestModifier: { request, size in

                await modifiers.modifyRequest(request, size: size)
            },
            imageModifier: { image, size in

                await modifiers.modifyImage(image, size: size)
            },
            fetch: { request in

                #expect(request.value(forHTTPHeaderField: "X-Modified") == "yes")

                return try self.response()
            }
        )
        let image = try await loader.loadImage(from: self.url, size: self.size)
        #expect(image.size.width > 0)
        #expect(await modifiers.calls == ["request", "image"])
    }

    @Test
    func `modified artwork is cached across repeated loads`() async {

        let replacement = UIImage()
        let modifications = ModificationCounter()
        var fetches = 0
        let loader = CarPlayArtworkLoader(imageModifier: { _, _ in

            _ = await modifications.increment()
            await Task.yield()
            return replacement
        }, fetch: { _ in

            fetches += 1
            return try self.response()
        })
        let store = CarPlayArtworkStore(loader: loader, size: self.size)
        #expect(store.image(for: self.url) == nil)
        await store.loadImages(from: [self.url, self.url])
        #expect(store.image(for: self.url) === replacement)
        await store.loadImage(from: self.url)
        #expect(store.image(for: self.url) === replacement)
        #expect(await modifications.value == 1)
        #expect(fetches == 1)
    }

    @Test
    func `image modifier errors propagate to direct callers`() async {

        let loader = CarPlayArtworkLoader(imageModifier: { _, _ in

            throw ModificationFailure.expected
        }, fetch: { _ in

            try self.response()
        })
        await #expect(throws: ModificationFailure.expected) {

            try await loader.loadImage(from: self.url, size: self.size)
        }
    }

    @Test
    func `failed modification leaves no original cached and permits retry`() async {

        let replacement = UIImage()
        let attempts = ModificationCounter()
        let loader = CarPlayArtworkLoader(imageModifier: { _, _ in

            let attempt = await attempts.increment()

            guard attempt > 1 else {

                throw ModificationFailure.expected
            }

            return replacement
        }, fetch: { _ in

            try self.response()
        })
        let store = CarPlayArtworkStore(loader: loader, size: self.size)
        await store.loadImage(from: self.url)
        #expect(store.image(for: self.url) == nil)
        await store.loadImage(from: self.url)
        #expect(store.image(for: self.url) === replacement)
        #expect(await attempts.value == 2)
    }

    @Test(arguments: [200, 404])
    func `invalid responses never reach the image modifier`(status: Int) async {

        let modifications = ModificationCounter()
        let loader = CarPlayArtworkLoader(imageModifier: { image, _ in

            _ = await modifications.increment()
            return image
        }, fetch: { _ in

            try self.response(status: status, data: Data())
        })
        await #expect(throws: URLError.self) {

            try await loader.loadImage(from: self.url, size: self.size)
        }
        #expect(await modifications.value == 0)
    }

    @Test
    func `cancellation before image processing prevents its invocation`() async {

        let modifications = ModificationCounter()
        let loader = CarPlayArtworkLoader(imageModifier: { image, _ in

            _ = await modifications.increment()
            return image
        }, fetch: { _ in

            withUnsafeCurrentTask { $0?.cancel() }
            return try self.response()
        })
        let task = Task {

            try await loader.loadImage(from: self.url, size: self.size)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await modifications.value == 0)
    }

    @Test
    func `cancellation during modification prevents returning its image`() async {

        let started = AsyncStream<Void>.makeStream()
        let resume = AsyncStream<Void>.makeStream()
        let loader = CarPlayArtworkLoader(imageModifier: { image, _ in

            started.continuation.yield(())
            var iterator = resume.stream.makeAsyncIterator()
            _ = await iterator.next()
            return image
        }, fetch: { _ in

            try self.response()
        })
        let task = Task {

            try await loader.loadImage(from: self.url, size: self.size)
        }
        var iterator = started.stream.makeAsyncIterator()
        _ = await iterator.next()
        task.cancel()
        resume.continuation.yield(())
        resume.continuation.finish()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

private extension CarPlayArtworkImageModificationTests {

    /// Supplies modifier methods isolated to an actor other than the main actor.
    actor ArtworkModifiers {

        private(set) var calls: [String] = []

        func modifyRequest(_ request: URLRequest, size: CGSize) -> URLRequest {

            self.calls.append("request")
            var request = request
            request.setValue("yes", forHTTPHeaderField: "X-Modified")

            return request
        }

        func modifyImage(_ image: UIImage, size: CGSize) -> UIImage {

            self.calls.append("image")

            return image
        }
    }

    func response(status: Int = 200, data: Data? = nil) throws
        -> (Data, URLResponse) {

        let data = try data ?? #require(UIImage(systemName: "music.note")?.pngData())
        let response = try #require(HTTPURLResponse(
            url: self.url,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        ))
        return (data, response)
    }

    /// Serializes counters shared between the main-actor test and modifiers.
    actor ModificationCounter {

        private(set) var value = 0

        func increment() -> Int {

            self.value += 1

            return self.value
        }
    }

    enum ModificationFailure: Error {

        case expected
    }
}

private extension CarPlayArtworkImageModificationTests {

    /// Samples the current executor thread before the async modifier suspends.
    nonisolated static func expectOffMainThread() {

        #expect(Thread.isMainThread == false)
    }
}
