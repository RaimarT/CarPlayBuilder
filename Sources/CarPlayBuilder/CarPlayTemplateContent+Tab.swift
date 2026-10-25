// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

extension CarPlayTemplateContent {

    /// A resolved tab snapshot used for validation and native reconciliation.
    struct Tab {

        let id: AnyHashable
        let label: CarPlayTabLabel
        let showsBadge: Bool
        let content: CarPlayTemplateContent
    }
}
