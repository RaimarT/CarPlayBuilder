// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A tab’s stable identity, label, and root screen.
///
/// The root must resolve to a list or grid without navigation bar buttons.
@MainActor
public struct CarPlayTab {

    let id: AnyHashable
    let label: CarPlayTabLabel
    var showsBadge = false
    let content: () -> CarPlayTemplateContent

    /// Creates a labeled tab with a repeatable root description.
    ///
    /// - Parameters:
    ///   - id: A stable value unique within the tab container.
    ///   - label: A title, image, both, or a system tab item.
    ///   - content: A list or grid root without toolbar modifiers.
    public init(
        id: some Hashable,
        label: CarPlayTabLabel,
        content: @escaping @MainActor () -> some CarPlayTemplate
    ) {

        self.id = AnyHashable(id)
        self.label = label
        self.content = {

            content()._resolve()
        }
    }

    /// Shows the native Boolean attention indicator on this tab.
    ///
    /// - Parameter visible: Whether to show the badge; defaults to `true`.
    /// - Returns: A tab with the requested badge visibility.
    public func badge(_ visible: Bool = true) -> Self {

        var copy = self
        copy.showsBadge = visible

        return copy
    }
}
