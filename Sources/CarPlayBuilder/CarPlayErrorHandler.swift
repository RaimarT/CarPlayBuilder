// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Receives unhandled rendering, selection, and lifecycle errors on the main actor.
public typealias CarPlayErrorHandler = @MainActor (any Error) -> Void
