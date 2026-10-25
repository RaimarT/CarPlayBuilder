// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Asynchronous selection work using the owning scene’s navigation context.
public typealias CarPlayAction = @MainActor (CarPlayContext) async throws -> Void
