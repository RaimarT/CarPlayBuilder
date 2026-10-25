// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

@available(iOS 26.0, *)
extension CarPlayImageRow {

    /// Constructs the native row and element subclasses for the selected layout.
    func makeNative() -> CPListImageRowItem {

        let elements = self.elements.map { self.makeElement($0) }

        switch self.style {


        case .row:
            return CPListImageRowItem(
                text: self.title,
                elements: elements
                    .compactMap { $0 as? CPListImageRowItemRowElement },
                allowsMultipleLines: self.allowsMultipleLines
            )

        case .card:
            return self.makeCardRow(elements)

        case .condensed:
            return self.makeCondensedRow(elements)

        case .grid:
            return self.makeGridRow(elements)

        case .imageGrid:
            return self.makeImageGridRow(elements)
        }
    }

    /// Updates mutable artwork, text, and actions on a structurally matching row.
    ///
    /// The renderer replaces the row when its layout key changes; this method
    /// assumes element count, order, shape, and card fill are already compatible.
    func updateNative(_ item: CPListImageRowItem) {

        if item.text != self.title {

            item.text = self.title
        }

        for (native, element) in zip(item.elements, self.elements) {

            if native.image !== element.image {

                native.image = element.image
            }

            self.updateText(native, element: element)
        }
    }
}

@available(iOS 26.0, *)
private extension CarPlayImageRow {

    func makeCardRow(_ elements: [CPListImageRowItemElement]) -> CPListImageRowItem {

        CPListImageRowItem(
            text: self.title,
            cardElements: elements
                .compactMap { $0 as? CPListImageRowItemCardElement },
            allowsMultipleLines: self.allowsMultipleLines
        )
    }

    func makeCondensedRow(
        _ elements: [CPListImageRowItemElement]
    ) -> CPListImageRowItem {

        CPListImageRowItem(
            text: self.title,
            condensedElements: elements.compactMap {
                $0 as? CPListImageRowItemCondensedElement
            },
            allowsMultipleLines: self.allowsMultipleLines
        )
    }

    func makeGridRow(_ elements: [CPListImageRowItemElement]) -> CPListImageRowItem {

        CPListImageRowItem(
            text: self.title,
            gridElements: elements
                .compactMap { $0 as? CPListImageRowItemGridElement },
            allowsMultipleLines: self.allowsMultipleLines
        )
    }

    func makeImageGridRow(
        _ elements: [CPListImageRowItemElement]
    ) -> CPListImageRowItem {

        CPListImageRowItem(
            text: self.title,
            imageGridElements: elements.compactMap {
                $0 as? CPListImageRowItemImageGridElement
            },
            allowsMultipleLines: self.allowsMultipleLines
        )
    }

    func makeElement(_ element: CarPlayImageElement) -> CPListImageRowItemElement {

        switch self.style {

        case .row:
            CPListImageRowItemRowElement(
                image: element.image,
                title: element.title,
                subtitle: element.subtitle
            )

        case .card:
            CPListImageRowItemCardElement(
                image: element.image,
                showsImageFullHeight: element.fillsCard,
                title: element.title,
                subtitle: element.subtitle,
                tintColor: element.tintColor
            )

        case .condensed:
            self.makeCondensedElement(element)

        case .grid:
            CPListImageRowItemGridElement(image: element.image)

        case .imageGrid:
            self.makeImageGridElement(element)
        }
    }

    func makeCondensedElement(
        _ element: CarPlayImageElement
    ) -> CPListImageRowItemCondensedElement {

        CPListImageRowItemCondensedElement(
            image: element.image,
            imageShape: element
                .imageShape == .circular ? .circular : .roundedRectangle,
            title: element.title,
            subtitle: element.subtitle,
            accessorySymbolName: element.accessorySymbolName
        )
    }

    func makeImageGridElement(
        _ element: CarPlayImageElement
    ) -> CPListImageRowItemImageGridElement {

        CPListImageRowItemImageGridElement(
            image: element.image,
            imageShape: element
                .imageShape == .circular ? .circular : .roundedRectangle,
            title: element.title,
            accessorySymbolName: element.accessorySymbolName
        )
    }

    func updateText(
        _ native: CPListImageRowItemElement,
        element: CarPlayImageElement
    ) {

        switch native {

        case let row as CPListImageRowItemRowElement:
            self.updateRow(row, element: element)

        case let card as CPListImageRowItemCardElement:
            self.updateCard(card, element: element)

        case let condensed as CPListImageRowItemCondensedElement:
            self.updateCondensed(condensed, element: element)

        case let grid as CPListImageRowItemImageGridElement:
            self.updateImageGrid(grid, element: element)

        default:
            break
        }
    }

    func updateRow(
        _ row: CPListImageRowItemRowElement,
        element: CarPlayImageElement
    ) {

        if row.title != element.title {

            row.title = element.title
        }

        if row.subtitle != element.subtitle {

            row.subtitle = element.subtitle
        }
    }

    func updateCard(
        _ card: CPListImageRowItemCardElement,
        element: CarPlayImageElement
    ) {

        if card.title != element.title {

            card.title = element.title
        }

        if card.subtitle != element.subtitle {

            card.subtitle = element.subtitle
        }

        if card.tintColor != element.tintColor {

            card.tintColor = element.tintColor
        }
    }

    func updateCondensed(
        _ condensed: CPListImageRowItemCondensedElement,
        element: CarPlayImageElement
    ) {

        if condensed.title != element.title {

            condensed.title = element.title
        }

        if condensed.subtitle != element.subtitle {

            condensed.subtitle = element.subtitle
        }

        if condensed.accessorySymbolName != element.accessorySymbolName {

            condensed.accessorySymbolName = element.accessorySymbolName
        }
    }

    func updateImageGrid(
        _ grid: CPListImageRowItemImageGridElement,
        element: CarPlayImageElement
    ) {

        if grid.title != element.title {

            grid.title = element.title
        }

        if grid.accessorySymbolName != element.accessorySymbolName {

            grid.accessorySymbolName = element.accessorySymbolName
        }
    }
}
