// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

/// Covers host connection, native visibility, and lifecycle task ownership.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct CarPlayTests {

    @Test
    func `builders flatten loops and omit absent branches`() {

        let rows = CarPlaySection {

            CarPlayRow("First")
            if false {

                CarPlayRow("Absent")
            }
            for index in 0 ..< 3 {

                CarPlayRow("Row \(index)")
                if index == 1 {

                    CarPlayRow("Extra")
                }
            }
            [CarPlayRow("Last")]
        }
        #expect(
            rows.rows.map(\.title) == [
                "First",
                "Row 0",
                "Row 1",
                "Extra",
                "Row 2",
                "Last"
            ]
        )
    }

    @Test
    func `reusable body and conditional composition`() {

        struct Screen: CarPlayTemplate {

            let populated: Bool
            var body: some CarPlayTemplate {

                if self.populated {

                    CarPlayList("Library") {

                        CarPlaySection {

                            CarPlayRow("Track")
                        }
                    }
                } else {

                    CarPlayList("Library") {}
                }
            }
        }

        guard case let .list(_, sections) = Screen(populated: true)._resolve().kind
        else {

            Issue.record("Unexpected template kind")
            return
        }

        #expect(sections.first?.rows.first?.title == "Track")

        guard case let .list(_, empty) = Screen(populated: false)._resolve().kind
        else {

            Issue.record("Unexpected template kind")
            return
        }

        #expect(empty.isEmpty)
    }

    @Test
    func `observation updates existing native template`() async throws {

        let model = Model()
        let changed = TestSignal()
        var renderCount = 0
        let screen = try CarPlayScreen(
            content: {

                renderCount += 1
                let content = CarPlayList("Library") {

                    CarPlaySection {

                        CarPlayRow(model.title)
                    }
                }._resolve()
                if renderCount == 2 {

                    changed.signal()
                }
                return content
            },
            context: .init(),
            onError: { _ in

                Issue.record("Unexpected failure")
            }
        )
        let original = try #require(screen.node.template as? CPListTemplate)
        model.title = "Updated"
        await changed.wait()
        #expect(original === screen.node.template)
        #expect(original.sections.first?.items.first?.text == "Updated")
        screen.cancel()
    }

    @Test
    func `cancelled screen stops observing`() async throws {

        let model = Model()
        var count = 0
        let screen = try CarPlayScreen(
            content: {

                count += 1
                return CarPlayList(model.title) {}._resolve()
            },
            context: .init(),
            onError: { _ in

                Issue.record("Unexpected failure")
            }
        )
        screen.cancel()
        model.title = "Ignored"
        // Drain the queued Observation callback using the main actor, without a
        // timed sleep.
        await Task { @MainActor in }.value
        #expect(count == 1)
    }

    @Test
    func `task identity and visibility cancellation`() async {

        let started = TestSignal()
        let cancelled = TestSignal()
        let scope = CarPlayTaskScope(
            onError: { _ in

                Issue.record("Unexpected failure")
            }
        )
        var count = 0
        let definition = CarPlayTemplateContent.LifecycleTask(
            id: 1,
            priority: .userInitiated
        ) {

            count += 1
            started.signal()

            do {

                try await Task.sleep(for: .seconds(30))
            } catch {

                cancelled.signal()
                throw error
            }
        }
        scope.update([definition], visible: true)
        await started.wait()
        scope.update([definition], visible: true)
        #expect(count == 1)
        scope.update([definition], visible: false)
        await cancelled.wait()
    }

    @Test
    func `task ID change restarts and completed task does not repeat`() async {

        let scope = CarPlayTaskScope(
            onError: { _ in

                Issue.record("Unexpected failure")
            }
        )
        let first = TestSignal()
        let second = TestSignal()
        var count = 0
        let definition = CarPlayTemplateContent.LifecycleTask(
            id: 1,
            priority: .userInitiated
        ) {

            count += 1
            first.signal()
        }
        scope.update([definition], visible: true)
        await first.wait()
        scope.update([definition], visible: true)
        #expect(count == 1)
        scope.update(
            [
                .init(id: 2, priority: .userInitiated, action: {

                    second.signal()
                })
            ],
            visible: true
        )
        await second.wait()
        scope.cancel()
    }

    @Test
    func `row selection completes and reports failure`() async throws {

        let failed = TestSignal()
        let finished = TestSignal()
        let node = try mount(selectionFailureList()) { error in
            #expect(error is SelectionFailure)
            failed.signal()
        }
        let template = try #require(node.template as? CPListTemplate)
        let item = try #require(template.sections[0].items[0] as? CPListItem)
        item.handler?(item) { finished.signal() }
        await failed.wait()
        await finished.wait()
        node.cancel()
    }

    @Test
    func `navigation destination is lazy`() {

        var constructed = false
        _ = CarPlayNavigationLink("Details") {
            constructed = true
            return CarPlayList("Details") {}
        }
        #expect(!constructed)
    }

    @Test
    func `invalid templates are rejected before native construction`() {

        #expect(throws: CarPlayError.self) {

            try self.mount(CarPlayGrid("Empty") {})
        }
        #expect(throws: CarPlayError.self) {

            try self.mount(
                CarPlayList {

                    CarPlaySection {

                        CarPlayRow("One").id(1)
                        CarPlayRow("Duplicate").id(1)
                    }
                }
            )
        }
    }

    @Test
    func `grid and tab limits are validated`() {

        let image = UIImage()
        #expect(throws: CarPlayError.self) {

            try self.mount(
                CarPlayTabs {

                    CarPlayTab(id: 1, label: .title("One")) {

                        CarPlayList {}
                    }
                    CarPlayTab(id: 1, label: .title("Duplicate")) {

                        CarPlayList {}
                    }
                }
            )
        }
        #expect(throws: CarPlayError.self) {

            try self.mount(
                CarPlayGrid {

                    for _ in 0 ..< 9 {

                        CarPlayButton("Too many", image: image) { _ in }
                    }
                }
            )
        }
    }

    @Test
    func `stable tab identity survives content updates`() throws {

        func tabs(_ label: String) -> CarPlayTabs {

            CarPlayTabs {

                CarPlayTab(id: "library", label: .title("Library")) {

                    CarPlayList {

                        CarPlaySection {

                            CarPlayRow(label)
                        }
                    }
                }
            }
        }
        let node = try mount(tabs("Before"))
        let tabBar = try #require(node.template as? CPTabBarTemplate)
        let original = try #require(tabBar.templates[0] as? CPListTemplate)
        try node.update(tabs("After")._resolve())
        #expect(original === tabBar.templates[0])
        #expect(original.sections[0].items[0].text == "After")
    }

    @Test
    func `row identity survives reordering and playback updates`() throws {

        func list(_ reversed: Bool) -> CarPlayList {

            CarPlayList {

                CarPlaySection {

                    for id in reversed ? [2, 1] : [1, 2] {

                        CarPlayRow("Track \(id)").id(id).playback(
                            isPlaying: reversed && id == 1,
                            progress: reversed ? 0.5 : 0
                        )
                    }
                }.id("tracks")
            }
        }
        let node = try mount(list(false))
        let template = try #require(node.template as? CPListTemplate)
        let original = try #require(template.sections[0].items[0] as? CPListItem)
        try node.update(list(true)._resolve())
        #expect(original === template.sections[0].items[1])
        #expect(original.isPlaying)
        #expect(original.playbackProgress == 0.5)
    }

    @Test
    func `popped destination stops observing`() async throws {

        let interface = FakeInterface()
        let host = self.makeHost(interface)
        let model = Model()
        var renders = 0
        try await host.connect()
        try await CarPlayContext(host: host).push {

            renders += 1
            return CarPlayList {

                CarPlaySection {

                    CarPlayRow(model.title)
                }
            }
        }
        try await CarPlayContext(host: host).pop()
        model.title = "Popped"
        await Task { @MainActor in }.value
        #expect(renders == 1)
        host.disconnect()
    }

    @Test
    func `invalid update preserves existing content`() throws {

        let node =
            try mount(CarPlayList("Fixed") {

                CarPlaySection {

                    CarPlayRow("Keep")
                }
            })
        #expect(throws: CarPlayError.self) {

            try node.update(CarPlayGrid {}._resolve())
        }
        #expect(
            (node.template as? CPListTemplate)?.sections[0].items[0]
                .text == "Keep"
        )
    }

    @Test
    func `playback progress is finite and clamped`() {

        #expect(
            CarPlayRow("Track").playback(isPlaying: true, progress: .nan)
                .progress == 0
        )
        #expect(
            CarPlayRow("Track").playback(isPlaying: true, progress: 2)
                .progress == 1
        )
        #expect(
            CarPlayRow("Track").playback(isPlaying: false, progress: -1)
                .progress == 0
        )
    }

    @Test
    func `host connect push pop and disconnect`() async throws {

        let interface = FakeInterface()
        let host = self.makeHost(interface)
        try await host.connect()
        let root = try #require(interface.templates.first)
        let context = host.context
        try await context.push {

            CarPlayList("Details") {}
        }
        #expect(interface.templates.count == 2)
        try await context.pop()
        #expect(interface.templates.count == 1)
        #expect(interface.templates[0] === root)
        host.disconnect()
        #expect(interface.delegate == nil)

        do {

            try await context.push {

                CarPlayList {}
            }
            Issue.record("Must reject disconnected navigation")
        } catch {

            #expect(error is CarPlayError)
        }
    }

    @Test
    func `failed push does not break subsequent navigation`() async throws {

        let interface = FakeInterface()
        let host = self.makeHost(interface)
        try await host.connect()
        interface.rejectNext = true

        do {

            try await CarPlayContext(host: host).push {

                CarPlayList {}
            }
            Issue.record("Unexpected failure")
        } catch {

            #expect(error is CarPlayError)
        }
        #expect(interface.templates.count == 1)
        try await CarPlayContext(host: host).push {

            CarPlayList {}
        }
        #expect(interface.templates.count == 2)
        host.disconnect()
    }

    @Test
    func `disconnect while connecting cannot restore session`() async throws {

        let interface = FakeInterface()
        let host = self.makeHost(interface)
        interface.duringRoot = {

            host.disconnect()
        }

        do {

            try await host.connect()
            Issue.record("Disconnected connect must fail")
        } catch {

            #expect(error is CarPlayError)
        }
        #expect(interface.delegate == nil)

        do {

            try await CarPlayContext(host: host).pop()
            Issue.record("Unexpected failure")
        } catch {

            #expect(error is CarPlayError)
        }
    }

    @Test
    func `trailing artwork takes precedence over the disclosure indicator`() throws {

        let image = UIImage()
        let row = CarPlayRow("Track")
            .trailingImage(image)
            .accessory(.disclosureIndicator)
        let node = try self.mount(self.imageList(row))
        let template = try #require(node.template as? CPListTemplate)
        let item = try #require(template.sections[0].items[0] as? CPListItem)
        #expect(item.image == nil)
        #expect(item.accessoryImage === image)
        #expect(item.accessoryType == .none)
    }

    @Test
    func `artwork can move to the trailing side and restore the accessory`() throws {

        let leading = UIImage()
        let trailing = UIImage()
        let initial = CarPlayRow("Track", image: leading)
        let node = try self.mount(self.imageList(initial))
        let template = try #require(node.template as? CPListTemplate)
        let item = try #require(template.sections[0].items[0] as? CPListItem)
        #expect(item.image === leading)
        let updated = CarPlayRow("Track").trailingImage(trailing)
        try node.update(self.imageList(updated)._resolve())
        #expect(template.sections[0].items[0] === item)
        #expect(item.image == nil)
        #expect(item.accessoryImage === trailing)
        let restored = updated.trailingImage(nil).accessory(.disclosureIndicator)
        try node.update(self.imageList(restored)._resolve())
        #expect(item.accessoryImage == nil)
        #expect(item.accessoryType == .disclosureIndicator)
    }

    @Test
    func `leading and trailing images can be displayed together`() throws {

        let leading = UIImage()
        let trailing = UIImage()
        let row = CarPlayRow("Track", image: leading).trailingImage(trailing)
        let node = try self.mount(self.imageList(row))
        let template = try #require(node.template as? CPListTemplate)
        let item = try #require(template.sections[0].items[0] as? CPListItem)
        #expect(item.image === leading)
        #expect(item.accessoryImage === trailing)
    }
}

private extension CarPlayTests {

    func selectionFailureList() -> CarPlayList {

        CarPlayList {
            CarPlaySection {
                CarPlayRow("Fail") { _ in
                    throw SelectionFailure.expected
                }
            }
        }
    }

    func imageList(_ row: CarPlayRow) -> CarPlayList {

        CarPlayList {

            CarPlaySection {

                row
            }
        }
    }

    func mount(
        _ template: some CarPlayTemplate,
        onError: @escaping @MainActor (Error) -> Void = { _ in

            Issue.record("Unexpected failure")
        }
    ) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: onError
        )
    }

    func makeHost(_ interface: FakeInterface) -> CarPlayHost {

        CarPlayHost(
            interface: interface,
            onError: { _ in

                Issue.record("Unexpected failure")
            },
            content: {

                CarPlayList("Root") {}._resolve()
            }
        )
    }
}

private extension CarPlayTests {

    @MainActor
    @Observable
    final class Model {

        var title = "Initial"
    }

    @MainActor
    final class FakeInterface: CarPlayInterface {

        weak var delegate: (any CPInterfaceControllerDelegate)?
        var templates: [CPTemplate] = []
        var presentedTemplate: CPTemplate?

        func presentTemplate(
            _ template: CPTemplate,
            animated: Bool
        ) async throws -> Bool {

            self.presentedTemplate = template
            return true
        }

        func dismissTemplate(animated: Bool) async throws -> Bool {

            self.presentedTemplate = nil
            return true
        }

        func selectTemplate(_ template: CPTemplate, in tabs: CPTabBarTemplate) {

            tabs.select(template)
        }

        var rejectNext = false
        var duringRoot: (() -> Void)?

        func setRootTemplate(
            _ template: CPTemplate,
            animated: Bool
        ) async throws -> Bool {

            self.duringRoot?()

            guard !self.rejectNext else {

                self.rejectNext = false
                return false
            }

            self.templates = [template]
            self.delegate?.templateWillAppear?(template, animated: animated)
            self.delegate?.templateDidAppear?(template, animated: animated)
            return true
        }

        func pushTemplate(
            _ template: CPTemplate,
            animated: Bool
        ) async throws -> Bool {

            guard !self.rejectNext else {

                self.rejectNext = false
                return false
            }

            if let old = templates.last {

                self.delegate?.templateWillDisappear?(old, animated: animated)
            }
            self.templates.append(template)
            self.delegate?.templateWillAppear?(template, animated: animated)
            self.delegate?.templateDidAppear?(template, animated: animated)
            return true
        }

        func popTemplate(animated: Bool) async throws -> Bool {

            guard self.templates.count > 1 else {

                return false
            }

            let removed = self.templates.removeLast()
            self.delegate?.templateWillDisappear?(removed, animated: animated)
            if let top = templates.last {

                self.delegate?.templateWillAppear?(top, animated: animated)
                self.delegate?.templateDidAppear?(top, animated: animated)
            }
            return true
        }

        func popToRootTemplate(animated: Bool) async throws -> Bool {

            self.templates = Array(self.templates.prefix(1))
            return true
        }

        func popToTemplate(
            _ template: CPTemplate,
            animated: Bool
        ) async throws -> Bool {

            guard let index = templates.firstIndex(where: {

                $0 === template
            })
            else {

                return false
            }

            self.templates = Array(self.templates.prefix(through: index))
            return true
        }
    }

    /// Buffered events let callback-driven tests await completion without sleeps or
    /// polling.
    struct TestSignal: Sendable {

        private let stream: AsyncStream<Void>
        private let continuation: AsyncStream<Void>.Continuation

        init() {

            let pair = AsyncStream<
                Void
            >.makeStream()
            self.stream = pair.stream
            self.continuation = pair.continuation
        }

        func signal() {

            self.continuation.yield(())
        }

        func wait() async {

            var iterator = self.stream.makeAsyncIterator()
            _ = await iterator.next()
        }
    }

    enum SelectionFailure: Error {

        case expected
    }
}
