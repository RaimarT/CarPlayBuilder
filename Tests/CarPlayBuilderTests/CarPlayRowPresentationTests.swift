// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers native row indicators and their interaction with artwork and playback.
@MainActor
struct CarPlayRowPresentationTests {

    @Test
    func `row indicators update in place and reset to defaults`() throws {

        let base = CarPlayRow("Episode").id("episode")
        let node = try self.mount([base])
        let list = try #require(node.template as? CPListTemplate)
        let section = list.sections[0]
        let item = try #require(section.items[0] as? CPListItem)
        #expect(!item.isExplicitContent)
        #expect(item.playingIndicatorLocation == .leading)
        let updated = base.explicitContent()
            .playingIndicatorLocation(.trailing)
            .playback(isPlaying: true, progress: 0.4)
        try node.update(self.list([updated])._resolve())
        #expect(list.sections[0] === section)
        #expect(section.items[0] === item)
        #expect(item.isExplicitContent)
        #expect(item.playingIndicatorLocation == .trailing)
        #expect(item.isPlaying)
        #expect(item.playbackProgress == 0.4)
        try node.update(self.list([base])._resolve())
        #expect(list.sections[0] === section)
        #expect(section.items[0] === item)
        #expect(!item.isExplicitContent)
        #expect(item.playingIndicatorLocation == .leading)
        #expect(!item.isPlaying)
        #expect(item.playbackProgress == 0)
        node.cancel()
    }

    @Test
    func `explicit flag and indicator placement are independent of playback`(
    ) throws {

        let row = CarPlayRow("Episode")
            .explicitContent()
            .explicitContent(false)
            .playingIndicatorLocation(.trailing)
            .playback(isPlaying: false, progress: 0.6)
        let node = try self.mount([row])
        let list = try #require(node.template as? CPListTemplate)
        let item = try #require(list.sections[0].items[0] as? CPListItem)
        #expect(!item.isExplicitContent)
        #expect(item.playingIndicatorLocation == .trailing)
        #expect(!item.isPlaying)
        #expect(item.playbackProgress == 0.6)
        let updated = row.playback(isPlaying: true, progress: 0.8)
        try node.update(self.list([updated])._resolve())
        #expect(item.playingIndicatorLocation == .trailing)
        #expect(!item.isExplicitContent)
        #expect(item.isPlaying)
        #expect(item.playbackProgress == 0.8)
        node.cancel()
    }

    @Test
    func `indicator updates preserve artwork accessory precedence and identity`(
    ) throws {

        let leading = UIImage()
        let trailing = UIImage()
        let row = CarPlayRow("Episode", detail: "Podcast", image: leading)
            .id("episode")
            .trailingImage(trailing)
            .accessory(.disclosureIndicator)
            .explicitContent()
            .playingIndicatorLocation(.trailing)
            .playback(isPlaying: true, progress: 0.5)
        let other = CarPlayRow("Other").id("other")
        let node = try self.mount([row, other])
        let list = try #require(node.template as? CPListTemplate)
        let item = try #require(list.sections[0].items[0] as? CPListItem)
        #expect(item.image === leading)
        #expect(item.accessoryImage === trailing)
        #expect(item.accessoryType == .none)
        #expect(item.isExplicitContent)
        #expect(item.playingIndicatorLocation == .trailing)
        let updated = row.trailingImage(nil).playingIndicatorLocation(.leading)
        try node.update(self.list([other, updated])._resolve())
        #expect(list.sections[0].items[1] === item)
        #expect(item.image === leading)
        #expect(item.accessoryImage == nil)
        #expect(item.accessoryType == .disclosureIndicator)
        #expect(item.isExplicitContent)
        #expect(item.playingIndicatorLocation == .leading)
        #expect(item.isPlaying)
        #expect(item.playbackProgress == 0.5)
        node.cancel()
    }
}

private extension CarPlayRowPresentationTests {

    func list(_ rows: [CarPlayRow]) -> CarPlayList {

        CarPlayList {

            CarPlaySection { rows }.id("episodes")
        }
    }

    func mount(_ rows: [CarPlayRow]) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: self.list(rows)._resolve(),
            context: .init(),
            onError: { Issue.record("Unexpected rendering error: \($0)") }
        )
    }
}
