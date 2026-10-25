// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Scene-scoped navigation passed to row and button actions.
@MainActor
public struct CarPlayContext {

    weak var host: CarPlayHost?

    /// Pushes a lazily constructed destination onto the scene’s stack.
    ///
    /// - Parameters:
    ///   - animated: Whether CarPlay animates the transition.
    ///   - content: The destination description, re-evaluated for observed updates.
    ///     Tab containers cannot be pushed.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func push(
        animated: Bool = true,
        content: @escaping @MainActor () -> some CarPlayTemplate
    ) async throws {

        guard let host else {

            throw CarPlayError.disconnected
        }

        try await host.push(animated: animated, content: content)
    }

    /// Pops the top screen using the native CarPlay navigation operation.
    ///
    /// - Parameter animated: Whether CarPlay animates the transition.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func pop(animated: Bool = true) async throws {

        guard let host else {

            throw CarPlayError.disconnected
        }

        try await host.pop(animated: animated)
    }

    /// Returns to the existing root, doing nothing if already at the root.
    ///
    /// - Parameter animated: Whether CarPlay animates the transition.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func popToRoot(animated: Bool = true) async throws {

        try await self.connectedHost().popToRoot(animated: animated)
    }

    /// Returns to the root and selects the tab with the supplied stable ID.
    ///
    /// - Parameters:
    ///   - id: An ID declared by a tab in the current root container.
    ///   - animated: Whether returning to the root is animated.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func selectTab(id: some Hashable, animated: Bool = true) async throws {

        try await self.connectedHost().selectTab(
            id: AnyHashable(id),
            animated: animated
        )
    }

    /// Replaces the root and navigation stack after CarPlay accepts the change.
    ///
    /// Rejected replacements keep the previous screens and observation active.
    /// An accepted replacement also becomes the root for future reconnections.
    ///
    /// - Parameters:
    ///   - animated: Whether CarPlay animates the replacement.
    ///   - content: The new root description and its observable dependencies.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func replaceRoot(
        animated: Bool = true,
        content: @escaping @MainActor () -> some CarPlayTemplate
    ) async throws {

        try await self.connectedHost().replaceRoot(animated: animated) {

            content()._resolve()
        }
    }

    /// Presents an alert or action sheet outside the navigation stack.
    ///
    /// Only one modal may be active. Other navigation is blocked until it is
    /// dismissed, except for an explicit call to `dismiss`.
    ///
    /// - Parameters:
    ///   - modal: The alert or action sheet to validate and present.
    ///   - animated: Whether CarPlay animates the presentation.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func present(
        _ modal: some CarPlayModal,
        animated: Bool = true
    ) async throws {

        try await self.connectedHost().present(
            modal._resolveModal(),
            animated: animated
        )
    }

    /// Dismisses the current modal, doing nothing if none is presented.
    ///
    /// - Parameter animated: Whether CarPlay animates the dismissal.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func dismiss(animated: Bool = true) async throws {

        try await self.connectedHost().dismiss(animated: animated)
    }

    /// Shows the shared system Now Playing screen.
    ///
    /// The application must supply audio playback and MediaPlayer metadata.
    /// If that shared template is already on the stack, the host returns to it.
    ///
    /// - Parameter animated: Whether CarPlay animates navigation.
    /// - Throws: `CarPlayError` for connection, validation, or navigation conflicts;
    ///   cancellation and native interface errors can also propagate.
    public func showNowPlaying(animated: Bool = true) async throws {

        try await self.push(animated: animated) {

            CarPlayNowPlaying()
        }
    }
}

private extension CarPlayContext {

    func connectedHost() throws -> CarPlayHost {

        guard let host else {

            throw CarPlayError.disconnected
        }

        return host
    }
}
