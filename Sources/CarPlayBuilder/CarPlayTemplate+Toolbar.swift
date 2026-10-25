// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

public extension CarPlayTemplate {

    /// Sets up to two leading navigation bar buttons on a list or grid.
    ///
    /// The host rejects toolbars on tab roots, tab containers, and Now Playing.
    /// Use a pushed list or grid for contextual toolbar actions.
    ///
    /// - Parameter content: Buttons evaluated when the modifier is applied.
    /// - Returns: A template with the supplied leading buttons.
    func leadingBarButtons(
        @CarPlayBarButtonBuilder _ content: () -> [CarPlayBarButton]
    ) -> CarPlayModifiedTemplate<Self> {

        let buttons = content()

        return CarPlayModifiedTemplate(content: self) {

            $0.leadingButtons = buttons
        }
    }

    /// Sets up to two trailing navigation bar buttons on a list or grid.
    ///
    /// The host rejects toolbars on tab roots, tab containers, and Now Playing.
    /// Use a pushed list or grid for contextual toolbar actions.
    ///
    /// - Parameter content: Buttons evaluated when the modifier is applied.
    /// - Returns: A template with the supplied trailing buttons.
    func trailingBarButtons(
        @CarPlayBarButtonBuilder _ content: () -> [CarPlayBarButton]
    ) -> CarPlayModifiedTemplate<Self> {

        let buttons = content()

        return CarPlayModifiedTemplate(content: self) {

            $0.trailingButtons = buttons
        }
    }
}
