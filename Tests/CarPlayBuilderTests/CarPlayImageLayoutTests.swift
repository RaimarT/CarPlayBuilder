// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers iOS 26 artwork layout construction and native item reuse.
@MainActor
struct CarPlayImageLayoutTests {

    @Test
    func `all artwork layouts retain elements and update content`() throws {

        guard #available(iOS 26.0, *) else {

            return
        }

        for style in CarPlayImageRow.Style.allCases {

            let node = try self.mount(self.list(
                style,
                title: "Before",
                image: UIImage()
            ))
            let list = try #require(node.template as? CPListTemplate)
            let row = try #require(list.sections[0].items[0] as? CPListImageRowItem)
            let element = row.elements[0]
            let image = UIImage()
            try node
                .update(self.list(style, title: "After", image: image)._resolve())
            #expect(list.sections[0].items[0] === row)
            #expect(row.elements[0] === element)
            #expect(row.text == "Header After")
            #expect(element.image === image)
            #expect(!element.isEnabled)
            self.checkText(element)
        }
    }

    @Test
    func `structural layout changes replace native image rows`() throws {

        guard #available(iOS 26.0, *) else {

            return
        }

        let node = try self.mount(self.list(.row, title: "Before", image: UIImage()))
        let list = try #require(node.template as? CPListTemplate)
        let row = list.sections[0].items[0]
        try node
            .update(self.list(.card, title: "Before", image: UIImage())._resolve())
        #expect(list.sections[0].items[0] !== row)
    }

    @Test
    func `disabled image selection still completes without invoking its action`(
    ) throws {

        guard #available(iOS 26.0, *) else {

            return
        }

        let node = try self.mount(self.list(.row, title: "After", image: UIImage()))
        let list = try #require(node.template as? CPListTemplate)
        let row = try #require(list.sections[0].items[0] as? CPListImageRowItem)
        var completions = 0
        row.listImageRowHandler?(row, 0) { completions += 1 }
        row.listImageRowHandler?(row, 999) { completions += 1 }
        #expect(completions == 2)
    }

    @Test
    func `empty excessive and duplicate image elements are rejected`() {

        guard #available(iOS 26.0, *) else {

            return
        }

        let rows = [
            CarPlayImageRow {},
            CarPlayImageRow {

                for _ in 0 ... Int(CPMaximumNumberOfGridImages) {

                    CarPlayImageElement("Many", image: UIImage())
                }
            },
            CarPlayImageRow {

                CarPlayImageElement("One", image: UIImage()).id(1)
                CarPlayImageElement("Two", image: UIImage()).id(1)
            }
        ]
        for row in rows {

            #expect(throws: CarPlayError.self) {

                try self.mount(CarPlayList { CarPlaySection { row } })
            }
        }
    }

    @Test
    func `array image rows support row modifiers and single-line configuration`(
    ) throws {

        guard #available(iOS 26.0, *) else {

            return
        }

        let image = UIImage()
        let rows = [CarPlayImageRow(style: .condensed, allowsMultipleLines: false) {

            CarPlayImageElement("Track", image: image).shape(.roundedRectangle)
        }.disabled()]
        let node = try self.mount(CarPlayList { CarPlaySection { rows } })
        let list = try #require(node.template as? CPListTemplate)
        let row = try #require(list.sections[0].items[0] as? CPListImageRowItem)
        #expect(!row.isEnabled)
    }
}

@available(iOS 26.0, *)
private extension CarPlayImageLayoutTests {

    func list(
        _ style: CarPlayImageRow.Style,
        title: String,
        image: UIImage
    ) -> CarPlayList {

        CarPlayList {

            CarPlaySection {

                CarPlayImageRow("Header \(title)", style: style) {

                    CarPlayImageElement(
                        title,
                        subtitle: "Detail \(title)",
                        image: image
                    ) {
                        _ in Issue.record("Disabled selection must be ignored")
                    }
                    .id("track").shape(.circular).fullHeightImage()
                    .tint(title == "Before" ? .red : .blue)
                    .accessorySymbol(title == "Before" ? "play" : "pause")
                    .disabled(title == "After")
                }.id("artwork")
            }
        }
    }

    func checkText(_ element: CPListImageRowItemElement) {

        if let row = element as? CPListImageRowItemRowElement {

            #expect(row.title == "After")
            #expect(row.subtitle == "Detail After")
        }
        if let card = element as? CPListImageRowItemCardElement {

            #expect(card.title == "After")
            #expect(card.subtitle == "Detail After")
            #expect(card.tintColor == .blue)
        }
        if let condensed = element as? CPListImageRowItemCondensedElement {

            #expect(condensed.title == "After")
            #expect(condensed.subtitle == "Detail After")
            #expect(condensed.accessorySymbolName == "pause")
        }
        if let grid = element as? CPListImageRowItemImageGridElement {

            #expect(grid.title == "After")
            #expect(grid.accessorySymbolName == "pause")
        }
    }

    func mount(_ template: some CarPlayTemplate) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { Issue.record("Error: \($0)") }
        )
    }
}
