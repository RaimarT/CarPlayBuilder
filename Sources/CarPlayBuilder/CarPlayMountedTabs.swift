// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Owns tab children, selection observation, and descendant lifecycle.
@MainActor
final class CarPlayMountedTabs {

    private let template: CPTabBarTemplate
    private let context: CarPlayContext
    private let onError: CarPlayContextualErrorHandler
    private let tabSelection = CarPlayTabSelectionObserver()
    private var children: [(id: AnyHashable, node: CarPlayMountedTemplate)] = []

    init(
        template: CPTabBarTemplate,
        context: CarPlayContext,
        onError: @escaping CarPlayContextualErrorHandler
    ) {

        self.template = template
        self.context = context
        self.onError = onError
    }

    func validateUpdate(_ tabs: [CarPlayTemplateContent.Tab]) throws {

        for tab in tabs {

            if let child = self.children.first(where: { $0.id == tab.id }) {

                try child.node.validateUpdate(tab.content)
            }
        }
    }

    func didSelectTab(_ template: CPTemplate) {

        self.tabSelection.select(template)
    }

    func setVisible(_ visible: Bool, for target: CPTemplate) {

        for child in self.children {

            child.node.setVisible(visible, for: target)
        }
    }

    func cancel() {

        self.tabSelection.cancel()
        for child in self.children {

            child.node.cancel()
        }
    }

    func update(
        _ tabs: [CarPlayTemplateContent.Tab],
        handler: CarPlayTabSelectionHandler?
    ) throws {

        let tabBar = self.template
        let updated = try tabs.map { tab in

            let node = try self.makeTab(tab)

            return (id: tab.id, node: node)
        }

        for old in self.children
            where !updated.contains(where: {

                $0.id == old.id
            }) {

            old.node.cancel()
        }
        self.children = updated
        let templates = updated.map {

            $0.node.template
        }
        self.updateNativeTabs(
            tabBar,
            templates: templates,
            children: updated,
            handler: handler
        )
    }
}

private extension CarPlayMountedTabs {

    func updateNativeTabs(
        _ tabBar: CPTabBarTemplate,
        templates: [CPTemplate],
        children: [(id: AnyHashable, node: CarPlayMountedTemplate)],
        handler: CarPlayTabSelectionHandler?
    ) {

        tabBar.delegate = nil
        if tabBar.templates != templates {

            tabBar.updateTemplates(templates)
        }
        self.tabSelection.update(
            tabBar: tabBar,
            tabs: children.map { ($0.id, $0.node.template) },
            handler: handler
        )
    }

    func makeTab(
        _ tab: CarPlayTemplateContent.Tab
    ) throws -> CarPlayMountedTemplate {

        let node: CarPlayMountedTemplate
        if let existing = self.children.first(where: {

            $0.id == tab.id
        })?.node {

            node = existing
            try node.update(tab.content)
        } else {

            node = try CarPlayMountedTemplate(
                content: tab.content,
                context: self.context,
                onErrorWithContext: self.onError
            )
        }
        node.updateTabLabel(tab.label)
        node.template.showsTabBadge = tab.showsBadge

        return node
    }
}
