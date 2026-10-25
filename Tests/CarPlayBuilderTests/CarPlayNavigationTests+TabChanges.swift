// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

extension CarPlayNavigationTests {

    @Test(arguments: [false, true])
    func `tab selection resolves current identity after awaiting root navigation`(
        remove: Bool
    ) async throws {

        let interface = CarPlayTestInterface()
        let model = ChangingTabs()
        let rendered = AsyncStream<Void>.makeStream()
        var selectedIDs: [AnyHashable] = []
        let host = self.changingTabsHost(interface, model, rendered: {

            rendered.continuation.yield(())
        }) {

            selectedIDs.append($0)
        }
        try await host.connect()
        let tabs = try #require(interface.templates.first as? CPTabBarTemplate)
        try await host.context.push { CarPlayList("Details") {} }
        interface.beforePopRoot = {

            model.ids = remove ? [1] : [2, 1]
            var iterator = rendered.stream.makeAsyncIterator()
            _ = await iterator.next()
        }
        if remove {

            await #expect(throws: CarPlayError.self) {

                try await host.context.selectTab(id: 2)
            }
            #expect(interface.selected == nil)
            #expect(selectedIDs.isEmpty)
        } else {

            try await host.context.selectTab(id: 2)
            #expect(interface.selected === tabs.templates[0])
            #expect(selectedIDs == [AnyHashable(2)])
        }
        host.disconnect()
    }
}

private extension CarPlayNavigationTests {

    func changingTabsHost(
        _ interface: CarPlayTestInterface,
        _ model: ChangingTabs,
        rendered: @escaping CarPlayCallback,
        onSelection: @escaping CarPlayTabSelectionHandler
    ) -> CarPlayHost {

        CarPlayHost(
            interface: interface,
            onError: { Issue.record("Error: \($0)") }
        ) {

            let content = CarPlayTabs {

                for id in model.ids {

                    CarPlayTab(id: id, label: .title("Tab \(id)")) {

                        CarPlayList {}
                    }
                }
            }.onSelectionChange(onSelection)._resolve()
            if model.ids != [1, 2] {

                rendered()
            }
            return content
        }
    }

    @MainActor
    @Observable
    final class ChangingTabs {

        var ids = [1, 2]
    }
}
