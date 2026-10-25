// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A modal choice of actions with an optional title and message.
///
/// Present the sheet through the scene context. At least one titled action is
/// required, with at most one cancel action.
@MainActor
public struct CarPlayActionSheet: CarPlayModal {

    private let title: String?
    private let message: String?
    private let actions: [CarPlayAlertAction]

    /// Creates an action sheet with an optional heading and explanation.
    ///
    /// - Parameters:
    ///   - title: The heading, or `nil` to omit it.
    ///   - message: Supporting text, or `nil` to omit it.
    ///   - actions: At least one titled action and at most one cancel action.
    public init(
        _ title: String? = nil,
        message: String? = nil,
        @CarPlayAlertActionBuilder actions: () -> [CarPlayAlertAction]
    ) {

        self.title = title
        self.message = message
        self.actions = actions()
    }

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolveModal() -> CarPlayModalContent {

        CarPlayModalContent(
            kind: .actionSheet(self.title, self.message),
            actions: self.actions
        )
    }
}
