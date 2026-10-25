// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Receives the stable ID of a newly selected tab on the main actor.
///
/// Used by `CarPlayTabs.onSelectionChange` for synchronous app state updates.
public typealias CarPlayTabSelectionHandler = @MainActor (AnyHashable) -> Void
