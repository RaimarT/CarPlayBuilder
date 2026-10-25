// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Identifies the kind of control whose asynchronous action failed.
public enum CarPlayErrorControl: Sendable, Equatable {

    /// A standard list row.
    case row
    /// An element in an image row.
    case imageElement
    /// A grid button.
    case gridButton
    /// A leading or trailing navigation bar button.
    case barButton
    /// An action in a rich list header.
    case listHeaderButton
    /// An action attached to a section header.
    case sectionHeaderButton
    /// An alert or action-sheet action.
    case modalAction
    /// A custom or standard asynchronous Now Playing action.
    case nowPlayingButton
    /// A coordinator-owned Up Next or album/artist destination.
    case nowPlayingDestination
}
