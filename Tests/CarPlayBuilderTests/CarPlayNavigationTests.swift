// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

/// Covers stack navigation, root replacement, tab selection, and disconnects.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayNavigationTests {

    @Test(arguments: [false, true])
    func `pop to root removes destinations and is idempotent`(
        tabbed: Bool
    ) async throws {

        let interface = CarPlayTestInterface()
        let host = tabbed ? self.tabHost(interface) : self.host(interface)
        try await host.connect()
        let root = try #require(interface.templates.first)
        try await host.context.push { CarPlayList("One") {} }
        try await host.context.push { CarPlayList("Two") {} }
        try await host.context.popToRoot()
        try await host.context.popToRoot()
        #expect(interface.templates.count == 1)
        #expect(interface.templates[0] === root)
        #expect(interface.operations.filter { $0 == "popRoot" }.count == 1)
        #expect(!interface.operations.contains("popTo"))
        host.disconnect()
    }

    @Test
    func `tab selection pops destinations and uses a stable ID`() async throws {

        let interface = CarPlayTestInterface()
        let host = self.tabHost(interface)
        try await host.connect()
        let tabs = try #require(interface.templates.first as? CPTabBarTemplate)
        try await host.context.push { CarPlayList("Details") {} }
        try await host.context.selectTab(id: "second")
        #expect(interface.templates.count == 1)
        #expect(interface.selected === tabs.templates[1])
        #expect(interface.operations.contains("popRoot"))
        #expect(!interface.operations.contains("popTo"))
        await #expect(throws: CarPlayError.self) {

            try await host.context.selectTab(id: "missing")
        }
        host.disconnect()
    }

    @Test
    func `replacement commits a new root and survives reconnect`() async throws {

        let interface = CarPlayTestInterface()
        let host = self.host(interface)
        try await host.connect()
        try await host.context.push { CarPlayList("Details") {} }
        try await host.context.replaceRoot { CarPlayList("New root") {} }
        #expect(interface.templates.count == 1)
        #expect((interface.templates[0] as? CPListTemplate)?.title == "New root")
        host.disconnect()
        try await host.connect()
        #expect((interface.templates[0] as? CPListTemplate)?.title == "New root")
        host.disconnect()
    }

    @Test
    func `rejected replacement preserves the old screen and observation`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let model = TitleModel()
        let changed = AsyncStream<Void>.makeStream()
        let host = CarPlayHost(interface: interface, onError: { _ in }) {

            let content = CarPlayList {

                CarPlaySection { CarPlayRow(model.title) }
            }._resolve()
            if model.title == "Updated" {

                changed.continuation.yield(())
            }
            return content
        }
        try await host.connect()
        let old = try #require(interface.templates.first as? CPListTemplate)
        interface.reject = "root"
        await #expect(throws: CarPlayError.self) {

            try await host.context.replaceRoot { CarPlayList("Rejected") {} }
        }
        model.title = "Updated"
        var iterator = changed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(interface.templates[0] === old)
        #expect(old.sections[0].items[0].text == "Updated")
        host.disconnect()
    }

    @Test(arguments: ["root", "popRoot"])
    func `disconnect during navigation cannot restore host state`(
        operation: String
    ) async throws {

        let interface = CarPlayTestInterface()
        let host = self.host(interface)
        try await host.connect()
        try await host.context.push { CarPlayList("Details") {} }
        interface.duringOperation = { name in

            if name == operation {

                host.disconnect()
            }
        }
        await #expect(throws: CarPlayError.self) {

            if operation == "root" {

                try await host.context.replaceRoot { CarPlayList("Stale") {} }
            } else {

                try await host.context.popToRoot()
            }
        }
        #expect(interface.delegate == nil)
        await #expect(throws: CarPlayError.disconnected) {

            try await host.context.dismiss()
        }
    }

    @Test
    func `rejected root pop prevents tab selection and allows retry`() async throws {

        let interface = CarPlayTestInterface()
        let host = self.tabHost(interface)
        try await host.connect()
        try await host.context.push { CarPlayList("Details") {} }
        interface.reject = "popRoot"
        await #expect(throws: CarPlayError.self) {

            try await host.context.selectTab(id: "second")
        }
        #expect(interface.selected == nil)
        try await host.context.selectTab(id: "second")
        #expect(interface.selected != nil)
        host.disconnect()
    }

    @Test
    func `all new context operations reject disconnected access`() async {

        let context = CarPlayContext()
        await #expect(throws: CarPlayError.disconnected) {
            try await context.popToRoot()
        }
        await #expect(throws: CarPlayError.disconnected) {

            try await context.selectTab(id: "none")
        }
        await #expect(throws: CarPlayError.disconnected) {

            try await context.replaceRoot { CarPlayList {} }
        }
        await #expect(throws: CarPlayError.disconnected) {

            try await context
                .present(CarPlayAlert("Alert") { CarPlayAlertAction("OK") })
        }
        await #expect(throws: CarPlayError.disconnected) {
            try await context.dismiss()
        }
    }
}

private extension CarPlayNavigationTests {

    func host(_ interface: CarPlayTestInterface) -> CarPlayHost {

        CarPlayHost(
            interface: interface,
            onError: { Issue.record("Error: \($0)") }
        ) {

            CarPlayList("Root") {}._resolve()
        }
    }

    func tabHost(_ interface: CarPlayTestInterface) -> CarPlayHost {

        CarPlayHost(
            interface: interface,
            onError: { Issue.record("Error: \($0)") }
        ) {

            CarPlayTabs {

                CarPlayTab(id: "first", label: .title("First")) { CarPlayList {} }
                CarPlayTab(id: "second", label: .title("Second")) {
                    CarPlayList {}
                }
            }._resolve()
        }
    }
}

private extension CarPlayNavigationTests {

    @MainActor
    @Observable
    final class TitleModel {

        var title = "Initial"
    }
}
