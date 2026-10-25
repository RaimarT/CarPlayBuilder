// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

extension CarPlayTemplateContent {

    /// A visibility-bound task definition identified within its modifier position.
    struct LifecycleTask {

        let id: AnyHashable
        let priority: TaskPriority
        let action: CarPlayTaskAction
    }
}
