// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Reconciles rich headers without raising the package's minimum iOS version.
@MainActor
final class CarPlayMountedListHeader {

    // Native storage is erased because details headers require iOS 26.4.
    private var native: NSObject?
    private var buttons: [Identity: CarPlayMountedListHeaderButton] = [:]
    private let context: CarPlayContext
    private let scope: CarPlayTaskScope

    init(context: CarPlayContext, scope: CarPlayTaskScope) {

        self.context = context
        self.scope = scope
    }

    @available(iOS 26.4, *)
    func update(_ content: CarPlayListHeader, in list: CPListTemplate) {

        let header: CPListTemplateDetailsHeader

        if let existing = self.native as? CPListTemplateDetailsHeader {

            header = existing
        } else {

            header = CPListTemplateDetailsHeader(
                thumbnail: CPThumbnailImage(image: content.image),
                title: content.title,
                subtitle: content.subtitle,
                actionButtons: []
            )
            self.native = header
        }

        self.updateContent(content, header: header)
        if list.listHeader !== header {

            list.listHeader = header
        }
    }

    @available(iOS 26.4, *)
    private func updateContent(
        _ content: CarPlayListHeader,
        header: CPListTemplateDetailsHeader
    ) {

        if header.title != content.title {

            header.title = content.title
        }

        if header.subtitle != content.subtitle {

            header.subtitle = content.subtitle
        }

        if header.thumbnail.image !== content.image {

            header.thumbnail = CPThumbnailImage(image: content.image)
        }

        let buttons = self.updateButtons(content.buttons)
        if header.actionButtons != buttons {

            header.actionButtons = buttons
        }
    }

    func cancel() {

        for button in self.buttons.values {

            button.cancel()
        }

        self.buttons = [:]
        self.native = nil
    }
}

private extension CarPlayMountedListHeader {

    func updateButtons(_ content: [CarPlayListHeaderButton]) -> [CPButton] {

        var updated: [Identity: CarPlayMountedListHeaderButton] = [:]
        let native = content.enumerated().map { index, button in

            let identity = button.identity
                .map(Identity.explicit) ?? .position(index)
            let mounted = self.mountButton(button, identity: identity)
            updated[identity] = mounted

            return mounted.item
        }

        for (identity, button) in self.buttons where updated[identity] == nil {

            button.cancel()
        }

        self.buttons = updated

        return native
    }

    func mountButton(
        _ content: CarPlayListHeaderButton,
        identity: Identity
    ) -> CarPlayMountedListHeaderButton {

        let mounted: CarPlayMountedListHeaderButton
        if let existing = self.buttons[identity],
           existing.content.image === content.image {

            mounted = existing
        } else {

            self.buttons[identity]?.retire()
            mounted = CarPlayMountedListHeaderButton(
                content: content,
                context: self.context,
                scope: self.scope,
                actionState: self.buttons[identity]?.actionState
            )
        }
        mounted.update(content)

        return mounted
    }

    enum Identity: Hashable {

        case explicit(AnyHashable)
        case position(Int)
    }
}
