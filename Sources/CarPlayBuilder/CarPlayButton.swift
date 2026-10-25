// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// An image button with an asynchronous action inside a grid.
///
/// Actions receive the owning scene’s navigation context. Unhandled action
/// errors are sent to the host’s error handler.
@MainActor
public struct CarPlayButton {

    var identity: AnyHashable?
    let titles: [String]
    let image: UIImage
    var repeatPolicy: CarPlayRepeatedActionPolicy = .allowConcurrent
    var isEnabled = true
    let action: CarPlayAction

    /// Creates a grid button with one title.
    ///
    /// - Parameters:
    ///   - title: The button label.
    ///   - image: A ready-to-display button image.
    ///   - action: Selection work using the scene context. Unhandled errors reach
    ///     the host’s error handler.
    public init(_ title: String, image: UIImage, action: @escaping CarPlayAction) {

        self.titles = [title]
        self.image = image
        self.action = action
    }

    /// Creates a grid button with alternative labels for different screen sizes.
    ///
    /// - Parameters:
    ///   - titleVariants: A nonempty list of labels, longest to shortest.
    ///   - image: A ready-to-display button image.
    ///   - action: Selection work using the scene context.
    public init(
        titleVariants: [String],
        image: UIImage,
        action: @escaping CarPlayAction
    ) {

        self.titles = titleVariants
        self.image = image
        self.action = action
    }

    /// Assigns a stable identity to this grid button.
    ///
    /// Use IDs that remain the same across updates and reordering. Without an
    /// explicit ID, the renderer uses the item’s position.
    ///
    /// - Parameter value: A hashable value unique among siblings.
    /// - Returns: A copy carrying the supplied identity.
    public func id(_ value: some Hashable) -> Self {

        var copy = self
        copy.identity = AnyHashable(value)

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

    /// Controls whether the grid button can be selected.
    ///
    /// - Parameter disabled: `true` to disable selection; defaults to `true`.
    /// - Returns: A copy with the requested availability.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }
}
