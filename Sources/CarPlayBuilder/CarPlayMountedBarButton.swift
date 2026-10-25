// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Retains native bar-button identity while replacing its value and callback.
///
/// Cancellation makes stale native tap handlers inert after button removal.
@MainActor
final class CarPlayMountedBarButton {

    private var content: CarPlayBarButton
    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    let actionState: CarPlayActionState
    private var active = true
    private lazy var native = self.makeNative()

    var item: CPBarButton {

        self.native
    }

    init(
        content: CarPlayBarButton,
        context: CarPlayContext,
        scope: CarPlayTaskScope,
        actionState: CarPlayActionState? = nil
    ) {

        self.content = content
        self.context = context
        self.scope = scope
        self.actionState = actionState ?? CarPlayActionState()
    }

    /// Updates title, image, and enabled state without replacing the native item.
    func update(_ content: CarPlayBarButton) {

        self.content = content
        let item = self.item

        if item.title != content.title {

            item.title = content.title
        }

        if item.image !== content.image {

            item.image = content.image
        }

        self.updateAvailability()
    }

    /// Dispatches the latest action only while the button remains active.
    func activate() {

        guard self.active, self.content.isEnabled else {

            return
        }

        self.updateAvailability()
        let action = self.content.action
        let context = self.context
        self.actionState.perform(
            in: self.scope,
            control: .barButton,
            controlID: self.content.identity
        ) {

            try await action(context)
        }
    }

    /// Prevents previously retained native handlers from invoking removed actions.
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
}

private extension CarPlayMountedBarButton {

    func makeNative() -> CPBarButton {

        let handler: CPBarButtonHandler = { [weak self] _ in

            Task { @MainActor [weak self] in self?.activate() }
        }
        if let image = self.content.image {

            return CPBarButton(image: image, handler: handler)
        }
        return CPBarButton(title: self.content.title ?? "", handler: handler)
    }
}
