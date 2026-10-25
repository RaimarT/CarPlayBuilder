// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation

/// Observable artwork shared by rows, grids, and Now Playing integrations.
/// Own one store per image size; cached images are keyed by their original URL.
@MainActor
@Observable
public final class CarPlayArtworkStore {

    private let pipeline: CarPlayArtworkPipeline
    private var revision = 0

    /// Creates an observable cache with shared, bounded-concurrency loading.
    ///
    /// Own one store per image size, image-processing configuration, and
    /// authentication scope. Cache keys use the original URL, even if the loader
    /// changes the outgoing request. A loader's image modifier runs before caching;
    /// cache hits and placeholder images bypass it.
    ///
    /// - Parameters:
    ///   - loader: A custom loader, or `nil` for `CarPlayArtworkLoader`.
    ///   - size: A loader size hint, defaulting to `CPListItem.maximumImageSize`.
    ///   - cacheLimit: Maximum cached image count. Zero or negative values use
    ///     an unbounded count limit. The same count separately limits retained
    ///     failures. Both caches may be evicted by the system.
    ///   - maximumConcurrentLoads: Store-wide request limit, clamped to at least
    /// one.
    public init(
        loader: (any CarPlayArtworkLoading)? = nil,
        size: CGSize? = nil,
        cacheLimit: Int = 100,
        maximumConcurrentLoads: Int = 4
    ) {

        self.pipeline = CarPlayArtworkPipeline(
            loader: loader ?? CarPlayArtworkLoader(),
            size: size ?? CPListItem.maximumImageSize,
            cacheLimit: cacheLimit,
            maximumConcurrentLoads: maximumConcurrentLoads
        )
        self.pipeline.onChange = { [weak self] in

            self?.revision += 1
        }
    }

    /// Returns cached artwork or a placeholder without starting a load.
    /// Reads participate in observation of loading and cache changes.
    public func image(for url: URL?, placeholder: UIImage? = nil) -> UIImage? {

        self.image(for: url, placeholder: placeholder, failurePlaceholder: nil)
    }

    /// Returns cached artwork or the supplied placeholder without starting a load.
    ///
    /// Reading this method tracks loading, failure, completion, and invalidation.
    /// A failed request uses `failurePlaceholder`, falling back to `placeholder`.
    /// Placeholders bypass image decoding/modification and are never cached.
    ///
    /// - Parameters:
    ///   - url: Original artwork URL, or `nil` to use the ordinary placeholder.
    ///   - placeholder: Artwork used for idle, loading, or unspecified failures.
    ///   - failurePlaceholder: Optional artwork used only after a failed request.
    /// - Returns: Cached artwork or the selected placeholder.
    public func image(
        for url: URL?,
        placeholder: UIImage? = nil,
        failurePlaceholder: UIImage?
    ) -> UIImage? {

        // Bridge pipeline changes into template observation.
        _ = self.revision

        guard let url else {

            return placeholder
        }

        if let image = self.pipeline.image(for: url) {

            return image
        }

        if case .failed = self.pipeline.state(for: url) {

            return failurePlaceholder ?? placeholder
        }
        return placeholder
    }

    /// Reads the observable state without starting a request.
    ///
    /// Missing URLs and cache misses are idle. Queued/shared requests are loading.
    /// Loaded means an image is currently cached; eviction returns it to idle on
    /// the next read. Automatic cache eviction does not emit a change callback.
    /// Failures preserve the original error in a bounded, evictable metadata cache.
    /// Cancellation and invalidation return to idle rather than reporting failure.
    /// - Parameter url: Original artwork URL, or `nil` for idle state.
    /// - Returns: The current state, preserving an original failure when retained.
    public func state(for url: URL?) -> CarPlayLoadState {

        _ = self.revision

        guard let url else {

            return .idle
        }

        return self.pipeline.state(for: url)
    }

    /// Removes one image and its failure metadata, cancelling any shared request.
    ///
    /// All current consumers resume. Cancelled work cannot repopulate this URL;
    /// the next explicit load starts a new request. Other URLs remain unchanged.
    /// - Parameter url: Original URL whose artwork and pending work are invalidated.
    public func invalidateImage(for url: URL) {

        self.pipeline.invalidateImage(for: url)
    }

    /// Clears cached artwork and failure metadata and cancels all pending work.
    ///
    /// Consumers resume without error; late results cannot repopulate the cache.
    /// Existing loader operations still occupy concurrency slots until they exit.
    /// For account changes, also replace the store/loader if credentials changed.
    public func invalidateAllImages() {

        self.pipeline.invalidateAllImages()
    }

    /// Refreshes cached artwork, retries failures, or joins an existing request.
    ///
    /// A refresh removes cached artwork first, so placeholders show while loading.
    /// Concurrent reloads share work. Cancelling this consumer does not cancel
    /// other consumers. A caller already cancelled on entry leaves cache intact.
    /// - Parameter url: Original artwork URL to refresh or retry.
    public func reloadImage(from url: URL) async {

        await self.pipeline.reloadImage(from: url)
    }

    /// Requests share in-flight work and a store-wide limit (four by default).
    /// Cancelling the last consumer cancels its request; other consumers continue.
    /// Failures preserve their error in `state(for:)`; another load retries them.
    public func loadImages(from urls: [URL]) async {

        await self.pipeline.loadImages(from: urls)
    }

    /// Loads one URL, joining any existing request. Cancelling this consumer only
    /// cancels the underlying loader when no other consumers remain.
    public func loadImage(from url: URL) async {

        await self.pipeline.loadImage(from: url)
    }
}
