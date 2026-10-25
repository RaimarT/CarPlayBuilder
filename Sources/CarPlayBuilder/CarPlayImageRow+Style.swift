// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

@available(iOS 26.0, *)
public extension CarPlayImageRow {

    /// The native layout used to arrange an artwork row’s elements.
    enum Style: Hashable, Sendable, CaseIterable {

        /// Artwork with a title and subtitle in a row layout.
        case row
        /// Portrait cards supporting full-height artwork and tint.
        case card
        /// Compact elements with text, artwork shape, and an accessory symbol.
        case condensed
        /// A grid of artwork without element text.
        case grid
        /// An artwork grid supporting titles, image shape, and accessory symbols.
        case imageGrid
    }
}
