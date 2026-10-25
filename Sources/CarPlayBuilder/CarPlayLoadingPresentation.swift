// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Replaces or supplements content without changing native template ownership.
@MainActor
struct CarPlayLoadingPresentation {

    let status: CarPlayLoadingStatus?
    let retainsContent: Bool
    let configuration: CarPlayLoadingConfiguration
    let rows: CarPlayStatusContent<CarPlayRow>?
    let buttons: CarPlayStatusContent<CarPlayButton>?
    let retry: CarPlayTaskAction?

    func apply(to content: inout CarPlayTemplateContent) {

        guard let status else {

            return
        }

        switch content.kind {

        case let .list(title, sections):
            content.kind = .list(
                title,
                self.sections(sections, status: status)
            )

        case let .grid(title, buttons):
            content.kind = .grid(
                title,
                self.gridButtons(buttons, status: status)
            )

        default:
            break
        }
    }
}

private extension CarPlayLoadingPresentation {

    func sections(
        _ original: [CarPlaySection],
        status: CarPlayLoadingStatus
    ) -> [CarPlaySection] {

        let hasRows = original.contains { !$0.rows.isEmpty }
        let retain = self.retainsContent && hasRows && status.allowsRetention

        guard !retain || !status.isLoading else {

            return original
        }

        let rows = self.rows?(status)
            ?? status.rows(configuration: self.configuration, retry: self.retry)

        guard !rows.isEmpty else {

            return retain ? original : []
        }

        let section = CarPlaySection { rows }.id(StatusIdentity.section)

        return retain ? original + [section] : [section]
    }

    func gridButtons(
        _ original: [CarPlayButton],
        status: CarPlayLoadingStatus
    ) -> [CarPlayButton] {

        let retain = self.retainsContent && !original.isEmpty
            && status.allowsRetention

        guard !retain || !status.isLoading else {

            return original
        }

        let buttons = self.buttons?(status)
            ?? status.buttons(configuration: self.configuration, retry: self.retry)

        return retain ? original + buttons : buttons
    }

    /// A private ID avoids collisions with app-provided section identities.
    enum StatusIdentity: Hashable {

        case section
    }
}
