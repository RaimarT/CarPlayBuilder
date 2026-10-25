// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Reuses compatible header actions while invalidating stale native handlers.
@MainActor
final class CarPlayMountedListHeaderButton {

    private(set) var content: CarPlayListHeaderButton
    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    let actionState: CarPlayActionState
    private var active = true
    private lazy var native = self.makeNative()

    var item: CPButton {

        self.native
    }

    init(
        content: CarPlayListHeaderButton,
        context: CarPlayContext,
        scope: CarPlayTaskScope,
        actionState: CarPlayActionState? = nil
    ) {

        self.content = content
        self.context = context
        self.scope = scope
        self.actionState = actionState ?? CarPlayActionState()
    }

    func update(_ content: CarPlayListHeaderButton) {

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
            control: .listHeaderButton,
            controlID: self.content.identity
        ) {

            try await action(context)
        }
    }

    func cancel() {

        self.active = false
        self.actionState.cancel()
    }

    /// Retires a replaced native button while transferring its busy state.
    func retire() {

        self.active = false
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

        let button = CPButton(image: self.content.image ?? UIImage()) {
            [weak self] _ in

            Task { @MainActor [weak self] in

                self?.activate()
            }
        }
        button.title = self.content.title
        button.isEnabled = self.content.isEnabled

        return button
    }
}
