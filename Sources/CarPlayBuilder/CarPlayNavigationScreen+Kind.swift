// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

public extension CarPlayNavigationScreen {

    /// Template categories supported by navigation event snapshots.
    enum Kind: Sendable, Equatable {

        /// A list screen.
        case list
        /// A grid screen.
        case grid
        /// The tab container; selection has a separate tab callback.
        case tabs
        /// The shared Now Playing screen.
        case nowPlaying
        /// A modal alert.
        case alert
        /// A modal action sheet.
        case actionSheet
    }
}
