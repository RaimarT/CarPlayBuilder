// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers native empty-view text, updates, defaults, and loading presentation.
@MainActor
struct CarPlayEmptyViewTests {

    @Test
    func `empty text updates in place and omitted configuration restores defaults`(
    ) throws {

        let node = try self.mount(self.list())
        let list = try #require(node.template as? CPListTemplate)
        let titles = list.emptyViewTitleVariants
        let subtitles = list.emptyViewSubtitleVariants
        let section = list.sections[0]
        let row = section.items[0]
        try node.update(self.list().emptyView(
            titleVariants: ["No saved episodes", "No episodes"],
            subtitleVariants: ["Save episodes on your iPhone", "Save on iPhone"]
        )._resolve())
        #expect(list.emptyViewTitleVariants == ["No saved episodes", "No episodes"])
        #expect(list.emptyViewSubtitleVariants == [
            "Save episodes on your iPhone",
            "Save on iPhone"
        ])
        #expect(list.sections[0] === section)
        #expect(list.sections[0].items[0] === row)
        try node.update(self.list().emptyView(titleVariants: ["Nothing here"])
            ._resolve())
        #expect(list.emptyViewTitleVariants == ["Nothing here"])
        #expect(list.emptyViewSubtitleVariants.isEmpty)
        try node.update(self.list()._resolve())
        #expect(node.template === list)
        #expect(list.emptyViewTitleVariants == titles)
        #expect(list.emptyViewSubtitleVariants == subtitles)
        node.cancel()
    }

    @Test
    func `fallback persists through empty populated and empty lists`() throws {

        let node = try self.mount(self.list(empty: true).emptyView(
            titleVariants: ["Nothing saved"],
            subtitleVariants: ["Save an episode"]
        ))
        let list = try #require(node.template as? CPListTemplate)
        #expect(list.itemCount == 0)
        for empty in [false, true] {

            try node.update(self.list(empty: empty).emptyView(
                titleVariants: ["Nothing saved"],
                subtitleVariants: ["Save an episode"]
            )._resolve())
            #expect(node.template === list)
            #expect(list.itemCount == (empty ? 0 : 1))
            #expect(list.emptyViewTitleVariants == ["Nothing saved"])
            #expect(list.emptyViewSubtitleVariants == ["Save an episode"])
        }
        node.cancel()
    }

    @Test
    func `empty arrays explicitly clear previously supplied native text`() throws {

        let node = try self.mount(CarPlayList {}.emptyView(
            titleVariants: ["No episodes"],
            subtitleVariants: ["Save on iPhone"]
        ))
        let list = try #require(node.template as? CPListTemplate)
        try node.update(CarPlayList {}.emptyView(titleVariants: [])._resolve())
        #expect(list.emptyViewTitleVariants.isEmpty)
        #expect(list.emptyViewSubtitleVariants.isEmpty)
        #expect(list.itemCount == 0)
        node.cancel()
    }

    @Test
    func `loading rows preserve fallback text and empty builders leave zero items`(
    ) throws {

        let template = self.list(empty: true).emptyView(
            titleVariants: ["No saved episodes"],
            subtitleVariants: ["Save on iPhone"]
        )
        let node = try self.mount(template.loadingState(.loading))
        let list = try #require(node.template as? CPListTemplate)
        #expect(list.itemCount == 1)
        #expect(list.sections[0].items[0].text == "Loading…")
        #expect(list.emptyViewTitleVariants == ["No saved episodes"])
        try node.update(template.loadingState(
            .loaded,
            isEmpty: true,
            empty: { [] }
        )._resolve())
        #expect(node.template === list)
        #expect(list.itemCount == 0)
        #expect(list.emptyViewTitleVariants == ["No saved episodes"])
        #expect(list.emptyViewSubtitleVariants == ["Save on iPhone"])
        node.cancel()
    }

    @Test
    @available(iOS 18.4, *)
    func `spinner changes preserve rows and omission restores native defaults`(
    ) throws {

        let node = try self.mount(self.list())
        let list = try #require(node.template as? CPListTemplate)
        let original = list.showsSpinnerWhileEmpty
        let section = list.sections[0]
        let row = section.items[0]
        for visible in [true, false, true] {

            try node.update(self.list().showsSpinnerWhileEmpty(visible)._resolve())
            #expect(list.showsSpinnerWhileEmpty == visible)
            #expect(list.sections[0] === section)
            #expect(section.items[0] === row)
        }
        try node.update(self.list()._resolve())
        #expect(list.showsSpinnerWhileEmpty == original)
        node.cancel()
    }

    @Test
    @available(iOS 18.4, *)
    func `spinner combines with empty text through populated list transitions`(
    ) throws {

        let template = self.list(empty: true).emptyView(
            titleVariants: ["Loading episodes"],
            subtitleVariants: ["Please wait"]
        ).showsSpinnerWhileEmpty()
        let node = try self.mount(template)
        let list = try #require(node.template as? CPListTemplate)
        #expect(list.itemCount == 0)
        #expect(list.showsSpinnerWhileEmpty)
        try node.update(self.list().emptyView(
            titleVariants: ["Loading episodes"],
            subtitleVariants: ["Please wait"]
        ).showsSpinnerWhileEmpty()._resolve())
        #expect(node.template === list)
        #expect(list.itemCount == 1)
        #expect(list.showsSpinnerWhileEmpty)
        try node.update(template._resolve())
        #expect(list.itemCount == 0)
        #expect(list.showsSpinnerWhileEmpty)
        #expect(list.emptyViewTitleVariants == ["Loading episodes"])
        #expect(list.emptyViewSubtitleVariants == ["Please wait"])
        node.cancel()
    }

    @Test
    @available(iOS 18.4, *)
    func `loading presentation preserves spinner and can leave zero items`(
    ) throws {

        let template = self.list(empty: true).showsSpinnerWhileEmpty()
        let node = try self.mount(template.loadingState(.loading))
        let list = try #require(node.template as? CPListTemplate)
        #expect(list.itemCount == 1)
        #expect(list.showsSpinnerWhileEmpty)
        try node.update(template.loadingState(
            .loading,
            loading: { [] }
        )._resolve())
        #expect(list.itemCount == 0)
        #expect(list.showsSpinnerWhileEmpty)
        try node.update(template.showsSpinnerWhileEmpty(false).loadingState(
            .loaded,
            isEmpty: true,
            empty: { [] }
        )._resolve())
        #expect(list.itemCount == 0)
        #expect(!list.showsSpinnerWhileEmpty)
        node.cancel()
    }
}

private extension CarPlayEmptyViewTests {

    func list(empty: Bool = false) -> CarPlayList {

        CarPlayList("Library") {

            CarPlaySection {

                if !empty {

                    CarPlayRow("Episode").id("episode")
                }
            }.id("episodes")
        }
    }

    func mount(_ template: some CarPlayTemplate) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { Issue.record("Unexpected empty-view error: \($0)") }
        )
    }
}
