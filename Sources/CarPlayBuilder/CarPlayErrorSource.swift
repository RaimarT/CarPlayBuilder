// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// The operation that surfaced an error, rather than its underlying cause.
public enum CarPlayErrorSource: Sendable, Equatable {

    /// An asynchronous user selection, including navigation performed by it.
    case action
    /// A visibility-bound task declared with the task modifier.
    case lifecycleTask
    /// An observed update rejected by validation or rendering.
    case rendering
    /// A coordinator-owned navigation request.
    case navigation
}
