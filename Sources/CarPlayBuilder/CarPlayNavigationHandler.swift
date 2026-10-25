// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Observes settled navigation changes on the main actor.
///
/// The navigation gate is released before delivery. Update app state or schedule
/// asynchronous navigation here; keep the synchronous callback inexpensive.
public typealias CarPlayNavigationHandler = @MainActor (CarPlayNavigationEvent) -> Void
