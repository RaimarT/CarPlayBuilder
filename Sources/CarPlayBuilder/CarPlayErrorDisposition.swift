// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Determines whether a screen has recovered from an error or delegates it.
public enum CarPlayErrorDisposition: Sendable {

    /// Stop propagation because this handler owns recovery.
    case handled
    /// Continue to enclosing handlers and ultimately the host's error handler.
    case unhandled
}
