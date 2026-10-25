// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers header rendering, reconciliation, validation, and action ownership.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlaySectionHeaderTests {

    @Test
    func `rich headers render and updates preserve rows`() throws {

        let image = UIImage()
        let node = try self.mount(self.list(subtitle: "Before", image: image))
        let list = try #require(node.template as? CPListTemplate)
        let original = list.sections[0]
        let row = original.items[0]
        #expect(original.header == "Recently played")
        #expect(original.headerSubtitle == "Before")
        #expect(original.headerImage === image)
        #expect(original.sectionIndexTitle == "R")
        #expect(original.headerButton?.title == "Show all")
        try node.update(self.list(subtitle: "After", image: image)._resolve())
        #expect(list.sections[0] !== original)
        #expect(list.sections[0].headerSubtitle == "After")
        #expect(list.sections[0].items[0] === row)
        #expect(list.sections[0].headerButton === original.headerButton)
        let updated = list.sections[0]
        try node.update(self.list(subtitle: "After", image: image)._resolve())
        #expect(list.sections[0] === updated)
        node.cancel()
    }

    @Test
    func `header buttons follow section identity across reordering`() throws {

        let node = try self.mount(self.sections([1, 2], disabled: false))
        let list = try #require(node.template as? CPListTemplate)
        let button = try #require(list.sections[0].headerButton)
        try node.update(self.sections([2, 1], disabled: true)._resolve())
        #expect(list.sections[1].headerButton === button)
        #expect(button.title == "Open 1")
        #expect(!button.isEnabled)
        try node.update(CarPlayList {}._resolve())
        try node.update(self.sections([1], disabled: false)._resolve())
        #expect(list.sections[0].headerButton !== button)
        node.cancel()
    }

    @Test
    func `removing rich header details keeps row identity`() throws {

        let node = try self.mount(self.list(subtitle: "Details", image: UIImage()))
        let list = try #require(node.template as? CPListTemplate)
        let row = list.sections[0].items[0]
        try node.update(CarPlayList {

            CarPlaySection(sectionIndexTitle: "T") {

                CarPlayRow("Track").id(1)
            }.id("recent")
        }._resolve())
        let section = list.sections[0]
        #expect(section.items[0] === row)
        #expect(section.header == nil)
        #expect(section.headerSubtitle == nil)
        #expect(section.headerImage == nil)
        #expect(section.headerButton == nil)
        #expect(section.sectionIndexTitle == "T")
        node.cancel()
    }

    @Test
    func `invalid headers reject updates before mutating native content`() throws {

        let node = try self.mount(self.list(subtitle: "Valid", image: UIImage()))
        let list = try #require(node.template as? CPListTemplate)
        let original = list.sections[0]
        let invalid = [
            CarPlaySection(subtitle: "Missing title") {},
            CarPlaySection(image: UIImage()) {},
            CarPlaySection(button: .init("Open") { _ in }) {},
            CarPlaySection("Header", button: .init("") { _ in }) {}
        ]
        for section in invalid {

            #expect(throws: CarPlayError.self) {

                try node.update(CarPlayList { section }._resolve())
            }
            #expect(list.sections[0] === original)
        }
        node.cancel()
    }

    @Test
    func `header image and index changes replace the section`() throws {

        let image = UIImage()
        let node = try self.mount(self.list(subtitle: "Details", image: image))
        let list = try #require(node.template as? CPListTemplate)
        let original = list.sections[0]
        let replacement = UIImage()
        try node
            .update(self.list(subtitle: "Details", image: replacement)._resolve())
        #expect(list.sections[0] !== original)
        #expect(list.sections[0].headerImage === replacement)
        let updated = list.sections[0]
        try node.update(CarPlayList {

            CarPlaySection("Recently played", sectionIndexTitle: "Z") {

                CarPlayRow("Track").id(1)
            }.id("recent")
        }._resolve())
        #expect(list.sections[0] !== updated)
        #expect(list.sections[0].sectionIndexTitle == "Z")
        node.cancel()
    }

    @Test
    func `header action uses latest callback and ignores disabled stale taps`(
    ) async {

        let completed = AsyncStream<Void>.makeStream()
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let mounted = CarPlayMountedSectionHeaderButton(
            content: .init("Old") { _ in Issue.record("Stale action") },
            context: .init(),
            scope: scope
        )
        let original = mounted.item
        var calls = 0
        mounted.update(.init("New") { _ in

            calls += 1
            completed.continuation.yield(())
        })
        #expect(mounted.item === original)
        #expect(original.title == "New")
        mounted.activate()
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        mounted.update(CarPlaySectionHeaderButton("Disabled") { _ in

            Issue.record("Disabled action")
        }.disabled())
        #expect(!original.isEnabled)
        mounted.activate()
        mounted.update(.init("Removed") { _ in Issue.record("Removed action") })
        mounted.cancel()
        mounted.activate()
        #expect(calls == 1)
        scope.cancel()
    }

    @Test
    func `header action errors reach the screen error handler`() async {

        let failed = AsyncStream<Bool>.makeStream()
        let scope = CarPlayTaskScope(onError: {

            failed.continuation.yield($0 is HeaderError)
        })
        let mounted = CarPlayMountedSectionHeaderButton(
            content: .init("Fail") { _ in throw HeaderError.expected },
            context: .init(),
            scope: scope
        )
        mounted.activate()
        var iterator = failed.stream.makeAsyncIterator()
        #expect(await iterator.next() == true)
        scope.cancel()
    }

    @Test
    func `screen scope cancellation cancels header selection work`() async {

        let started = AsyncStream<Void>.makeStream()
        let finished = AsyncStream<Bool>.makeStream()
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let mounted = CarPlayMountedSectionHeaderButton(
            content: .init("Wait") { _ in

                started.continuation.yield(())

                do {

                    try await Task.sleep(for: .seconds(60))
                    Issue.record("Selection was not cancelled")
                } catch {

                    finished.continuation.yield(error is CancellationError)
                    throw error
                }
            },
            context: .init(),
            scope: scope
        )
        mounted.activate()
        var start = started.stream.makeAsyncIterator()
        _ = await start.next()
        scope.cancel()
        var finish = finished.stream.makeAsyncIterator()
        #expect(await finish.next() == true)
    }
}

private extension CarPlaySectionHeaderTests {

    func list(subtitle: String, image: UIImage) -> CarPlayList {

        CarPlayList {

            CarPlaySection(
                "Recently played",
                subtitle: subtitle,
                image: image,
                button: .init("Show all") { _ in },
                sectionIndexTitle: "R"
            ) {

                CarPlayRow("Track").id(1)
            }.id("recent")
        }
    }

    func sections(_ ids: [Int], disabled: Bool) -> CarPlayList {

        CarPlayList {

            for id in ids {

                CarPlaySection(
                    "Section \(id)",
                    button: CarPlaySectionHeaderButton("Open \(id)") { _ in }
                        .disabled(disabled)
                ) {

                    CarPlayRow("Track").id(1)
                }.id(id)
            }
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

private extension CarPlaySectionHeaderTests {

    enum HeaderError: Error {

        case expected
    }
}
