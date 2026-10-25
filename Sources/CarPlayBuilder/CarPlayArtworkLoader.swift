// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation
import UIKit

/// Downloads HTTP artwork with off-main decoding and optional image changes.
@MainActor
public struct CarPlayArtworkLoader: CarPlayArtworkLoading {

    private let fetch: @MainActor (URLRequest) async throws -> (Data, URLResponse)

    private nonisolated let requestModifier:
        @Sendable (URLRequest, CGSize) async throws -> URLRequest

    private nonisolated let imageModifier: @Sendable (UIImage, CGSize) async throws
        -> UIImage

    private nonisolated let imageDecoder: @Sendable (Data) throws -> UIImage

    /// Creates an HTTP loader with request, decoding, image, and transport hooks.
    ///
    /// - Parameters:
    ///   - requestModifier: Changes a request before fetching it. The requested
    ///     size is a hint for URL variants or server-side resizing. This loader
    ///     does not resize the decoded image unless an image modifier does so.
    ///     The sendable closure is invoked off the main actor.
    ///   - imageDecoder: Converts validated response data to display-ready artwork.
    ///     The default creates a UIKit image and prepares it for display. This
    ///     synchronous sendable closure runs off the main actor. Custom decoders
    ///     should honor cancellation and throw if decoding or preparation fails.
    ///   - imageModifier: Processes successfully decoded artwork before returning
    ///     it for caching and display. Receives the requested size hint. Defaults
    ///     to returning the image unchanged. The sendable closure is invoked off
    ///     the main actor and may suspend or throw. Honor cancellation and use
    ///     actor-safe access for any shared state captured by either modifier.
    ///   - fetch: An async transport, defaulting to `URLSession.shared.data(for:)`.
    ///     Supply a test transport or an authenticated session as needed.
    public init(
        requestModifier: @escaping @Sendable (URLRequest, CGSize) async throws
            -> URLRequest = { request, _ in request },
        imageDecoder: @escaping @Sendable (Data) throws -> UIImage = { data in

            guard let image = UIImage(data: data) else {

                throw URLError(.cannotDecodeContentData)
            }

            try Task.checkCancellation()

            guard let prepared = image.preparingForDisplay() else {

                throw URLError(.cannotDecodeContentData)
            }

            return prepared
        },
        imageModifier: @escaping @Sendable (UIImage, CGSize) async throws
            -> UIImage = { image, _ in image },
        fetch: @escaping @MainActor (URLRequest) async throws
            -> (Data, URLResponse) = {

                try await URLSession.shared.data(for: $0)
            }
    ) {

        self.fetch = fetch
        self.requestModifier = requestModifier
        self.imageModifier = imageModifier
        self.imageDecoder = imageDecoder
    }

    /// Fetches and decodes HTTP artwork, then applies the image modifier.
    ///
    /// The decoder runs off the main actor before the image modifier. The default
    /// decoder creates and prepares artwork for display. Custom decoders must
    /// return display-ready images. Cache and template updates remain actor-owned.
    ///
    /// - Parameters:
    ///   - url: The original artwork URL.
    ///   - size: The size hint passed to both modifiers.
    /// - Returns: The processed image, unchanged by default.
    /// - Throws: Decoder, modifier, transport, or cancellation errors. Invalid
    ///   HTTP responses throw `URLError`. The default decoder also throws
    ///   `URLError` when image creation or display preparation fails.
    public func loadImage(from url: URL, size: CGSize) async throws -> UIImage {

        try Task.checkCancellation()
        let request = try await self.modifyRequest(URLRequest(url: url), size: size)
        try Task.checkCancellation()
        let (data, response) = try await self.fetch(request)
        try Task.checkCancellation()

        let image = try await self.decode(data, response: response)
        let modified = try await self.modifyImage(image, size: size)
        try Task.checkCancellation()

        return modified
    }
}

private extension CarPlayArtworkLoader {

    /// Leaves the calling actor before invoking app-provided request work.
    @concurrent
    nonisolated func modifyRequest(
        _ request: URLRequest,
        size: CGSize
    ) async throws -> URLRequest {

        try Task.checkCancellation()

        return try await self.requestModifier(request, size)
    }

    /// Leaves the calling actor before invoking app-provided image processing.
    @concurrent
    nonisolated func modifyImage(
        _ image: UIImage,
        size: CGSize
    ) async throws -> UIImage {

        try Task.checkCancellation()

        return try await self.imageModifier(image, size)
    }

    /// Validates the response and invokes the decoder off the caller's actor.
    /// Cancellation is checked before and after the synchronous decoder returns.
    @concurrent
    nonisolated func decode(
        _ data: Data,
        response: URLResponse
    ) async throws -> UIImage {

        try Task.checkCancellation()

        guard let response = response as? HTTPURLResponse,
              (200 ..< 300).contains(response.statusCode)
        else {

            throw URLError(.badServerResponse)
        }

        let image = try self.imageDecoder(data)
        try Task.checkCancellation()

        return image
    }
}
