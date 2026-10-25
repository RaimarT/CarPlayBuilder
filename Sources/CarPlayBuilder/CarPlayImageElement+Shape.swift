// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

@available(iOS 26.0, *)
public extension CarPlayImageElement {

    /// The artwork mask used by condensed and image-grid elements.
    enum Shape: Hashable, Sendable {

        /// Artwork clipped to the native rounded-rectangle shape.
        case roundedRectangle
        /// Artwork clipped to a circle.
        case circular
    }
}
