// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Native artwork collections embedded in a list section.
@available(iOS 26.0, *)
@MainActor
public struct CarPlayImageRow {

    let title: String?
    let style: Style
    let allowsMultipleLines: Bool
    let elements: [CarPlayImageElement]
    private var identity: AnyHashable?
    private var isEnabled = true

    /// Creates an iOS 26 artwork collection for a list section.
    ///
    /// - Parameters:
    ///   - title: Optional text above the artwork collection.
    ///   - style: The native layout. Defaults to an image grid.
    ///   - allowsMultipleLines: Whether the row permits multiline presentation.
    ///   - content: One or more artwork elements within the native image-count
    ///     limit. The builder is evaluated immediately.
    public init(
        _ title: String? = nil,
        style: Style = .imageGrid,
        allowsMultipleLines: Bool = true,
        @CarPlayImageElementBuilder content: () -> [CarPlayImageElement]
    ) {

        self.title = title
        self.style = style
        self.allowsMultipleLines = allowsMultipleLines
        self.elements = content()
    }

    /// Assigns a stable identity to this image row.
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

    /// Controls whether the image row can be selected.
    ///
    /// - Parameter disabled: `true` to disable selection; defaults to `true`.
    /// - Returns: A copy with the requested availability.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }

    var row: CarPlayRow {

        var row = CarPlayRow(self.title ?? "")
        row.identity = self.identity
        row.isEnabled = self.isEnabled
        row.imageRow = CarPlayImageRowContent(
            layout: AnyHashable(self.layout),
            elementIDs: self.elements.compactMap(\.identity),
            actions: self.elements.map { $0.isEnabled ? $0.action : nil },
            identities: self.elements.map(\.identity),
            policies: self.elements.map(\.repeatPolicy),
            make: self.makeNative,
            update: self.updateNative
        )

        return row
    }

    private var layout: Layout {

        Layout(
            style: self.style,
            allowsMultipleLines: self.allowsMultipleLines,
            elements: self.elements.enumerated().map { index, element in

                ElementLayout(
                    identity: element.identity,
                    position: index,
                    shape: element.imageShape,
                    fillsCard: element.fillsCard
                )
            }
        )
    }
}

public extension CarPlayArrayBuilder where Element == CarPlayRow {

    /// Adapts a single iOS 26 artwork row into a list section’s row collection.
    ///
    /// - Parameter expression: The artwork row to embed.
    /// - Returns: One type-erased list row.
    @available(iOS 26.0, *)
    @MainActor
    static func buildExpression(_ expression: CarPlayImageRow) -> [CarPlayRow] {

        [expression.row]
    }

    /// Adapts an array of iOS 26 artwork rows into list section content.
    ///
    /// - Parameter expression: The artwork rows in display order.
    /// - Returns: Type-erased list rows preserving input order.
    @available(iOS 26.0, *)
    @MainActor
    static func buildExpression(_ expression: [CarPlayImageRow]) -> [CarPlayRow] {

        expression.map(\.row)
    }
}

@available(iOS 26.0, *)
private extension CarPlayImageRow {

    /// Structural artwork-row identity; content-only changes can reuse native items.
    struct Layout: Hashable {

        let style: Style
        let allowsMultipleLines: Bool
        let elements: [ElementLayout]
    }

    /// Element shape and position needed to decide native row compatibility.
    struct ElementLayout: Hashable {

        let identity: AnyHashable?
        let position: Int
        let shape: CarPlayImageElement.Shape
        let fillsCard: Bool
    }
}
