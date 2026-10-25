// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

/// Covers result builders, reusable bodies, and stable content identities.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayCompositionTests {

    @Test
    func `collection builders cover both branches optional values and arrays`() {

        #expect(CarPlayArrayBuilder<Int>.buildOptional(nil).isEmpty)
        #expect(CarPlayArrayBuilder<Int>.buildEither(first: [1]) == [1])
        #expect(CarPlayArrayBuilder<Int>.buildEither(second: [2]) == [2])
        #expect(CarPlayArrayBuilder<Int>.buildLimitedAvailability([3]) == [3])
        #expect(CarPlayArrayBuilder<Int>.buildExpression([1, 2]) == [1, 2])
        #expect(CarPlayArrayBuilder<Int>.buildBlock([1], [2]) == [1, 2])
        #expect(CarPlayArrayBuilder<Int>.buildArray([[1], [], [2]]) == [1, 2])
    }

    @Test
    func `availability erasure preserves the selected template`() {

        let wrapped = CarPlayTemplateBuilder.buildLimitedAvailability(
            AnyCarPlayTemplate(CarPlayList("Available") {})
        )

        guard case let .list(title, _) = wrapped._resolve().kind else {

            Issue.record("Unexpected template kind")
            return
        }

        #expect(title == "Available")
    }

    @Test
    func `appearance disappearance and completed tasks follow visibility`(
    ) async throws {

        let completed = AsyncStream<Void>.makeStream()
        var appearances = 0
        var disappearances = 0
        var tasks = 0
        let node = try self.mount(CarPlayList {}.onAppear { appearances += 1 }
            .onDisappear { disappearances += 1 }.task {

                tasks += 1
                completed.continuation.yield(())
            })
        node.setVisible(true, for: node.template)
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        node.setVisible(true, for: node.template)
        #expect(appearances == 1)
        #expect(tasks == 1)
        node.setVisible(false, for: node.template)
        #expect(disappearances == 1)
        node.setVisible(true, for: node.template)
        _ = await iterator.next()
        #expect(appearances == 2)
        #expect(tasks == 2)
        node.cancel()
        #expect(disappearances == 2)
    }

    @Test
    func `navigation link action pushes its lazy destination`() async throws {

        let interface = CarPlayTestInterface()
        let host = CarPlayHost(interface: interface, onError: { _ in }) {

            CarPlayList {}._resolve()
        }
        try await host.connect()
        let link = CarPlayNavigationLink("Open") { CarPlayList("Destination") {} }
        try await link.action?(host.context)
        #expect(link.accessory == .disclosureIndicator)
        #expect((interface.templates.last as? CPListTemplate)?
            .title == "Destination")
        try await host.context.showNowPlaying()
        #expect(interface.templates.last === CPNowPlayingTemplate.shared)
        try await host.context.showNowPlaying()
        #expect(interface.templates.count == 3)
        host.disconnect()
    }

    @Test
    func `invalid observed updates report errors and keep the last valid screen`(
    ) async
        throws {

        let model = TitleState()
        let failed = AsyncStream<Void>.makeStream()
        let screen = try CarPlayScreen(content: {

            CarPlayList(model.title) {}._resolve()
        }, context: .init(), onError: { _ in failed.continuation.yield(()) })
        model.title = "Different title"
        var iterator = failed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect((screen.node.template as? CPListTemplate)?.title == "Fixed")
        screen.cancel()
    }

    @Test
    func `duplicate sections and nested tabs are rejected`() {

        #expect(throws: CarPlayError.self) {

            try self.mount(CarPlayList {

                CarPlaySection {}.id(1)
                CarPlaySection {}.id(1)
            })
        }
        #expect(throws: CarPlayError.self) {

            try self.mount(CarPlayTabs {

                CarPlayTab(id: 1, label: .title("Invalid")) { CarPlayTabs {} }
            })
        }
    }

    @Test
    func `grid button modifiers and title variants survive resolution`() throws {

        let image = UIImage()
        let node = try self.mount(CarPlayGrid("Grid") {

            CarPlayButton(titleVariants: ["Long", "Short"], image: image) { _ in }
                .id("button").disabled()
        })
        let grid = try #require(node.template as? CPGridTemplate)
        #expect(grid.gridButtons[0].titleVariants == ["Long", "Short"])
        #expect(!grid.gridButtons[0].isEnabled)
    }

    @Test(arguments: [
        CarPlayError.disconnected,
        .operationInProgress,
        .presentationRejected,
        .invalidContent("Detailed failure")
    ])
    func `package errors provide localized descriptions`(error: CarPlayError) {

        #expect(error.errorDescription?.isEmpty == false)
        if case .invalidContent = error {

            #expect(error.errorDescription == "Detailed failure")
        }
    }
}

private extension CarPlayCompositionTests {

    func mount(_ template: some CarPlayTemplate) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { Issue.record("Error: \($0)") }
        )
    }
}

private extension CarPlayCompositionTests {

    @MainActor
    @Observable
    final class TitleState {

        var title = "Fixed"
    }
}
