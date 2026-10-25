// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Builds custom items for a resolved status, or returns `nil` to use defaults.
typealias CarPlayStatusContent<Item> = @MainActor (CarPlayLoadingStatus) -> [Item]?
