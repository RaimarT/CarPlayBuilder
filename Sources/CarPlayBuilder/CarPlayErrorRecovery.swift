// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Handles an error synchronously on the main actor using the scene context.
///
/// Return `.handled` after arranging recovery, or `.unhandled` to propagate.
/// Update observable app state here; asynchronous recovery can run through the
/// screen's tasks or subsequent actions.
public typealias CarPlayErrorRecovery = @MainActor (any Error, CarPlayContext)
    -> CarPlayErrorDisposition
