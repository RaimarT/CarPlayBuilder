// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A main-actor builder for custom loading or empty-state items.
///
/// Return `nil` to use the default presentation, or an empty array to show no items.
public typealias CarPlayLoadingContent<Item> = @MainActor () -> [Item]?
