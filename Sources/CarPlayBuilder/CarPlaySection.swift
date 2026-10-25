// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A group of rows with an optional header inside a list.
///
/// Use a stable ID when sections may be inserted, removed, or reordered.
@MainActor
public struct CarPlaySection {

    var identity: AnyHashable?
    let header: String?
    let subtitle: String?
    let image: UIImage?
    let button: CarPlaySectionHeaderButton?
    let sectionIndexTitle: String?
    let rows: [CarPlayRow]

    /// Creates a list section by immediately evaluating its row builder.
    ///
    /// - Parameters:
    ///   - header: An optional section heading.
    ///   - subtitle: Supporting header text. Requires a header title.
    ///   - image: Ready-to-display header artwork. Requires a header title.
    ///     Size it for `CPMaximumListSectionImageSize` and the car display scale.
    ///   - button: An optional header action. Requires a header title.
    ///   - sectionIndexTitle: An optional index label. CarPlay displays only its
    ///     first character.
    ///   - content: Rows to display in order, including conditional or loop content.
    public init(
        _ header: String? = nil,
        subtitle: String? = nil,
        image: UIImage? = nil,
        button: CarPlaySectionHeaderButton? = nil,
        sectionIndexTitle: String? = nil,
        @CarPlayRowBuilder content: () -> [CarPlayRow]
    ) {

        self.header = header
        self.subtitle = subtitle
        self.image = image
        self.button = button
        self.sectionIndexTitle = sectionIndexTitle
        self.rows = content()
    }

    /// Assigns a stable identity to this section.
    ///
    /// Use IDs that remain the same across updates and reordering. Without an
    /// explicit ID, the renderer uses the item’s position.
    ///
    /// - Parameter id: A hashable value unique among siblings.
    /// - Returns: A copy carrying the supplied identity.
    public func id(_ id: some Hashable) -> Self {

        var copy = self
        copy.identity = AnyHashable(id)

        return copy
    }
}
