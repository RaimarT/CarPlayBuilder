// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Reconciles navigation controls independently of screen content.
@MainActor
final class CarPlayMountedToolbar {

    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    private let template: CPTemplate
    private var leadingBars: [CarPlayContentIdentity: CarPlayMountedBarButton] = [:]
    private var trailingBars: [CarPlayContentIdentity: CarPlayMountedBarButton] = [:]

    init(
        template: CPTemplate,
        context: CarPlayContext,
        scope: CarPlayTaskScope
    ) {

        self.template = template
        self.context = context
        self.scope = scope
    }

    func update(_ content: CarPlayTemplateContent) {

        switch content.kind {

        case .grid,
             .list:
            break
        default:
            return
        }

        guard let toolbar = self.template as? any CPBarButtonProviding else {

            return
        }

        let leading = self.mountBars(
            content.leadingButtons,
            cache: &self.leadingBars
        )
        if toolbar.leadingNavigationBarButtons != leading {

            toolbar.leadingNavigationBarButtons = leading
        }

        let trailing = self.mountBars(
            content.trailingButtons,
            cache: &self.trailingBars
        )
        if toolbar.trailingNavigationBarButtons != trailing {

            toolbar.trailingNavigationBarButtons = trailing
        }
    }

    func cancel() {

        for button in self.leadingBars.values {

            button.cancel()
        }
        for button in self.trailingBars.values {

            button.cancel()
        }
    }
}

private extension CarPlayMountedToolbar {

    func mountBars(
        _ buttons: [CarPlayBarButton],
        cache: inout [CarPlayContentIdentity: CarPlayMountedBarButton]
    ) -> [CPBarButton] {

        var updated: [CarPlayContentIdentity: CarPlayMountedBarButton] = [:]
        let items = buttons.enumerated().map { index, button in

            let id = button.identity
                .map(CarPlayContentIdentity.explicit) ?? .position(index)
            let mounted = cache[id] ?? CarPlayMountedBarButton(
                content: button,
                context: self.context,
                scope: self.scope
            )
            mounted.update(button)
            updated[id] = mounted
            return mounted.item
        }

        for (id, mounted) in cache where updated[id] == nil {

            mounted.cancel()
        }

        cache = updated

        return items
    }
}
