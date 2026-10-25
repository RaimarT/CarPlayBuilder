// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers label rendering and clearing stale values on reused native tabs.
@MainActor
struct CarPlayTabLabelTests {

    @Test(arguments: 0 ... 3, 0 ... 3)
    func `tab labels render and update without retaining old values`(
        source: Int,
        destination: Int
    ) throws {

        let image = UIImage()
        let defaultItem = CPListTemplate(title: nil, sections: []).tabSystemItem
        let labels: [CarPlayTabLabel] = [
            .title("Library"),
            .image(image),
            .titleAndImage("Library", image),
            .system(.favorites)
        ]
        let titles: [String?] = ["Library", nil, "Library", nil]
        let images: [UIImage?] = [nil, image, image, nil]
        let node = try self.mount(labels[source])
        let tabBar = try #require(node.template as? CPTabBarTemplate)
        let tab = try #require(tabBar.templates.first)
        #expect(tab.tabTitle == titles[source])
        #expect(tab.tabImage === images[source])
        #expect(tab.tabSystemItem == (source == 3 ? .favorites : defaultItem))
        try node.update(self.tabs(labels[destination])._resolve())
        #expect(tabBar.templates.first === tab)
        #expect(tab.tabTitle == titles[destination])
        #expect(tab.tabImage === images[destination])
        #expect(
            tab.tabSystemItem == (destination == 3 ? .favorites : defaultItem)
        )
    }
}

private extension CarPlayTabLabelTests {

    func tabs(_ label: CarPlayTabLabel) -> CarPlayTabs {

        CarPlayTabs {

            CarPlayTab(id: "library", label: label) {

                CarPlayList {}
            }
        }
    }

    func mount(_ label: CarPlayTabLabel) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: self.tabs(label)._resolve(),
            context: .init(),
            onError: { Issue.record("Unexpected rendering error: \($0)") }
        )
    }
}
