// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import UIKit

/// Coordinates cache access and shared requests without UI observation.
@MainActor
final class CarPlayArtworkPipeline {

    private let cache = NSCache<NSURL, UIImage>()
    private let failures = NSCache<NSURL, Failure>()
    private let loader: any CarPlayArtworkLoading
    private let size: CGSize
    private let maximumConcurrentLoads: Int
    var onChange: CarPlayCallback?
    private var requests: [URL: Request] = [:]
    private var pending: [URL] = []
    private var running = 0

    init(
        loader: any CarPlayArtworkLoading,
        size: CGSize,
        cacheLimit: Int = 100,
        maximumConcurrentLoads: Int = 4
    ) {

        self.loader = loader
        self.size = size
        self.cache.countLimit = max(0, cacheLimit)
        self.failures.countLimit = max(0, cacheLimit)
        self.maximumConcurrentLoads = max(1, maximumConcurrentLoads)
    }

    func image(for url: URL) -> UIImage? {

        self.cache.object(forKey: url as NSURL)
    }

    func state(for url: URL) -> CarPlayLoadState {

        if self.requests[url] != nil {

            return .loading
        }

        if self.image(for: url) != nil {

            return .loaded
        }

        if let failure = self.failures.object(forKey: url as NSURL) {

            return .failed(failure.error)
        }

        return .idle
    }

    /// Refreshes cached or failed URLs while joining already-running work.
    func reloadImage(from url: URL) async {

        guard !Task.isCancelled else {

            return
        }

        if self.requests[url] == nil {

            self.invalidateImage(for: url)
        }
        await self.loadImage(from: url)
    }

    /// Invalidates the request generation before cancelled work can publish.
    func invalidateImage(for url: URL) {

        self.cache.removeObject(forKey: url as NSURL)
        self.failures.removeObject(forKey: url as NSURL)
        self.pending.removeAll { $0 == url }
        let request = self.requests.removeValue(forKey: url)
        self.cancel(request)
        self.onChange?()
    }

    func invalidateAllImages() {

        self.cache.removeAllObjects()
        self.failures.removeAllObjects()
        self.pending.removeAll()
        let requests = Array(self.requests.values)
        self.requests.removeAll()
        for request in requests {

            self.cancel(request)
        }
        self.onChange?()
    }

    /// Requests share in-flight work and a store-wide limit (four by default).
    /// Cancelling the last consumer cancels its request; other consumers continue.
    /// Failures leave the cache empty so the next load can retry the URL.
    func loadImages(from urls: [URL]) async {

        await withTaskGroup(of: Void.self) { group in

            for url in Set(urls) {

                group.addTask { [self, url] in

                    await self.loadImage(from: url)
                }
            }
        }
    }

    /// Loads one URL, joining any existing request. Cancelling this consumer only
    /// cancels the underlying loader when no other consumers remain.
    func loadImage(from url: URL) async {

        guard !Task.isCancelled, self.image(for: url) == nil else {

            return
        }

        let waiter = UUID()
        await withTaskCancellationHandler {

            await withCheckedContinuation { continuation in

                let isNew = self.requests[url] == nil
                let request = self.requests[url] ?? Request()

                if isNew {

                    self.requests[url] = request
                    self.failures.removeObject(forKey: url as NSURL)
                    self.pending.append(url)
                }

                request.waiters[waiter] = continuation
                self.startPendingRequests()

                if isNew {

                    self.onChange?()
                }
            }
        } onCancel: {

            Task { @MainActor in

                self.cancel(waiter: waiter, url: url)
            }
        }
    }
}

private extension CarPlayArtworkPipeline {

    /// Starts queued loads until the store-wide concurrency limit is reached.
    func startPendingRequests() {

        while self.running < self.maximumConcurrentLoads, !self.pending.isEmpty {

            let url = self.pending.removeFirst()

            guard let request = self.requests[url], request.task == nil else {

                continue
            }

            self.running += 1
            request.task = self.makeTask(url: url, id: request.id)
        }
    }

    func makeTask(url: URL, id: UUID) -> Task<Void, Never> {

        let loader = self.loader
        let size = self.size
        return Task { [weak self] in

            let result: Result<UIImage, any Error>

            do {

                try Task.checkCancellation()
                let loaded = try await loader.loadImage(from: url, size: size)
                try Task.checkCancellation()
                result = .success(loaded)
            } catch {

                result = .failure(error)
            }
            self?.complete(url: url, id: id, result: result)
        }
    }

    /// Releases a concurrency slot and publishes only the matching request result.
    ///
    /// A cancelled URL can be requested again before its old task finishes. The
    /// request UUID prevents the old result from completing the new consumers.
    func complete(url: URL, id: UUID, result: Result<UIImage, any Error>) {

        self.running -= 1
        if let request = self.requests[url], request.id == id {

            self.requests[url] = nil
            self.publish(result, for: url)
            self.onChange?()
            for waiter in request.waiters.values {

                waiter.resume()
            }
        }
        self.startPendingRequests()
    }

    /// Resumes one cancelled consumer and cancels work only after the last leaves.
    func cancel(waiter: UUID, url: URL) {

        guard let request = self.requests[url] else {

            return
        }

        request.waiters.removeValue(forKey: waiter)?.resume()
        if request.waiters.isEmpty {

            self.requests[url] = nil
            self.pending.removeAll { $0 == url }
            request.task?.cancel()
            self.onChange?()
        }
    }

    func publish(_ result: Result<UIImage, any Error>, for url: URL) {

        switch result {

        case let .success(image):
            self.cache.setObject(image, forKey: url as NSURL)

        case let .failure(error) where !(error is CancellationError):
            self.failures.setObject(
                Failure(error: error),
                forKey: url as NSURL
            )

        case .failure:
            break
        }
    }

    func cancel(_ request: Request?) {

        guard let request else {

            return
        }

        request.task?.cancel()
        for waiter in request.waiters.values {

            waiter.resume()
        }
    }
}

private extension CarPlayArtworkPipeline {

    /// Tracks one URL generation and all consumers awaiting its shared load.
    final class Request {

        let id = UUID()
        var task: Task<Void, Never>?
        var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    }
}

private extension CarPlayArtworkPipeline {

    final class Failure {

        let error: any Error

        init(error: any Error) {

            self.error = error
        }
    }
}
