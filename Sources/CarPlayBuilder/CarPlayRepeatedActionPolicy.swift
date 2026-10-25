// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Controls selection while previous invocations of the same control are running.
public enum CarPlayRepeatedActionPolicy: Sendable {

    /// Every enabled selection starts work. This is the default.
    case allowConcurrent
    /// Ignore further selections and disable the control until its work finishes.
    case ignoreWhileRunning
}
