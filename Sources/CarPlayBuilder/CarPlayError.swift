// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A validation, connection, or navigation failure reported by the package.
///
/// Explicit async navigation propagates errors to its caller. Errors from
/// selection actions, lifecycle tasks, and observed updates reach the host’s
/// error handler. Underlying CarPlay errors may also propagate unchanged.
public enum CarPlayError: Error, LocalizedError, Equatable {

    /// The scene is disconnected or its host or interface controller is unavailable.
    case disconnected
    /// Another navigation operation or a modal blocks the requested operation.
    case operationInProgress
    /// The native CarPlay interface declined the requested presentation.
    case presentationRejected
    /// Content violates a supported layout, count, identity, or navigation rule.
    ///
    /// The associated message explains the invalid content.
    case invalidContent(String)

    /// A human-readable description suitable for logging or an error interface.
    public var errorDescription: String? {

        switch self {

        case .disconnected:
            "The CarPlay scene is disconnected."

        case .operationInProgress:
            "A CarPlay navigation operation is already in progress."

        case .presentationRejected:
            "CarPlay rejected the navigation operation."

        case let .invalidContent(reason):
            reason
        }
    }
}
