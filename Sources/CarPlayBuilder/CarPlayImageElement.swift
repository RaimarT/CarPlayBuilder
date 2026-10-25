// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// An artwork tile with app-owned content and selection behavior.
@available(iOS 26.0, *)
@MainActor
public struct CarPlayImageElement {

    var identity: AnyHashable?
    let title: String
    let subtitle: String?
    let image: UIImage
    let action: CarPlayAction?
    var repeatPolicy: CarPlayRepeatedActionPolicy = .allowConcurrent
    var isEnabled = true
    var imageShape: Shape = .roundedRectangle
    var fillsCard = false
    var tintColor: UIColor?
    var accessorySymbolName: String?

    /// Creates an artwork element for an iOS 26 image row.
    ///
    /// - Parameters:
    ///   - title: The element label, displayed by layouts supporting text.
    ///   - subtitle: Optional supporting text for layouts that display subtitles.
    ///   - image: Ready-to-display artwork.
    ///   - action: Optional main-actor selection work. An element without an action
    ///     is not selectable, even if it has not been explicitly disabled.
    public init(
        _ title: String,
        subtitle: String? = nil,
        image: UIImage,
        action: CarPlayAction? = nil
    ) {

        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.action = action
    }

    /// Assigns a stable identity to this artwork element.
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

    /// Controls whether the artwork element can be selected.
    ///
    /// - Parameter disabled: `true` to disable selection; defaults to `true`.
    /// - Returns: A copy with the requested availability.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }

    /// Sets the artwork shape for condensed and image-grid layouts.
    ///
    /// - Parameter shape: Rounded-rectangle or circular artwork.
    /// - Returns: A modified element. Other layouts ignore this option.
    public func shape(_ shape: Shape) -> Self {

        var copy = self
        copy.imageShape = shape

        return copy
    }

    /// Fills a portrait card with artwork instead of a square thumbnail.
    ///
    /// - Parameter enabled: Whether the artwork fills the card.
    /// - Returns: A modified element. Applies to the card layout.
    public func fullHeightImage(_ enabled: Bool = true) -> Self {

        var copy = self
        copy.fillsCard = enabled

        return copy
    }

    /// Sets the card’s background or label tint.
    ///
    /// - Parameter color: A tint color, or `nil` to use the native default.
    /// - Returns: A modified element. Other layouts ignore this option.
    public func tint(_ color: UIColor?) -> Self {

        var copy = self
        copy.tintColor = color

        return copy
    }

    /// Adds an SF Symbol to condensed and image-grid elements.
    ///
    /// - Parameter name: The symbol name, or `nil` to omit the accessory.
    /// - Returns: A modified element. Other layouts ignore this option.
    public func accessorySymbol(_ name: String?) -> Self {

        var copy = self
        copy.accessorySymbolName = name

        return copy
    }
}
