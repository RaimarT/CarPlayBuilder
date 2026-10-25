// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A synchronous main-actor callback for lifecycle events and completion.
public typealias CarPlayCallback = @MainActor () -> Void
