// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

public extension CarPlayStatusLabel {

    /// The English loading label with an hourglass symbol.
    static var loading: Self {

        Self(title: "Loading…", systemImage: "hourglass")
    }

    /// The English failure label with a warning-triangle symbol.
    static var failure: Self {

        Self(title: "Unable to load", systemImage: "exclamationmark.triangle")
    }

    /// The English empty-result label with a tray symbol.
    static var empty: Self {

        Self(title: "No items available", systemImage: "tray")
    }

    /// The English retry label with a clockwise-arrow symbol.
    static var retry: Self {

        Self(title: "Try again", systemImage: "arrow.clockwise")
    }
}
