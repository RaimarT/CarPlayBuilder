// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Receives the original error and its originating operation on the main actor.
///
/// Used by host and Now Playing `onErrorWithContext` callbacks. When supplied,
/// this callback replaces the corresponding legacy error-only callback.
public typealias CarPlayContextualErrorHandler = @MainActor (
    any Error,
    CarPlayErrorContext
) -> Void
