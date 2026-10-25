// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation

/// Asynchronous resource or artwork state, preserving original failure errors.
public enum CarPlayLoadState: Sendable {

    /// No current value or failure is retained and no request is running.
    case idle
    /// A request is running; a previous successful value may still be available.
    case loading
    /// A successful value is available, including an empty collection result.
    /// For artwork, an image is currently retained in the cache.
    case loaded
    /// A request failed with the original error preserved for recovery.
    case failed(any Error)
}
