// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Maps native selections to stable IDs and suppresses repeated notifications.
@MainActor
final class CarPlayTabSelectionObserver: NSObject, CPTabBarTemplateDelegate {

    private weak var tabBar: CPTabBarTemplate?
    private var tabs: [(id: AnyHashable, template: CPTemplate)] = []
    private var selectedID: AnyHashable?
    private var handler: CarPlayTabSelectionHandler?

    func update(
        tabBar: CPTabBarTemplate,
        tabs: [(id: AnyHashable, template: CPTemplate)],
        handler: CarPlayTabSelectionHandler?
    ) {

        self.tabBar = tabBar
        self.tabs = tabs
        self.handler = handler
        if !tabs.contains(where: { $0.id == self.selectedID }) {

            self.selectedID = tabs.first {

                $0.template === tabBar.selectedTemplate
            }?.id ?? tabs.first?.id
        }
        tabBar.delegate = self
    }

    func select(_ template: CPTemplate) {

        guard self.tabBar != nil,
              let tab = self.tabs.first(where: { $0.template === template }),
              tab.id != self.selectedID
        else {

            return
        }

        self.selectedID = tab.id
        self.handler?(tab.id)
    }

    func cancel() {

        if self.tabBar?.delegate === self {

            self.tabBar?.delegate = nil
        }
        self.tabBar = nil
        self.tabs = []
        self.handler = nil
        self.selectedID = nil
    }

    func tabBarTemplate(
        _ tabBarTemplate: CPTabBarTemplate,
        didSelect selectedTemplate: CPTemplate
    ) {

        guard tabBarTemplate === self.tabBar else {

            return
        }

        self.select(selectedTemplate)
    }
}
