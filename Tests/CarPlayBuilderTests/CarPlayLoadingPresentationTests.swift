// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import os
import Testing
@testable import CarPlayBuilder

/// Covers typed status builders, retention, fallback, and recovery actions.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayLoadingPresentationTests {

    @Test(arguments: 0 ..< 5)
    func `lists evaluate only the selected status builder`(index: Int) {

        let probe = BuilderProbe()
        let scenario = self.scenario(index)
        let content = self.list.loadingState(
            scenario.state,
            isEmpty: scenario.empty,
            loading: { probe.rows("Loading") },
            empty: { probe.rows("Empty") },
            failure: { probe.failureRows($0) }
        )._resolve()
        #expect(self.sections(content).first?.rows.first?.title == scenario.title)
        #expect(probe.calls == (index == 4 ? [] : [scenario.title]))
    }

    @Test(arguments: 0 ..< 5)
    func `grids evaluate only the selected status builder`(index: Int) {

        let probe = BuilderProbe()
        let scenario = self.scenario(index)
        let content = self.grid.loadingState(
            scenario.state,
            isEmpty: scenario.empty,
            loading: { probe.buttons("Loading") },
            empty: { probe.buttons("Empty") },
            failure: { probe.failureButtons($0) }
        )._resolve()
        #expect(self.buttons(content).first?.titles == [scenario.title])
        #expect(probe.calls == (index == 4 ? [] : [scenario.title]))
    }

    @Test
    func `custom empty rows own their recovery actions`() async throws {

        var browsed = false
        var retried = false
        let content = self.list.loadingState(
            .loaded,
            isEmpty: true,
            empty: { CarPlayRow("Browse") { _ in browsed = true } },
            retry: { retried = true }
        )._resolve()
        let rows = self.sections(content).flatMap(\.rows)
        #expect(rows.count == 1)
        let action = try #require(rows.first?.action)
        try await action(.init())
        #expect(browsed)
        #expect(retried == false)
    }

    @Test
    func `custom failure buttons own their recovery actions`() async throws {

        var recovered = false
        let image = UIImage()
        let content = self.grid.loadingState(
            .failed(LoadingFailure.offline),
            failure: { _ in

                CarPlayButton("Downloads", image: image) { _ in recovered = true }
            },
            retry: { Issue.record("Default retry must not replace custom actions") }
        )._resolve()
        let buttons = self.buttons(content)
        #expect(buttons.count == 1)
        try await buttons.first?.action(.init())
        #expect(recovered)
    }

    @Test
    func `list refresh preserves items and surrounding modifiers`() {

        let probe = BuilderProbe()
        let content = self.list.task {}.onAppear {}.trailingBarButtons {

            CarPlayBarButton("Help") { _ in }
        }.loadingState(
            .loading,
            retainsContentDuringRefresh: true,
            loading: { probe.rows("Loading") }
        )._resolve()
        #expect(self.sections(content).first?.rows.first?.title == "Content")
        #expect(content.tasks.count == 1)
        #expect(content.appear.count == 1)
        #expect(content.trailingButtons.count == 1)
        #expect(probe.calls.isEmpty)
    }

    @Test
    func `grid refresh preserves buttons and skips loading builder`() {

        let probe = BuilderProbe()
        let content = self.grid.loadingState(
            .loading,
            retainsContentDuringRefresh: true,
            loading: { probe.buttons("Loading") }
        )._resolve()
        #expect(self.buttons(content).count == 1)
        #expect(self.buttons(content).first?.titles == ["Content"])
        #expect(probe.calls.isEmpty)
    }

    @Test
    func `failed list refresh appends a distinct recovery section`() throws {

        let content = self.list.loadingState(
            .failed(LoadingFailure.offline),
            retainsContentDuringRefresh: true,
            failure: { _ in CarPlayRow("Open downloads") }
        )._resolve()
        let sections = self.sections(content)
        #expect(sections.count == 2)
        #expect(sections.first?.rows.first?.title == "Content")
        #expect(sections.last?.rows.first?.title == "Open downloads")
        #expect(sections.first?.identity != sections.last?.identity)
        try CarPlayTemplateValidation.validate(content)
    }

    @Test
    func `failed grid refresh appends default status and retry`() throws {

        let content = self.grid.loadingState(
            .failed(LoadingFailure.offline),
            retainsContentDuringRefresh: true,
            retry: {}
        )._resolve()
        #expect(self.buttons(content).map(\.titles) == [
            ["Content"],
            ["Unable to load"],
            ["Try again"]
        ])
        try CarPlayTemplateValidation.validate(content)
    }

    @Test(arguments: [CarPlayLoadState.idle, .loading, .loaded])
    func `empty resources never retain placeholders`(state: CarPlayLoadState) {

        let content = self.list.loadingState(
            state,
            isEmpty: true,
            retainsContentDuringRefresh: true
        )._resolve()
        let title = self.sections(content).first?.rows.first?.title
        #expect(title != "Content")
    }

    @Test
    func `initial loading replaces existing content even with retention`() {

        let content = self.grid.loadingState(
            .idle,
            retainsContentDuringRefresh: true
        )._resolve()
        #expect(self.buttons(content).first?.titles == ["Loading…"])
    }

    @Test
    func `retention also requires actual rows or buttons`() {

        let list = CarPlayList {}.loadingState(
            .loading,
            retainsContentDuringRefresh: true
        )._resolve()
        let grid = CarPlayGrid {}.loadingState(
            .loading,
            retainsContentDuringRefresh: true
        )._resolve()
        #expect(self.sections(list).first?.rows.first?.title == "Loading…")
        #expect(self.buttons(grid).first?.titles == ["Loading…"])
    }

    @Test
    func `nil builders use defaults but empty custom rows stay empty`() {

        let fallback = self.list.loadingState(
            .failed(LoadingFailure.offline),
            failure: { _ in return nil }
        )._resolve()
        let empty = self.list.loadingState(
            .loaded,
            isEmpty: true,
            empty: { [] }
        )._resolve()
        #expect(self.sections(fallback).first?.rows.first?.title == "Unable to load")
        #expect(self.sections(empty).flatMap(\.rows).isEmpty)
    }

    @Test
    func `default list failure maps the original error to title and message`() {

        let configuration = CarPlayLoadingConfiguration(failure: { error in

            #expect(error as? LoadingFailure == .offline)

            return .init(
                label: .init(title: "Offline", systemImage: "wifi.slash"),
                message: "Check your connection"
            )
        })
        let content = self.list.loadingState(
            .failed(LoadingFailure.offline),
            configuration: configuration
        )._resolve()
        #expect(self.sections(content).first?.rows.first?.title == "Offline")
        #expect(self.sections(content).first?.rows.first?.detail
            == "Check your connection")
    }

    @Test
    func `custom failure rows bypass the default error presentation provider`() {

        let probe = BuilderProbe()
        let configuration = CarPlayLoadingConfiguration(failure: { _ in

            Issue.record("Custom content must bypass the default error mapper")

            return .init(message: "Unexpected")
        })
        _ = self.list.loadingState(
            .failed(LoadingFailure.offline),
            configuration: configuration,
            failure: { probe.failureRows($0) }
        )._resolve()
        #expect(probe.calls == ["Failure"])
    }

    @Test
    func `default grid status symbols are configurable`() {

        let configuration = CarPlayLoadingConfiguration(
            failure: { _ in

                .init(label: .init(title: "Offline", systemImage: "wifi.slash"))
            },
            retry: .init(title: "Reconnect", systemImage: "arrow.left")
        )
        let content = self.grid.loadingState(
            .failed(LoadingFailure.offline),
            configuration: configuration,
            retry: {}
        )._resolve()
        let buttons = self.buttons(content)
        #expect(buttons.first?.titles == ["Offline"])
        #expect(buttons.last?.titles == ["Reconnect"])
        #expect(buttons.first?.image == UIImage(systemName: "wifi.slash"))
        #expect(buttons.last?.image == UIImage(systemName: "arrow.left"))
    }

    @Test
    func `each state renders its configured title and symbol together`() {

        let configuration = CarPlayLoadingConfiguration(
            loading: .init(title: "Wait", systemImage: "clock"),
            failure: { _ in

                .init(label: .init(title: "Offline", systemImage: "wifi.slash"))
            },
            empty: .init(title: "Nothing saved", systemImage: "star"),
            retry: .init(title: "Reconnect", systemImage: "arrow.left")
        )
        let cases: [(CarPlayLoadState, String, String)] = [
            (.idle, "Wait", "clock"),
            (.loading, "Wait", "clock"),
            (.loaded, "Nothing saved", "star"),
            (.failed(LoadingFailure.offline), "Offline", "wifi.slash")
        ]
        for (state, title, symbol) in cases {

            let content = self.grid.loadingState(
                state,
                isEmpty: true,
                configuration: configuration,
                retry: {}
            )._resolve()
            let buttons = self.buttons(content)
            #expect(buttons.first?.titles == [title])
            #expect(buttons.first?.image == UIImage(systemName: symbol))
        }
    }

    @Test(arguments: [false, true])
    func `failure presentation resolves once for each default render`(grid: Bool) {

        let calls = OSAllocatedUnfairLock(initialState: 0)
        let configuration = CarPlayLoadingConfiguration(failure: { _ in

            calls.withLock { $0 += 1 }

            return .init(message: nil)
        })
        let state = CarPlayLoadState.failed(LoadingFailure.offline)
        if grid {

            _ = self.grid.loadingState(
                state,
                configuration: configuration
            )._resolve()
        } else {

            let content = self.list.loadingState(
                state,
                configuration: configuration
            )._resolve()
            #expect(self.sections(content).first?.rows.first?.detail == nil)
        }
        #expect(calls.withLock { $0 } == 1)
    }

    @Test(arguments: [CarPlayLoadState.idle, .loading, .loaded])
    func `nonfailure states bypass the error presentation provider`(
        state: CarPlayLoadState
    ) {

        let configuration = CarPlayLoadingConfiguration(failure: { _ in

            Issue.record("Nonfailure states must not map errors")

            return .init()
        })
        _ = self.list.loadingState(
            state,
            isEmpty: true,
            configuration: configuration
        )._resolve()
        _ = self.grid.loadingState(
            state,
            isEmpty: true,
            configuration: configuration
        )._resolve()
    }

    @Test
    func `custom failure grids bypass the error presentation provider`() {

        let configuration = CarPlayLoadingConfiguration(failure: { _ in

            Issue.record("Custom content must bypass the default error mapper")

            return .init()
        })
        let content = self.grid.loadingState(
            .failed(LoadingFailure.offline),
            configuration: configuration,
            failure: { _ in CarPlayButton("Help", image: UIImage()) { _ in } }
        )._resolve()
        #expect(self.buttons(content).first?.titles == ["Help"])
    }

    @Test(arguments: [URLError.notConnectedToInternet, .userAuthenticationRequired])
    func `one provider selects error specific labels for lists and grids`(
        code: URLError.Code
    ) {

        let configuration = CarPlayLoadingConfiguration(failure: { error in

            let offline = (error as? URLError)?.code == .notConnectedToInternet

            return .init(
                label: .init(
                    title: offline ? "Offline" : "Sign in",
                    systemImage: offline ? "wifi.slash" : "person"
                )
            )
        })
        let state = CarPlayLoadState.failed(URLError(code))
        let title = code == .notConnectedToInternet ? "Offline" : "Sign in"
        let symbol = code == .notConnectedToInternet ? "wifi.slash" : "person"
        let list = self.list.loadingState(state, configuration: configuration)
        let grid = self.grid.loadingState(state, configuration: configuration)
        #expect(self.sections(list._resolve()).first?.rows.first?.title == title)
        #expect(self.buttons(grid._resolve()).first?.titles == [title])
        #expect(self.buttons(grid._resolve()).first?.image
            == UIImage(systemName: symbol))
    }

    @Test
    func `native list identity survives refresh failure and recovery`() throws {

        let template = self.list
        let node = try self.mount(template)
        let list = try #require(node.template as? CPListTemplate)
        let original = list.sections[0].items[0]
        for state in [
            CarPlayLoadState.loading,
            .failed(LoadingFailure.offline),
            .loaded
        ] {

            try node.update(template.loadingState(
                state,
                retainsContentDuringRefresh: true
            )._resolve())
            #expect(list.sections[0].items[0] === original)
            #expect(list.title == "Library")
        }
        #expect(list.sections.count == 1)
        node.cancel()
    }

    @Test
    func `native grid buttons survive refresh failure and recovery`() throws {

        let button = CarPlayButton("Content", image: UIImage()) { _ in }.id(1)
        let template = CarPlayGrid("Browse") { button }
        let node = try self.mount(template)
        let grid = try #require(node.template as? CPGridTemplate)
        let original = grid.gridButtons[0]
        for state in [
            CarPlayLoadState.loading,
            .failed(LoadingFailure.offline),
            .loaded
        ] {

            try node.update(template.loadingState(
                state,
                retainsContentDuringRefresh: true
            )._resolve())
            #expect(grid.gridButtons[0] === original)
            #expect(grid.title == "Browse")
        }
        #expect(grid.gridButtons.count == 1)
        node.cancel()
    }

    @Test
    func `custom recovery errors report and finish selection`() async throws {

        let finished = AsyncStream<Void>.makeStream()
        var reported: (any Error)?
        let template = self.list.loadingState(
            .loaded,
            isEmpty: true,
            empty: {

                CarPlayRow("Recover") { _ in throw LoadingFailure.offline }
            }
        )
        let node = try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { reported = $0 }
        )
        let list = try #require(node.template as? CPListTemplate)
        let row = try #require(list.sections[0].items[0] as? CPListItem)
        let handler = try #require(row.handler)
        handler(row) { finished.continuation.yield(()) }
        var iterator = finished.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(reported as? LoadingFailure == .offline)
        node.cancel()
    }

    @Test
    func `custom status content still respects native grid limits`() {

        let content = self.grid.loadingState(.loading, loading: {

            for index in 0 ..< 9 {

                CarPlayButton("\(index)", image: UIImage()) { _ in }
            }
        })._resolve()
        #expect(throws: CarPlayError.self) {

            try CarPlayTemplateValidation.validate(content)
        }
    }

    @Test
    func `retained failure content also counts against grid limits`() {

        let content = CarPlayGrid {

            for index in 0 ..< 8 {

                CarPlayButton("\(index)", image: UIImage()) { _ in }
            }
        }.loadingState(
            .failed(LoadingFailure.offline),
            retainsContentDuringRefresh: true
        )._resolve()
        #expect(throws: CarPlayError.self) {

            try CarPlayTemplateValidation.validate(content)
        }
    }
}

private extension CarPlayLoadingPresentationTests {

    func mount(_ template: some CarPlayTemplate) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { Issue.record("Unexpected rendering error: \($0)") }
        )
    }

    var list: CarPlayList {

        CarPlayList("Library") {

            CarPlaySection { CarPlayRow("Content").id("content") }.id("library")
        }
    }

    var grid: CarPlayGrid {

        CarPlayGrid("Browse") {

            CarPlayButton("Content", image: UIImage()) { _ in }.id("content")
        }
    }

    func sections(_ content: CarPlayTemplateContent) -> [CarPlaySection] {

        guard case let .list(_, sections) = content.kind else {

            Issue.record("Status presentation changed the template kind")
            return []
        }

        return sections
    }

    func buttons(_ content: CarPlayTemplateContent) -> [CarPlayButton] {

        guard case let .grid(_, buttons) = content.kind else {

            Issue.record("Status presentation changed the template kind")
            return []
        }

        return buttons
    }

    func scenario(_ index: Int)
        -> (state: CarPlayLoadState, empty: Bool, title: String) {

        let states: [CarPlayLoadState] = [
            .idle,
            .loading,
            .loaded,
            .failed(LoadingFailure.offline),
            .loaded
        ]
        let titles = ["Loading", "Loading", "Empty", "Failure", "Content"]

        return (states[index], index == 2, titles[index])
    }

    enum LoadingFailure: Error {

        case offline
    }

    @MainActor
    final class BuilderProbe {

        var calls: [String] = []

        func rows(_ title: String) -> [CarPlayRow] {

            self.calls.append(title)

            return [CarPlayRow(title)]
        }

        func buttons(_ title: String) -> [CarPlayButton] {

            self.calls.append(title)

            return [CarPlayButton(title, image: UIImage()) { _ in }]
        }

        func failureRows(_ error: any Error) -> [CarPlayRow] {

            #expect(error as? LoadingFailure == .offline)

            return self.rows("Failure")
        }

        func failureButtons(_ error: any Error) -> [CarPlayButton] {

            #expect(error as? LoadingFailure == .offline)

            return self.buttons("Failure")
        }
    }
}
