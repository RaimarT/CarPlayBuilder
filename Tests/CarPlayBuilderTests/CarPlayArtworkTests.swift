// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Observation
import Testing
import UIKit
@testable import CarPlayBuilder

/// Covers observable artwork caching and loading integration with screens.
@MainActor
struct CarPlayArtworkTests {

    private let url: URL
    private let size = CGSize(width: 80, height: 80)

    init() throws {

        let source = "https://example.com/images/cover.jpg?v=1"
        self.url = try #require(URL(string: source))
    }

    @Test
    func `default loader preserves the source URL`() async throws {

        let request = try ArtworkRequest()
        let image = try await request.loader.loadImage(
            from: self.url,
            size: self.size
        )
        #expect(image.size.width > 0)
        #expect(request.urls == [self.url])
    }

    @Test
    func `raster artwork retains its pixel dimensions after preparation`() async
        throws {

        let request = try ArtworkRequest()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 12, height: 8)
        let source = UIGraphicsImageRenderer(size: size, format: format).image {
            context in

            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        request.data = try #require(source.jpegData(compressionQuality: 1))
        let image = try await request.loader.loadImage(from: self.url, size: size)
        let pixels = try #require(image.cgImage)
        #expect(pixels.width == 12)
        #expect(pixels.height == 8)
    }

    @Test
    func `non HTTP responses are rejected`() async throws {

        let request = try ArtworkRequest()
        request.statusCode = nil
        await #expect(throws: URLError(.badServerResponse)) {

            try await request.loader.loadImage(from: self.url, size: self.size)
        }
    }

    @Test
    func `transport failures preserve the original error`() async {

        let loader = CarPlayArtworkLoader(fetch: { _ in

            throw URLError(.timedOut)
        })
        await #expect(throws: URLError(.timedOut)) {

            try await loader.loadImage(from: self.url, size: self.size)
        }
    }

    @Test
    func `placeholder is replaced after a single image loads`() async throws {

        let request = try ArtworkRequest()
        let store = CarPlayArtworkStore(loader: request.loader)
        let placeholder = UIImage()
        #expect(store.image(for: self.url, placeholder: placeholder) === placeholder)
        #expect(store.image(for: nil, placeholder: placeholder) === placeholder)
        await store.loadImage(from: self.url)
        let image = try #require(store.image(for: self.url))
        #expect(image !== placeholder)
        #expect(store.image(for: self.url, placeholder: placeholder) === image)
        #expect(request.urls == [self.url])
    }

    @Test
    func `custom loader receives the original URL and requested size`() async {

        let loader = SizedLoader()
        let store = CarPlayArtworkStore(loader: loader, size: self.size)
        await store.loadImage(from: self.url)
        #expect(loader.url == self.url)
        #expect(loader.size == self.size)
        #expect(store.image(for: self.url) === loader.image)
    }

    @Test
    func `invalid data is rejected`() async throws {

        let request = try ArtworkRequest()
        request.data = Data()
        await #expect(throws: URLError(.cannotDecodeContentData)) {

            try await request.loader.loadImage(from: self.url, size: self.size)
        }
    }

    @Test
    func `unsuccessful HTTP responses are rejected`() async throws {

        let request = try ArtworkRequest()
        request.statusCode = 404
        await #expect(throws: URLError(.badServerResponse)) {

            try await request.loader.loadImage(from: self.url, size: self.size)
        }
    }

    @Test
    func `repeated URLs use the cached image`() async throws {

        let request = try ArtworkRequest()
        let store = CarPlayArtworkStore(loader: request.loader, size: self.size)
        await store.loadImages(from: [self.url, self.url])
        let first = try #require(store.image(for: self.url))
        await store.loadImages(from: [self.url])
        #expect(request.urls.count == 1)
        #expect(store.image(for: self.url) === first)
    }

    @Test
    func `artwork requests notify image observers`() async throws {

        let request = try ArtworkRequest()
        let store = CarPlayArtworkStore(loader: request.loader, size: self.size)
        await confirmation("Artwork state invalidates rows") { changed in

            withObservationTracking {

                _ = store.image(for: self.url)
            } onChange: {

                changed()
            }
            await store.loadImages(from: [self.url])
        }
        #expect(store.image(for: self.url) != nil)
    }

    @Test
    func `failed images can be retried`() async throws {

        let request = try ArtworkRequest()
        let data = request.data
        let store = CarPlayArtworkStore(loader: request.loader, size: self.size)
        request.data = Data()
        await store.loadImages(from: [self.url])
        #expect(store.image(for: self.url) == nil)
        request.data = data
        await store.loadImages(from: [self.url])
        #expect(store.image(for: self.url) != nil)
        #expect(request.urls.count == 2)
    }

    @Test
    func `cancellation prevents image requests`() async throws {

        let request = try ArtworkRequest()
        let store = CarPlayArtworkStore(loader: request.loader, size: self.size)
        let task = Task {

            await store.loadImages(from: [self.url])
        }
        task.cancel()
        await task.value
        #expect(request.urls.isEmpty)
        #expect(store.image(for: self.url) == nil)
    }
}

private extension CarPlayArtworkTests {

    @MainActor
    final class SizedLoader: CarPlayArtworkLoading {

        let image = UIImage()
        var url: URL?
        var size: CGSize?

        func loadImage(from url: URL, size: CGSize) async throws -> UIImage {

            self.url = url
            self.size = size
            return self.image
        }
    }

    @MainActor
    final class ArtworkRequest {

        var urls: [URL] = []
        var statusCode: Int? = 200
        var data: Data

        init() throws {

            self.data = try #require(UIImage(systemName: "music.note")?.pngData())
        }

        var loader: CarPlayArtworkLoader {

            CarPlayArtworkLoader(fetch: { request in

                guard let url = request.url else {

                    throw URLError(.badURL)
                }

                self.urls.append(url)
                let response: URLResponse = if let statusCode = self.statusCode {

                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: statusCode,
                        httpVersion: nil,
                        headerFields: nil
                    ))
                } else {

                    URLResponse(
                        url: url,
                        mimeType: "image/png",
                        expectedContentLength: self.data.count,
                        textEncodingName: nil
                    )
                }
                return (self.data, response)
            })
        }
    }
}
