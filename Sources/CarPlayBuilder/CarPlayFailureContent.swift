// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A main-actor builder for custom items using the original loading error.
///
/// Return `nil` to use the default presentation, or an empty array to show no items.
public typealias CarPlayFailureContent<Item> = @MainActor (any Error) -> [Item]?
