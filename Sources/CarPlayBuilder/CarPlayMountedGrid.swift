// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Reconciles grid buttons while retaining identity and running actions.
@MainActor
final class CarPlayMountedGrid {

    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    private let template: CPGridTemplate
    private var buttons: [CarPlayContentIdentity: MountedButton] = [:]

    init(
        template: CPGridTemplate,
        context: CarPlayContext,
        scope: CarPlayTaskScope
    ) {

        self.template = template
        self.context = context
        self.scope = scope
    }

    func update(_ buttons: [CarPlayButton], title: String?) {

        let grid = self.template
        var updated: [CarPlayContentIdentity: MountedButton] = [:]
        let native = buttons.enumerated().map { index, button in

            let key = button.identity
                .map(CarPlayContentIdentity.explicit) ?? .position(index)
            let mounted = self.buttons[key] ?? MountedButton(content: button)
            let item = self.updateButton(mounted, with: button)
            updated[key] = mounted

            return item
        }

        for (id, button) in self.buttons where updated[id] == nil {

            button.actionState.cancel()
        }
        self.buttons = updated

        if grid.title != title {

            grid.updateTitle(title ?? "")
        }

        if grid.gridButtons != native {

            grid.updateGridButtons(native)
        }
    }

    func cancel() {

        for button in self.buttons.values {

            button.actionState.cancel()
        }
    }
}

private extension CarPlayMountedGrid {

    func updateButton(
        _ mounted: MountedButton,
        with button: CarPlayButton
    ) -> CPGridButton {

        let old = mounted.content
        mounted.content = button

        let item: CPGridButton
        if let existing = mounted.item {

            if #available(iOS 26.0, *) {

                if old.titles != button.titles {

                    existing.updateTitleVariants(button.titles)
                }

                if old.image !== button.image {

                    existing.updateImage(button.image)
                }

                item = existing
            } else if old.titles == button.titles, old.image === button.image {

                item = existing
            } else {

                item = self.makeButton(mounted)
            }
        } else {

            item = self.makeButton(mounted)
        }

        mounted.item = item

        self.updateGridAvailability(mounted)

        return item
    }

    func updateGridAvailability(_ mounted: MountedButton) {

        mounted.actionState.update(
            enabled: mounted.content.isEnabled,
            policy: mounted.content.repeatPolicy
        ) { [weak mounted] enabled in

            mounted?.item?.isEnabled = enabled
        }
    }

    func makeButton(_ mounted: MountedButton) -> CPGridButton {

        CPGridButton(
            titleVariants: mounted.content.titles,
            image: mounted.content.image
        ) { [weak self, weak mounted] button in

            guard let self, let mounted, mounted.item === button else {

                return
            }

            let action = mounted.content.action
            let context = self.context
            mounted.actionState.perform(
                in: self.scope,
                control: .gridButton,
                controlID: mounted.content.identity
            ) {

                try await action(context)
            }
        }
    }
}

private extension CarPlayMountedGrid {

    final class MountedButton {

        let actionState = CarPlayActionState()
        var content: CarPlayButton
        var item: CPGridButton?

        init(content: CarPlayButton) {

            self.content = content
        }
    }
}
