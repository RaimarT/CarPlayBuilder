// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation
import UIKit

/// Inject app-specific URL transformation, authentication, or image processing.
@MainActor
public protocol CarPlayArtworkLoading {

    /// Loads artwork for the supplied original URL and size hint.
    ///
    /// Custom implementations may authenticate requests, choose variants, or
    /// process images. They should cooperate with task cancellation.
    ///
    /// - Parameters:
    ///   - url: The original URL used as the store’s cache key.
    ///   - size: A hint for resizing or choosing an image variant.
    /// - Returns: Ready-to-display artwork.
    /// - Throws: Loading, decoding, or cancellation errors. The artwork store
    ///   retains noncancellation errors in `state(for:)` and permits a later retry.
    func loadImage(from url: URL, size: CGSize) async throws -> UIImage
}
