// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A selectable row. Playback and image state can be derived from an observable
/// application model.
@MainActor
public struct CarPlayRow {

    var identity: AnyHashable?
    var imageRow: CarPlayImageRowContent?
    let title: String
    let detail: String?
    var image: UIImage?
    var trailingImage: UIImage?
    var accessory: CPListItemAccessoryType = .none
    var repeatPolicy: CarPlayRepeatedActionPolicy = .allowConcurrent
    var isEnabled = true
    var isPlaying = false
    var isExplicitContent = false
    var indicatorLocation: CPListItemPlayingIndicatorLocation = .leading
    var progress: Double = 0
    var action: CarPlayAction?

    /// Creates a text row with optional artwork and selection behavior.
    ///
    /// - Parameters:
    ///   - title: Primary text shown by the native list item.
    ///   - detail: Optional secondary text.
    ///   - image: Optional leading image. Supply a ready-to-display image.
    ///   - action: Main-actor selection work. The host retains it until completion
    ///     and cancels it when the screen is removed or the scene disconnects.
    ///     `nil` creates a row without a selection handler.
    public init(
        _ title: String,
        detail: String? = nil,
        image: UIImage? = nil,
        action: CarPlayAction? = nil
    ) {

        self.title = title
        self.detail = detail
        self.image = image
        self.action = action
    }

    /// Assigns a stable identity to this row.
    ///
    /// Use IDs that remain the same across updates and reordering. Without an
    /// explicit ID, the renderer uses the item’s position.
    ///
    /// - Parameter id: A hashable value unique among siblings.
    /// - Returns: A copy carrying the supplied identity.
    public func id(_ id: some Hashable) -> Self {

        var copy = self
        copy.identity = AnyHashable(id)

        return copy
    }

    /// Sets the native accessory indicator.
    ///
    /// - Parameter accessory: A disclosure, cloud, or absent indicator.
    /// - Returns: A modified row. A non-`nil` trailing image takes precedence.
    public func accessory(_ accessory: CPListItemAccessoryType) -> Self {

        var copy = self
        copy.accessory = accessory

        return copy
    }

    /// Shows artwork in the accessory region, replacing the accessory indicator.
    /// Pass `nil` to restore the configured accessory type.
    public func trailingImage(_ image: UIImage?) -> Self {

        var copy = self
        copy.trailingImage = image

        return copy
    }

    /// Chooses how repeated selections behave while this control's work runs.
    ///
    /// `.ignoreWhileRunning` temporarily disables the native control, preserving
    /// app-owned disabled state. Use stable IDs to retain busy state on updates.
    public func repeatedActionPolicy(_ policy: CarPlayRepeatedActionPolicy) -> Self {

        var copy = self
        copy.repeatPolicy = policy

        return copy
    }

    /// Controls whether the row can be selected.
    ///
    /// - Parameter disabled: `true` to disable selection; defaults to `true`.
    /// - Returns: A copy with the requested availability.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }

    /// Shows the native explicit-content indicator beside the primary text.
    ///
    /// This marks content only; it does not restrict access or affect playback.
    ///
    /// - Parameter explicit: Whether to show the indicator; defaults to `true`.
    /// - Returns: A row with the requested explicit-content presentation.
    public func explicitContent(_ explicit: Bool = true) -> Self {

        var copy = self
        copy.isExplicitContent = explicit

        return copy
    }

    /// Positions the native Now Playing indicator on the leading or trailing side.
    ///
    /// The default is `.leading`. The indicator appears when `playback` sets
    /// `isPlaying` to `true`. Artwork and accessories retain their configuration;
    /// CarPlay determines the final native layout.
    ///
    /// - Parameter location: The side on which to show the playing indicator.
    /// - Returns: A row with the requested indicator placement.
    public func playingIndicatorLocation(
        _ location: CPListItemPlayingIndicatorLocation
    ) -> Self {

        var copy = self
        copy.indicatorLocation = location

        return copy
    }

    /// Sets the native playback indicator and normalized progress.
    ///
    /// This updates presentation only; it does not control an audio player.
    ///
    /// - Parameters:
    ///   - isPlaying: Whether the row represents the current playing item.
    ///   - progress: Playback fraction, clamped to 0...1. Nonfinite values use zero.
    /// - Returns: A row with the supplied playback presentation.
    public func playback(isPlaying: Bool, progress: Double = 0) -> Self {

        var copy = self
        copy.isPlaying = isPlaying
        copy.progress = progress.isFinite ? min(max(progress, 0), 1) : 0

        return copy
    }
}
