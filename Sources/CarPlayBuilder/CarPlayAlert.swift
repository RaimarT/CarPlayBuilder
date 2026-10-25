// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A modal alert with title variants and asynchronous actions.
///
/// Present an alert using the scene context, rather than pushing it onto the
/// navigation stack. Actions dismiss the alert before their callbacks run.
@MainActor
public struct CarPlayAlert: CarPlayModal {

    private let titles: [String]
    private let actions: [CarPlayAlertAction]

    /// Creates an alert with a single nonempty title.
    ///
    /// - Parameters:
    ///   - title: The alert heading.
    ///   - actions: At least one titled action, at most one with cancel style.
    ///     The count must respect `CPAlertTemplate.maximumActionCount`.
    public init(
        _ title: String,
        @CarPlayAlertActionBuilder actions: () -> [CarPlayAlertAction]
    ) {

        self.titles = [title]
        self.actions = actions()
    }

    /// Creates an alert with headings for different screen sizes.
    ///
    /// - Parameters:
    ///   - titleVariants: Nonempty titles ordered from longest to shortest.
    ///   - actions: Titled actions within the native alert limit, with at most
    ///     one cancel action.
    public init(
        titleVariants: [String],
        @CarPlayAlertActionBuilder actions: () -> [CarPlayAlertAction]
    ) {

        self.titles = titleVariants
        self.actions = actions()
    }

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolveModal() -> CarPlayModalContent {

        CarPlayModalContent(
            kind: .alert(self.titles),
            actions: self.actions
        )
    }
}
