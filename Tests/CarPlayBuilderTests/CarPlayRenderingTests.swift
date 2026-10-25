// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers native content reconciliation and validation of observed updates.
@MainActor
struct CarPlayRenderingTests {

    @Test
    func `progress updates preserve native sections and rows`() throws {

        let node = try self.mount(self.list(progress: 0))
        let list = try #require(node.template as? CPListTemplate)
        let section = list.sections[0]
        let row = try #require(section.items[0] as? CPListItem)
        try node.update(self.list(progress: 0.5)._resolve())
        #expect(list.sections[0] === section)
        #expect(section.items[0] === row)
        #expect(row.playbackProgress == 0.5)
    }

    @Test
    func `grid identity survives reordering`() throws {

        let image = UIImage()
        let node = try self.mount(self.grid([1, 2], image: image) { _ in })
        let grid = try #require(node.template as? CPGridTemplate)
        let first = grid.gridButtons[0]
        try node.update(self.grid([2, 1], image: image) { _ in }._resolve())
        #expect(grid.gridButtons[1] === first)
    }

    @Test
    func `grid visual changes use the available native update API`() throws {

        let node = try self.mount(self.singleButton("Before", image: UIImage()))
        let grid = try #require(node.template as? CPGridTemplate)
        let button = grid.gridButtons[0]
        let image = UIImage()
        try node.update(self.singleButton("After", image: image)._resolve())
        if #available(iOS 26.0, *) {

            #expect(grid.gridButtons[0] === button)
        } else {

            #expect(grid.gridButtons[0] !== button)
        }
        #expect(grid.gridButtons[0].titleVariants == ["After"])
        #expect(grid.gridButtons[0].image === image)
    }

    @Test
    func `duplicate grid button identities are rejected`() {

        #expect(throws: CarPlayError.self) {

            try self.mount(self.grid([1, 1], image: UIImage()) { _ in })
        }
    }

    @Test
    @available(iOS 26.0, *)
    func `image row updates preserve elements and selection uses latest action`(
    ) async
        throws {

        let originalImage = UIImage()
        let updatedImage = UIImage()
        let completed = AsyncStream<Void>.makeStream()
        let node = try self.mount(self.imageList("Before", image: originalImage) {})
        let list = try #require(node.template as? CPListTemplate)
        let row = try #require(list.sections[0].items[0] as? CPListImageRowItem)
        let element = try #require(row.elements[0] as? CPListImageRowItemRowElement)
        try node.update(self.imageList("After", image: updatedImage) {

            completed.continuation.yield(())
        }._resolve())
        #expect(list.sections[0].items[0] === row)
        #expect(row.elements[0] === element)
        #expect(element.title == "After")
        #expect(element.image === updatedImage)
        row.listImageRowHandler?(row, 0) {}
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        node.cancel()
    }
}

private extension CarPlayRenderingTests {

    func list(progress: Double) -> CarPlayList {

        CarPlayList {

            CarPlaySection {

                CarPlayRow("Track").id(1).playback(
                    isPlaying: true,
                    progress: progress
                )
            }.id("tracks")
        }
    }

    func singleButton(_ title: String, image: UIImage) -> CarPlayGrid {

        CarPlayGrid {

            CarPlayButton(title, image: image) { _ in }.id(1)
        }
    }

    func grid(
        _ ids: [Int],
        image: UIImage,
        action: @escaping @MainActor (Int) -> Void
    ) -> CarPlayGrid {

        CarPlayGrid {

            for id in ids {

                CarPlayButton("Track \(id)", image: image) { _ in action(id) }.id(id)
            }
        }
    }

    @available(iOS 26.0, *)
    func imageList(
        _ title: String,
        image: UIImage,
        action: @escaping @MainActor () -> Void
    ) -> CarPlayList {

        CarPlayList {

            CarPlaySection {

                CarPlayImageRow(style: .row) {

                    CarPlayImageElement(title, image: image) { _ in action() }.id(1)
                }.id("artwork")
            }
        }
    }

    func mount(
        _ template: some CarPlayTemplate
    ) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { Issue.record("Unexpected rendering error: \($0)") }
        )
    }
}
