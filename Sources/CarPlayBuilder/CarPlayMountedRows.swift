// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Reconciles section-scoped list items and their retained action state.
@MainActor
final class CarPlayMountedRows {

    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    private var rows: [RowKey: MountedRow] = [:]

    init(context: CarPlayContext, scope: CarPlayTaskScope) {

        self.context = context
        self.scope = scope
    }

    func update(_ sections: [CarPlaySection]) -> [[any CPListTemplateItem]] {

        var updated: [RowKey: MountedRow] = [:]
        let native = sections.enumerated().map { index, section in

            let identity = section.identity
                .map(CarPlayContentIdentity.explicit) ?? .position(index)

            return self.makeRows(
                section.rows,
                section: identity,
                updated: &updated
            )
        }

        for (key, row) in self.rows where updated[key] == nil {

            row.cancel()
        }
        self.rows = updated
        return native
    }

    func cancel() {

        for row in self.rows.values {

            row.cancel()
        }
    }
}

private extension CarPlayMountedRows {

    func makeRows(
        _ rows: [CarPlayRow],
        section: CarPlayContentIdentity,
        updated: inout [RowKey: MountedRow]
    ) -> [any CPListTemplateItem] {

        rows.enumerated().map { index, row in

            let key = RowKey(
                section: section,
                row: row.identity
                    .map(CarPlayContentIdentity.explicit) ?? .position(index)
            )
            let mounted = self.makeRow(row, key: key)
            updated[key] = mounted

            return mounted.item
        }
    }

    func makeRow(_ row: CarPlayRow, key: RowKey) -> MountedRow {

        if let imageRow = row.imageRow {

            return self.makeImageRow(imageRow, row: row, key: key)
        }

        let previous = self.rows[key]
        if previous?.layout != nil {

            previous?.cancel()
        }
        let state = previous?.layout == nil
            ? previous?.actionState ?? CarPlayActionState() : CarPlayActionState()
        let item = (previous?.item as? CPListItem) ?? CPListItem(
            text: row.title,
            detailText: row.detail,
            image: row.image
        )
        self.configure(item, with: row, state: state)

        return MountedRow(item: item, layout: nil, actionState: state)
    }

    func makeImageRow(
        _ content: CarPlayImageRowContent,
        row: CarPlayRow,
        key: RowKey
    ) -> MountedRow {

        if let previous = self.rows[key], previous.layout == nil {

            previous.cancel()
        }

        let item: CPListImageRowItem = if let existing = self.rows[key],
                                          existing.layout == content.layout,
                                          let native = existing
                                          .item as? CPListImageRowItem {

            native
        } else {

            content.make()
        }
        content.update(item)
        if item.isEnabled != row.isEnabled {

            item.isEnabled = row.isEnabled
        }
        let states = self.imageActionStates(content, item: item, row: row, key: key)
        self.configureImageSelection(
            item,
            content: content,
            states: states,
            key: key
        )

        return MountedRow(
            item: item,
            layout: content.layout,
            elementStates: states
        )
    }

    func imageActionStates(
        _ content: CarPlayImageRowContent,
        item: CPListImageRowItem,
        row: CarPlayRow,
        key: RowKey
    ) -> [CarPlayContentIdentity: CarPlayActionState] {

        var updated: [CarPlayContentIdentity: CarPlayActionState] = [:]

        for index in content.actions.indices {

            let id = content.identities[index]
                .map(CarPlayContentIdentity.explicit) ?? .position(index)
            let state = self.rows[key]?.elementStates[id] ?? CarPlayActionState()
            self.configureImageAvailability(
                state,
                item: item,
                index: index,
                enabled: row.isEnabled && content.actions[index] != nil,
                policy: content.policies[index]
            )
            updated[id] = state
        }

        for (id, state) in self.rows[key]?.elementStates ?? [:]
            where updated[id] == nil {

            state.cancel()
        }

        return updated
    }

    func configureImageAvailability(
        _ state: CarPlayActionState,
        item: CPListImageRowItem,
        index: Int,
        enabled: Bool,
        policy: CarPlayRepeatedActionPolicy
    ) {

        state.update(enabled: enabled, policy: policy) { [weak item] enabled in

            if #available(iOS 26.0, *), let item,
               item.elements.indices.contains(index) {

                item.elements[index].isEnabled = enabled
            }
        }
    }

    func configureImageSelection(
        _ item: CPListImageRowItem,
        content: CarPlayImageRowContent,
        states: [CarPlayContentIdentity: CarPlayActionState],
        key: RowKey
    ) {

        item.listImageRowHandler = { [weak self, weak item] _, index, completion in

            guard let self, let item, self.rows[key]?.item === item,
                  content.actions.indices.contains(index),
                  let action = content.actions[index]
            else {

                completion()
                return
            }

            let id = content.identities[index]
                .map(CarPlayContentIdentity.explicit) ?? .position(index)
            let context = self.context

            guard let state = states[id] else {

                completion()
                return
            }

            state.perform(
                in: self.scope,
                control: .imageElement,
                controlID: content.identities[index],
                action: {

                    try await action(context)
                },
                completion: { completion() }
            )
        }
    }

    func configure(
        _ item: CPListItem,
        with row: CarPlayRow,
        state: CarPlayActionState
    ) {

        if item.text != row.title {

            item.setText(row.title)
        }

        if item.detailText != row.detail {

            item.setDetailText(row.detail)
        }

        if item.image !== row.image {

            item.setImage(row.image)
        }

        if item.accessoryImage !== row.trailingImage {

            item.setAccessoryImage(row.trailingImage)
        }

        if item.isExplicitContent != row.isExplicitContent {

            item.isExplicitContent = row.isExplicitContent
        }

        self.configurePlayback(item, with: row)
        self.configureSelection(item, with: row, state: state)
    }

    func configurePlayback(_ item: CPListItem, with row: CarPlayRow) {

        let accessory = row.trailingImage == nil ? row.accessory : .none

        if item.accessoryType != accessory {

            item.accessoryType = accessory
        }

        if item.playingIndicatorLocation != row.indicatorLocation {

            item.playingIndicatorLocation = row.indicatorLocation
        }

        if item.isPlaying != row.isPlaying {

            item.isPlaying = row.isPlaying
        }

        if item.playbackProgress != row.progress {

            item.playbackProgress = row.progress
        }
    }

    func configureSelection(
        _ item: CPListItem,
        with row: CarPlayRow,
        state: CarPlayActionState
    ) {

        state.update(enabled: row.isEnabled, policy: row.repeatPolicy) {
            [weak item] enabled in

            item?.isEnabled = enabled
        }

        if let action = row.action {

            item.handler = { [weak self] _, completion in

                guard let self else {

                    completion()
                    return
                }

                let context = self.context
                state.perform(
                    in: self.scope,
                    control: .row,
                    controlID: row.identity,
                    action: {

                        try await action(context)
                    },
                    completion: { completion() }
                )
            }
        } else {

            item.handler = nil
        }
    }
}

private extension CarPlayMountedRows {

    struct RowKey: Hashable {

        let section: CarPlayContentIdentity
        let row: CarPlayContentIdentity
    }

    @MainActor
    struct MountedRow {

        let item: any CPListTemplateItem
        let layout: AnyHashable?
        var actionState = CarPlayActionState()
        var elementStates: [CarPlayContentIdentity: CarPlayActionState] = [:]

        func cancel() {

            self.actionState.cancel()
            for state in self.elementStates.values {

                state.cancel()
            }
        }
    }
}
