// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Maps an original error to user-facing text and artwork without handling it.
///
/// Loading presentation invokes this synchronous closure on the main actor.
/// Keep mapping inexpensive and capture only sendable state. The closure itself
/// is not actor-isolated, so apps can also reuse it outside rendering.
public typealias CarPlayErrorPresentationProvider = @Sendable (any Error)
    -> CarPlayErrorPresentation
