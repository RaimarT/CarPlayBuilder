// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Owns native list presentation, sections, and header controls.
@MainActor
final class CarPlayMountedList {

    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    private let template: CPListTemplate
    private let rows: CarPlayMountedRows
    private let defaultEmptyViewSpinner: Bool
    private let defaultEmptyView: (title: [String], subtitle: [String])
    private var listHeader: CarPlayMountedListHeader?
    private var headerButtons: [
        CarPlayContentIdentity: CarPlayMountedSectionHeaderButton
    ] = [:]

    init(
        template: CPListTemplate,
        context: CarPlayContext,
        scope: CarPlayTaskScope
    ) {

        self.template = template
        self.context = context
        self.scope = scope
        self.rows = CarPlayMountedRows(context: context, scope: scope)
        self.defaultEmptyView = (
            template.emptyViewTitleVariants,
            template.emptyViewSubtitleVariants
        )
        if #available(iOS 18.4, *) {

            self.defaultEmptyViewSpinner = template.showsSpinnerWhileEmpty
        } else {

            self.defaultEmptyViewSpinner = false
        }
    }

    func update(_ content: CarPlayTemplateContent, sections: [CarPlaySection]) {

        self.updateListHeader(content)
        self.updateEmptyView(content)
        self.updateSections(sections)
    }

    func cancel() {

        self.listHeader?.cancel()
        for button in self.headerButtons.values {

            button.cancel()
        }
        self.rows.cancel()
    }
}

private extension CarPlayMountedList {

    func updateListHeader(_ content: CarPlayTemplateContent) {

        guard #available(iOS 26.4, *) else {

            return
        }

        let list = self.template

        guard let header = content.listHeader else {

            self.listHeader?.cancel()
            self.listHeader = nil
            list.listHeader = nil
            return
        }

        let mounted = self.listHeader ?? CarPlayMountedListHeader(
            context: self.context,
            scope: self.scope
        )
        mounted.update(header, in: list)
        self.listHeader = mounted
    }

    func updateEmptyView(_ content: CarPlayTemplateContent) {

        let list = self.template
        self.updateEmptyViewSpinner(content, in: list)
        let titles = content.emptyViewTitleVariants ?? self.defaultEmptyView.title
        let subtitles = content.emptyViewSubtitleVariants
            ?? self.defaultEmptyView.subtitle

        if list.emptyViewTitleVariants != titles {

            list.emptyViewTitleVariants = titles
        }

        if list.emptyViewSubtitleVariants != subtitles {

            list.emptyViewSubtitleVariants = subtitles
        }
    }

    func updateEmptyViewSpinner(
        _ content: CarPlayTemplateContent,
        in list: CPListTemplate
    ) {

        guard #available(iOS 18.4, *) else {

            return
        }

        let visible = content.emptyViewSpinner ?? self.defaultEmptyViewSpinner
        if list.showsSpinnerWhileEmpty != visible {

            list.showsSpinnerWhileEmpty = visible
        }
    }

    func updateHeaderButtons(
        _ sections: [CarPlaySection]
    ) -> [CarPlayContentIdentity: CarPlayMountedSectionHeaderButton] {

        var updated: [CarPlayContentIdentity: CarPlayMountedSectionHeaderButton] =
            [:]

        for (index, section) in sections.enumerated() {

            guard let button = section.button else {

                continue
            }

            let identity = section.identity
                .map(CarPlayContentIdentity.explicit) ?? .position(index)
            let mounted = self.headerButtons[identity]
                ?? CarPlayMountedSectionHeaderButton(
                    content: button,
                    context: self.context,
                    scope: self.scope
                )
            mounted.update(button)
            updated[identity] = mounted
        }

        for (identity, button) in self.headerButtons where updated[identity] == nil {

            button.cancel()
        }

        self.headerButtons = updated

        return updated
    }

    func makeSection(
        items: [any CPListTemplateItem],
        section: CarPlaySection,
        button: CPButton?,
        existing: CPListSection?
    ) -> CPListSection {

        if let existing, existing.header == section.header,
           existing.headerSubtitle == section.subtitle,
           existing.headerImage === section.image,
           existing.headerButton === button,
           existing.sectionIndexTitle == section.sectionIndexTitle,
           existing.items.count == items.count,
           zip(existing.items, items).allSatisfy({ $0 === $1 }) {

            return existing
        }
        if let header = section.header {

            return CPListSection(
                items: items,
                header: header,
                headerSubtitle: section.subtitle,
                headerImage: section.image,
                headerButton: button,
                sectionIndexTitle: section.sectionIndexTitle
            )
        }
        return CPListSection(
            items: items,
            header: nil,
            sectionIndexTitle: section.sectionIndexTitle
        )
    }

    func updateSections(_ sections: [CarPlaySection]) {

        let headers = self.updateHeaderButtons(sections)
        let rows = self.rows.update(sections)
        let native = sections.enumerated().map { index, section in

            let identity = section.identity
                .map(CarPlayContentIdentity.explicit) ?? .position(index)
            return self.makeSection(
                items: rows[index],
                section: section,
                button: headers[identity]?.item,
                existing: self.template.sections.indices.contains(index)
                    ? self.template.sections[index] : nil
            )
        }

        if self.template.sections != native {

            self.template.updateSections(native)
        }
    }
}
