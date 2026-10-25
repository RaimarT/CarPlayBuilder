// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers tab badges, stable selection IDs, and native/programmatic callbacks.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayTabInteractionTests {

    @Test
    func `badges update and reset while preserving tab identity`() throws {

        let node = try self.mount(self.tabs())
        let native = try #require(node.template as? CPTabBarTemplate)
        let tab = native.templates[0]
        #expect(!tab.showsTabBadge)
        try node.update(self.tabs([2, 1], badge: true)._resolve())
        #expect(native.templates[1] === tab)
        #expect(tab.showsTabBadge)
        #expect(!native.templates[0].showsTabBadge)
        try node.update(self.tabs()._resolve())
        #expect(native.templates[0] === tab)
        #expect(!tab.showsTabBadge)
        node.cancel()
    }

    @Test
    func `native selections report changes using the latest callback`() throws {

        var selected: [AnyHashable] = []
        let node = try self.mount(self.tabs().onSelectionChange {

            selected.append($0)
        })
        let native = try #require(node.template as? CPTabBarTemplate)
        #expect(selected.isEmpty)
        self.select(native.templates[0], in: native)
        self.select(native.templates[1], in: native)
        self.select(native.templates[1], in: native)
        #expect(selected == [AnyHashable(2)])
        try node.update(self.tabs([2, 1]).onSelectionChange {

            selected.append($0)
            selected.append("updated")
        }._resolve())
        #expect(selected == [AnyHashable(2)])
        self.select(native.templates[0], in: native)
        #expect(selected == [AnyHashable(2)])
        self.select(native.templates[1], in: native)
        #expect(selected == [AnyHashable(2), AnyHashable(1), "updated"])
        node.cancel()
    }

    @Test
    func `removed tabs and cancelled delegates ignore stale events`() throws {

        var selected: [AnyHashable] = []
        let node = try self.mount(self.tabs().onSelectionChange {

            selected.append($0)
        })
        let native = try #require(node.template as? CPTabBarTemplate)
        let delegate = try #require(native.delegate)
        let removed = native.templates[1]
        self.select(removed, in: native)
        try node.update(self.tabs([1]).onSelectionChange {

            selected.append($0)
        }._resolve())
        delegate.tabBarTemplate(native, didSelect: removed)
        self.select(native.templates[0], in: native)
        #expect(selected == [AnyHashable(2)])
        node.cancel()
        #expect(native.delegate == nil)
        delegate.tabBarTemplate(native, didSelect: native.templates[0])
        #expect(selected == [AnyHashable(2)])
    }

    @Test
    func `removing the callback stops notifications but keeps selection tracking`(
    ) throws {

        var selected: [AnyHashable] = []
        let node = try self.mount(self.tabs().onSelectionChange {

            selected.append($0)
        })
        let native = try #require(node.template as? CPTabBarTemplate)
        try node.update(self.tabs()._resolve())
        self.select(native.templates[1], in: native)
        try node.update(self.tabs().onSelectionChange {

            selected.append($0)
        }._resolve())
        self.select(native.templates[1], in: native)
        #expect(selected.isEmpty)
        self.select(native.templates[0], in: native)
        #expect(selected == [AnyHashable(1)])
        node.cancel()
    }

    @Test(arguments: [false, true])
    func `programmatic selections notify once with or without native callbacks`(
        nativeCallback: Bool
    ) async throws {

        let interface = CarPlayTestInterface()
        interface.notifiesTabSelection = nativeCallback
        var selected: [AnyHashable] = []
        let host = self.host(interface) { selected.append($0) }
        try await host.connect()
        #expect(selected.isEmpty)
        try await host.context.push { CarPlayList("Details") {} }
        try await host.context.selectTab(id: 2)
        #expect(interface.templates.count == 1)
        #expect(selected == [AnyHashable(2)])
        try await host.context.selectTab(id: 2)
        #expect(selected == [AnyHashable(2)])
        try await host.context.selectTab(id: 1)
        #expect(selected == [AnyHashable(2), AnyHashable(1)])
        host.disconnect()
    }

    @Test
    func `failed navigation does not report a tab selection`() async throws {

        let interface = CarPlayTestInterface()
        var selected: [AnyHashable] = []
        let host = self.host(interface) { selected.append($0) }
        try await host.connect()
        try await host.context.push { CarPlayList("Details") {} }
        interface.reject = "popRoot"
        await #expect(throws: CarPlayError.self) {

            try await host.context.selectTab(id: 2)
        }
        await #expect(throws: CarPlayError.self) {

            try await host.context.selectTab(id: "missing")
        }
        #expect(selected.isEmpty)
        try await host.context.selectTab(id: 2)
        #expect(selected == [AnyHashable(2)])
        host.disconnect()
    }

    @Test(arguments: [false, true])
    func `root replacement and disconnect invalidate old selection delegates`(
        replace: Bool
    ) async throws {

        let interface = CarPlayTestInterface()
        var selected: [AnyHashable] = []
        let host = self.host(interface) { selected.append($0) }
        try await host.connect()
        let native = try #require(interface.templates.first as? CPTabBarTemplate)
        let delegate = try #require(native.delegate)
        if replace {

            try await host.context.replaceRoot { CarPlayList("Replacement") {} }
        } else {

            host.disconnect()
        }
        #expect(native.delegate == nil)
        delegate.tabBarTemplate(native, didSelect: native.templates[1])
        #expect(selected.isEmpty)
        host.disconnect()
    }
}

private extension CarPlayTabInteractionTests {

    func tabs(_ ids: [Int] = [1, 2], badge: Bool = false) -> CarPlayTabs {

        CarPlayTabs {

            for id in ids {

                CarPlayTab(id: id, label: .title("Tab \(id)")) {

                    CarPlayList {}
                }.badge(badge && id == 1)
            }
        }
    }

    func select(_ template: CPTemplate, in tabs: CPTabBarTemplate) {

        tabs.delegate?.tabBarTemplate(tabs, didSelect: template)
    }

    func mount(_ tabs: CarPlayTabs) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: tabs._resolve(),
            context: .init(),
            onError: { Issue.record("Unexpected tab error: \($0)") }
        )
    }

    func host(
        _ interface: CarPlayTestInterface,
        onSelection: @escaping CarPlayTabSelectionHandler
    ) -> CarPlayHost {

        CarPlayHost(
            interface: interface,
            onError: { Issue.record("Unexpected navigation error: \($0)") }
        ) {

            self.tabs().onSelectionChange(onSelection)._resolve()
        }
    }
}
