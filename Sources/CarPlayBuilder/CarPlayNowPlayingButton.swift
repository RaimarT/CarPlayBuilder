// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

public extension CarPlayNowPlayingButton {

    /// Cycles the app's playback rate through `CarPlayNowPlayingPlayback`.
    static var playbackRate: Self {

        Self(kind: .playbackRate)
    }

    /// Toggles the app's shuffle mode through `CarPlayNowPlayingPlayback`.
    static var shuffle: Self {

        Self(kind: .shuffle)
    }

    /// Cycles the app's repeat mode through `CarPlayNowPlayingPlayback`.
    static var repeatMode: Self {

        Self(kind: .repeat)
    }

    /// Creates a standard Add to Library control with app-owned save behavior.
    static func addToLibrary(action: @escaping CarPlayAction) -> Self {

        Self(kind: .addToLibrary, action: action)
    }

    /// Creates a standard More control, for example to present an action sheet.
    static func more(action: @escaping CarPlayAction) -> Self {

        Self(kind: .more, action: action)
    }
}

/// A standard or custom control in an ordered Now Playing button builder.
///
/// Use stable IDs for conditional or reordered controls. The application owns
/// playback, media metadata, and the state read while building these values.
@MainActor
public struct CarPlayNowPlayingButton {

    var identity: AnyHashable?
    let kind: CarPlayNowPlayingAction
    let image: UIImage?
    let action: CarPlayAction?
    var repeatPolicy: CarPlayRepeatedActionPolicy = .allowConcurrent
    var isEnabled = true
    var isSelected = false

    /// Creates a custom image action. CarPlay recolors the supplied image.
    ///
    /// - Parameters:
    ///   - image: Ready-to-display artwork sized for
    ///     `CPNowPlayingButtonMaximumImageSize`.
    ///   - action: Scene-owned asynchronous work. Unhandled errors reach `onError`.
    public init(image: UIImage, action: @escaping CarPlayAction) {

        self.kind = .custom
        self.image = image
        self.action = action
    }

    init(
        kind: CarPlayNowPlayingAction,
        image: UIImage? = nil,
        action: CarPlayAction? = nil
    ) {

        self.kind = kind
        self.image = image
        self.action = action
    }

    /// Assigns a stable identity unique among the coordinator's buttons.
    public func id(_ id: some Hashable) -> Self {

        var copy = self
        copy.identity = AnyHashable(id)

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

    /// Controls whether this button can be selected.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }

    /// Sets a custom image button's selected appearance.
    ///
    /// Standard controls derive their selected appearance from system media
    /// metadata and ignore this modifier.
    public func selected(_ selected: Bool = true) -> Self {

        var copy = self
        copy.isSelected = selected

        return copy
    }
}
