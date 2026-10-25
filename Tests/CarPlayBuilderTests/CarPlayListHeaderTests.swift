// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers rich list headers, reconciliation, validation, and selection work.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayListHeaderTests {

    @Test
    @available(iOS 26.4, *)
    func `header content updates preserve native header list and rows`() throws {

        let initialImage = UIImage()
        let node = try self.mount(self.list(self.header("Before", initialImage)))
        let list = try #require(node.template as? CPListTemplate)
        let header = try #require(list.listHeader)
        let section = list.sections[0]
        let row = section.items[0]
        #expect(header.title == "Before")
        #expect(header.subtitle == "Artist Before")
        #expect(header.thumbnail.image === initialImage)
        let image = UIImage()
        try node.update(self.list(self.header("After", image))._resolve())
        #expect(node.template === list)
        #expect(list.listHeader === header)
        #expect(header.title == "After")
        #expect(header.subtitle == "Artist After")
        #expect(header.thumbnail.image === image)
        #expect(list.sections[0] === section)
        #expect(section.items[0] === row)
        #expect(list.title == "Library")
        node.cancel()
    }

    @Test
    @available(iOS 26.4, *)
    func `header action identity survives reorder and replaces changed images`(
    ) throws {

        let image = UIImage()
        let node = try self.mount(self.list(self.actions([1, 2], image: image)))
        let list = try #require(node.template as? CPListTemplate)
        let header = try #require(list.listHeader)
        let first = header.actionButtons[0]
        let second = header.actionButtons[1]
        try node.update(self.list(self.actions(
            [2, 1],
            image: image,
            disabled: true
        ))._resolve())
        #expect(header.actionButtons[1] === first)
        #expect(!first.isEnabled)
        #expect(first.title == "Play 1")
        try node.update(self.list(self.actions([1, 2], image: UIImage()))._resolve())
        #expect(header.actionButtons[0] === first)
        #expect(header.actionButtons[1] !== second)
        #expect(first.isEnabled)
        node.cancel()
    }

    @Test
    @available(iOS 26.4, *)
    func `headers survive loading and can be removed explicitly or by omission`(
    ) throws {

        let template = self.list(self.header("Album", UIImage()))
        let node = try self.mount(template)
        let list = try #require(node.template as? CPListTemplate)
        let header = try #require(list.listHeader)
        try node.update(template.loadingState(.loading)._resolve())
        #expect(list.listHeader === header)
        #expect(list.sections[0].items[0].text == "Loading…")
        try node.update(template.listHeader(nil)._resolve())
        #expect(list.listHeader == nil)
        try node.update(template._resolve())
        #expect(list.listHeader != nil)
        #expect(list.listHeader !== header)
        try node.update(CarPlayList("Library") {}._resolve())
        #expect(list.listHeader == nil)
        node.cancel()
    }

    @Test
    @available(iOS 26.4, *)
    func `invalid header actions preserve the previous native content`() throws {

        let node = try self.mount(self.list(self.header("Valid", UIImage())))
        let list = try #require(node.template as? CPListTemplate)
        let original = list.listHeader
        let invalid: [[CarPlayListHeaderButton]] = [
            [CarPlayListHeaderButton("") { _ in }],
            [
                CarPlayListHeaderButton("One") { _ in }.id(1),
                CarPlayListHeaderButton("Two") { _ in }.id(1)
            ],
            (0 ... CPListTemplateDetailsHeader.maximumActionButtonCount).map {

                CarPlayListHeaderButton("Action \($0)") { _ in }
            }
        ]
        for buttons in invalid {

            let header = CarPlayListHeader("Invalid", image: UIImage()) { buttons }
            #expect(throws: CarPlayError.self) {

                try node.update(self.list(header)._resolve())
            }
            #expect(list.listHeader === original)
            #expect(list.listHeader?.title == "Valid")
        }
        node.cancel()
    }

    @Test
    @available(iOS 26.4, *)
    func `optional text clears in place and an artwork-only header is allowed`(
    ) throws {

        let image = UIImage()
        let node = try self.mount(self.list(self.header("Album", image)))
        let list = try #require(node.template as? CPListTemplate)
        let header = try #require(list.listHeader)
        try node.update(self.list(CarPlayListHeader(image: image))._resolve())
        #expect(list.listHeader === header)
        #expect(header.title == nil)
        #expect(header.subtitle == nil)
        #expect(header.actionButtons.isEmpty)
        node.cancel()
    }

    @Test
    @available(iOS 26.4, *)
    func `mounted header actions use latest callbacks and ignore stale taps`(
    ) async {

        let completed = AsyncStream<Void>.makeStream()
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let mounted = CarPlayMountedListHeaderButton(
            content: .init("Old") { _ in Issue.record("Old action") },
            context: .init(),
            scope: scope
        )
        let original = mounted.item
        var calls = 0
        let updated = CarPlayListHeaderButton("New") { _ in

            calls += 1
            completed.continuation.yield(())
        }
        mounted.update(updated)
        #expect(mounted.item === original)
        #expect(original.title == "New")
        mounted.activate()
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        mounted.update(updated.disabled())
        mounted.activate()
        mounted.update(updated)
        mounted.cancel()
        mounted.activate()
        #expect(calls == 1)
        scope.cancel()
    }

    @Test
    @available(iOS 26.4, *)
    func `header action failures reach the screen error handler`() async {

        let failed = AsyncStream<Void>.makeStream()
        let scope = CarPlayTaskScope(onError: {

            #expect($0 is HeaderFailure)
            failed.continuation.yield(())
        })
        let mounted = CarPlayMountedListHeaderButton(
            content: .init("Fail") { _ in throw HeaderFailure.expected },
            context: .init(),
            scope: scope
        )
        mounted.activate()
        var iterator = failed.stream.makeAsyncIterator()
        _ = await iterator.next()
        scope.cancel()
    }

    @Test
    @available(iOS 26.4, *)
    func `screen scope cancellation cancels rich header selection work`() async {

        let started = AsyncStream<Void>.makeStream()
        let finished = AsyncStream<Bool>.makeStream()
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let mounted = CarPlayMountedListHeaderButton(
            content: .init("Wait") { _ in

                started.continuation.yield(())

                do {

                    try await Task.sleep(for: .seconds(30))
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

@available(iOS 26.4, *)
private extension CarPlayListHeaderTests {

    func header(_ title: String, _ image: UIImage) -> CarPlayListHeader {

        CarPlayListHeader(title, subtitle: "Artist \(title)", image: image)
    }

    func actions(
        _ ids: [Int],
        image: UIImage,
        disabled: Bool = false
    ) -> CarPlayListHeader {

        CarPlayListHeader("Album", image: image) {

            for id in ids {

                if id == 1 {

                    CarPlayListHeaderButton("Play \(id)") { _ in }
                        .id(id).disabled(disabled)
                } else {

                    CarPlayListHeaderButton(image: image) { _ in }.id(id)
                }
            }
        }
    }

    func list(_ header: CarPlayListHeader) -> CarPlayList {

        CarPlayList("Library") {

            CarPlaySection { CarPlayRow("Track").id(1) }.id("tracks")
        }.listHeader(header)
    }

    func mount(_ template: some CarPlayTemplate) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { Issue.record("Unexpected rich header error: \($0)") }
        )
    }

    enum HeaderFailure: Error {

        case expected
    }
}
