// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Keeps a section header button stable while updating its action and state.
@MainActor
final class CarPlayMountedSectionHeaderButton {

    private var content: CarPlaySectionHeaderButton
    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    let actionState: CarPlayActionState
    private var active = true
    private lazy var native = self.makeNative()

    var item: CPButton {

        self.native
    }

    init(
        content: CarPlaySectionHeaderButton,
        context: CarPlayContext,
        scope: CarPlayTaskScope,
        actionState: CarPlayActionState? = nil
    ) {

        self.content = content
        self.context = context
        self.scope = scope
        self.actionState = actionState ?? CarPlayActionState()
    }

    func update(_ content: CarPlaySectionHeaderButton) {

        self.content = content
        self.item.title = content.title
        self.updateAvailability()
    }

    func activate() {

        guard self.active, self.content.isEnabled else {

            return
        }

        self.updateAvailability()
        let action = self.content.action
        let context = self.context
        self.actionState.perform(
            in: self.scope,
            control: .sectionHeaderButton
        ) {

            try await action(context)
        }
    }

    func cancel() {

        self.active = false
        self.actionState.cancel()
    }

    private func updateAvailability() {

        self.actionState.update(
            enabled: self.content.isEnabled,
            policy: self.content.repeatPolicy
        ) { [weak self] enabled in

            if let self, self.item.isEnabled != enabled {

                self.item.isEnabled = enabled
            }
        }
    }

    private func makeNative() -> CPButton {

        // CPButton requires an image even in headers that display its title.
        let button = CPButton(image: UIImage()) { [weak self] _ in

            Task { @MainActor [weak self] in

                self?.activate()
            }
        }
        button.title = self.content.title
        button.isEnabled = self.content.isEnabled

        return button
    }
}
