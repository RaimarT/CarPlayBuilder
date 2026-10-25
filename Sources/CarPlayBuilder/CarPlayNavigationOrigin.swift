// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Distinguishes host operations from changes observed through native delegates.
public enum CarPlayNavigationOrigin: Sendable, Equatable {

    /// A host or context operation, including scene connection and disconnection.
    case programmatic
    /// A completed native change, such as the driver pressing Back.
    case native
}
