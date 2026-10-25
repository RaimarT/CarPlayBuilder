// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Visibility of the native Now Playing controls.
public struct CarPlayNowPlayingConfiguration: Sendable {

    /// Whether the playback-rate button is shown. Defaults to `true`.
    public var showsPlaybackRateButton: Bool
    /// Whether the shuffle button is shown. Defaults to `false`.
    public var showsShuffleButton: Bool
    /// Whether the repeat button is shown. Defaults to `false`.
    public var showsRepeatButton: Bool
    /// Whether Add to Library is eligible to appear. A callback is also required.
    public var showsAddToLibraryButton: Bool
    /// Whether More is eligible to appear. A callback is also required.
    public var showsMoreButton: Bool
    /// Custom Up Next button title, or `nil` for the native system default.
    public var upNextTitle: String?

    /// Selects which controls the coordinator installs.
    ///
    /// The rate button is enabled by default. Other controls are opt-in. Button
    /// visibility does not implement playback behavior or publish media metadata.
    ///
    /// - Parameters:
    ///   - showsPlaybackRateButton: Include the native rate control.
    ///   - showsShuffleButton: Include the native shuffle control.
    ///   - showsRepeatButton: Include the native repeat control.
    ///   - showsAddToLibraryButton: Include Add to Library when its callback exists.
    ///   - showsMoreButton: Include More when its callback exists.
    ///   - upNextTitle: A localized queue label, or `nil` for the system default.
    public init(
        showsPlaybackRateButton: Bool = true,
        showsShuffleButton: Bool = false,
        showsRepeatButton: Bool = false,
        showsAddToLibraryButton: Bool = false,
        showsMoreButton: Bool = false,
        upNextTitle: String? = nil
    ) {

        self.showsPlaybackRateButton = showsPlaybackRateButton
        self.showsShuffleButton = showsShuffleButton
        self.showsRepeatButton = showsRepeatButton
        self.showsAddToLibraryButton = showsAddToLibraryButton
        self.showsMoreButton = showsMoreButton
        self.upNextTitle = upNextTitle
    }
}
