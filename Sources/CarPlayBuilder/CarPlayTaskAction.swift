// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Asynchronous main-actor work for lifecycle tasks and retry actions.
public typealias CarPlayTaskAction = @MainActor () async throws -> Void
