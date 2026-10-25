// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Recovers using the original error, its origin, and the current scene context.
///
/// Return `.handled` to stop propagation or `.unhandled` to continue. Parent tab
/// handlers receive the originating child's metadata, not the parent's identity.
public typealias CarPlayContextualErrorRecovery = @MainActor (
    any Error,
    CarPlayErrorContext,
    CarPlayContext
) -> CarPlayErrorDisposition
