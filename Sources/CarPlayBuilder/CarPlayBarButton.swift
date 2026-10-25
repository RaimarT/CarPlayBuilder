// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A text or image button in a list or grid navigation bar.
///
/// Attach buttons with the leading or trailing toolbar modifiers. The host
/// allows at most two buttons per side and rejects toolbars on tab roots.
@MainActor
public struct CarPlayBarButton {

    var identity: AnyHashable?
    let title: String?
    let image: UIImage?
    var repeatPolicy: CarPlayRepeatedActionPolicy = .allowConcurrent
    var isEnabled = true
    let action: CarPlayAction

    /// Creates a text navigation bar button.
    ///
    /// - Parameters:
    ///   - title: A nonempty label.
    ///   - action: Main-actor work retained in the screen’s action scope.
    ///     Unhandled errors reach the host’s error handler.
    public init(_ title: String, action: @escaping CarPlayAction) {

        self.title = title
        self.image = nil
        self.action = action
    }

    /// Creates an image navigation bar button.
    ///
    /// - Parameters:
    ///   - image: The ready-to-display button image.
    ///   - action: Main-actor work retained in the screen’s action scope.
    public init(image: UIImage, action: @escaping CarPlayAction) {

        self.title = nil
        self.image = image
        self.action = action
    }

    /// Assigns a stable identity to this navigation bar button.
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

    /// Chooses how repeated selections behave while this control's work runs.
    ///
    /// `.ignoreWhileRunning` temporarily disables the native control, preserving
    /// app-owned disabled state. Use stable IDs to retain busy state on updates.
    public func repeatedActionPolicy(_ policy: CarPlayRepeatedActionPolicy) -> Self {

        var copy = self
        copy.repeatPolicy = policy

        return copy
    }

    /// Controls whether the navigation bar button can be selected.
    ///
    /// - Parameter disabled: `true` to disable selection; defaults to `true`.
    /// - Returns: A copy with the requested availability.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }
}
