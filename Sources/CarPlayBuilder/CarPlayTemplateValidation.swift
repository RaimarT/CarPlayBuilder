// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Validates native counts, stable IDs, and supported template placements.
///
/// Run validation before constructing or mutating native objects to avoid
/// invalid CarPlay API usage and preserve previously rendered content.
@MainActor
enum CarPlayTemplateValidation {

    /// Validates the complete resolved subtree for the requested root position.
    static func validate(
        _ content: CarPlayTemplateContent,
        allowsTabs: Bool = true
    ) throws {

        try self.validateListHeader(content)
        try self.validateToolbar(content)
        switch content.kind {

        case let .list(_, sections):
            try self.validateSections(sections)

        case let .grid(_, buttons):
            try self.validateButtons(buttons)

        case let .tabs(tabs):
            try self.validateTabs(tabs, allowsTabs: allowsTabs)

        case .nowPlaying:
            break
        }
    }
}

private extension CarPlayTemplateValidation {

    static func validateListHeader(_ content: CarPlayTemplateContent) throws {

        guard let header = content.listHeader else {

            return
        }

        guard #available(iOS 26.4, *), case .list = content.kind else {

            throw CarPlayError.invalidContent(
                "Rich headers require an iOS 26.4 list template."
            )
        }

        guard header.buttons.count <=
            CPListTemplateDetailsHeader.maximumActionButtonCount,
            header.buttons.allSatisfy({

                $0.image != nil || $0.title?.isEmpty == false
            })
        else {

            throw CarPlayError.invalidContent(
                "Rich header actions require labels or images "
                    + "and must respect the native action count limit."
            )
        }

        try self.validateIDs(header.buttons.compactMap(\.identity), kind: "Header")
    }

    static func validateToolbar(_ content: CarPlayTemplateContent) throws {

        let buttons = content.leadingButtons + content.trailingButtons
        if buttons.isEmpty {

            return
        }

        switch content.kind {

        case .grid,
             .list:
            break

        default:
            throw CarPlayError.invalidContent("This template cannot show a toolbar.")
        }

        guard content.leadingButtons.count <= 2, content.trailingButtons.count <= 2,
              buttons.allSatisfy({ $0.image != nil || $0.title?.isEmpty == false })
        else {

            throw CarPlayError.invalidContent("Toolbars allow two buttons per side.")
        }

        try self.validateIDs(
            content.leadingButtons.compactMap(\.identity),
            kind: "Bar"
        )
        try self.validateIDs(
            content.trailingButtons.compactMap(\.identity),
            kind: "Bar"
        )
    }

    static func validateSections(_ sections: [CarPlaySection]) throws {

        try self.validateIDs(
            sections.compactMap(\.identity),
            kind: "Section"
        )

        for section in sections {

            try self.validateHeader(section)

            try self.validateIDs(
                section.rows.compactMap(\.identity),
                kind: "Row"
            )

            for row in section.rows {

                if let imageRow = row.imageRow {

                    try self.validateImageRow(imageRow)
                }
            }
        }

        guard sections.count <= CPListTemplate.maximumSectionCount,
              sections.reduce(
                  0,
                  { $0 + $1.rows.count }
              ) <= CPListTemplate.maximumItemCount
        else {

            throw CarPlayError
                .invalidContent("The list exceeds CarPlay's section or item limit.")
        }
    }

    static func validateHeader(_ section: CarPlaySection) throws {

        let hasDetails = section.subtitle != nil || section.image != nil
            || section.button != nil

        guard !hasDetails || section.header != nil else {

            throw CarPlayError.invalidContent(
                "Section header details require a header title."
            )
        }

        guard section.button?.title.isEmpty != true else {

            throw CarPlayError.invalidContent(
                "Section header buttons require a nonempty title."
            )
        }
    }

    static func validateImageRow(_ row: CarPlayImageRowContent) throws {

        guard !row.actions.isEmpty,
              row.actions.count <= Int(CPMaximumNumberOfGridImages)
        else {

            throw CarPlayError.invalidContent(
                "Image rows need 1–\(CPMaximumNumberOfGridImages) elements."
            )
        }

        try self.validateIDs(row.elementIDs, kind: "Element")
    }

    static func validateIDs(_ ids: [AnyHashable], kind: String) throws {

        guard Set(ids).count == ids.count else {

            throw CarPlayError
                .invalidContent("\(kind) IDs must be unique among siblings.")
        }
    }

    static func validateButtons(_ buttons: [CarPlayButton]) throws {

        try self.validateIDs(buttons.compactMap(\.identity), kind: "Button")

        guard !buttons.isEmpty,
              buttons.count <= Int(CPGridTemplateMaximumItems),
              buttons.allSatisfy({ !$0.titles.isEmpty })
        else {

            throw CarPlayError
                .invalidContent(
                    "A grid needs 1–8 buttons, each with at least one title variant."
                )
        }
    }

    static func validateTabs(
        _ tabs: [CarPlayTemplateContent.Tab],
        allowsTabs: Bool
    ) throws {

        guard allowsTabs,
              !tabs.isEmpty,
              tabs.count <= CPTabBarTemplate.maximumTabCount,
              Set(tabs.map(\.id)).count == tabs.count
        else {

            throw CarPlayError
                .invalidContent(
                    "Tabs must be at the root, have unique IDs, "
                        + "and respect CarPlay's tab limit."
                )
        }

        for tab in tabs {

            guard tab.content.leadingButtons.isEmpty,
                  tab.content.trailingButtons.isEmpty
            else {

                throw CarPlayError.invalidContent("Tab roots cannot show toolbars.")
            }

            try self.validateTabRoot(tab.content)
            try self.validate(tab.content, allowsTabs: false)
        }
    }

    static func validateTabRoot(_ content: CarPlayTemplateContent) throws {

        switch content.kind {

        case .grid,
             .list:
            break

        default:
            throw CarPlayError
                .invalidContent("Tab roots must be list or grid templates.")
        }
    }
}
