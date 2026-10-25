// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A root tab container whose children are list or grid screens.
///
/// Tabs require unique, stable IDs. Nested tab containers and pushed tab
/// containers are rejected by the host.
public struct CarPlayTabs: CarPlayTemplate {

    /// Primitive templates have no compositional body.
    ///
    /// The renderer uses `_resolve()` instead; accessing `body` traps.
    public typealias Body = Never
    private var selectionHandler: CarPlayTabSelectionHandler?
    private let tabs: () -> [CarPlayTab]

    /// Creates the scene’s root tab container.
    ///
    /// - Parameter content: Tabs with unique IDs, evaluated on every render.
    ///   The count must respect `CPTabBarTemplate.maximumTabCount`.
    public init(
        @CarPlayTabBuilder content: @escaping @MainActor () -> [CarPlayTab]
    ) {

        self.tabs = content
    }

    /// Observes changes to the selected tab's stable ID.
    ///
    /// Called synchronously on the main actor for native selections and successful
    /// `CarPlayContext.selectTab` requests. Initial mounting, content updates, and
    /// reselecting the same ID do not invoke the callback. Removing the selected
    /// tab establishes a new baseline without invoking it. The latest modifier
    /// replaces any previously supplied callback.
    ///
    /// - Parameter action: App state or analytics work for the selected tab ID.
    /// - Returns: A container with the selection callback.
    public func onSelectionChange(
        _ action: @escaping CarPlayTabSelectionHandler
    ) -> Self {

        var copy = self
        copy.selectionHandler = action

        return copy
    }

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolve() -> CarPlayTemplateContent {

        var content = CarPlayTemplateContent(
            kind: .tabs(
                self.tabs().map {

                    .init(
                        id: $0.id,
                        label: $0.label,
                        showsBadge: $0.showsBadge,
                        content: $0.content()
                    )
                }
            )
        )
        content.tabSelectionHandler = self.selectionHandler

        return content
    }
}
