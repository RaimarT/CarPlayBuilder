// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Artwork, text, and ordered actions displayed above a list's sections.
///
/// Attach with `CarPlayList.listHeader` on iOS 26.4 or later. This value can be
/// prepared on earlier systems without constructing native header objects.
@MainActor
public struct CarPlayListHeader {

    let title: String?
    let subtitle: String?
    let image: UIImage
    let buttons: [CarPlayListHeaderButton]

    /// Creates a rich list header with optional actions.
    ///
    /// - Parameters:
    ///   - title: Optional primary text, independent of the navigation title.
    ///   - subtitle: Optional supporting text, such as an artist or show name.
    ///   - image: Ready-to-display thumbnail artwork.
    ///   - buttons: Ordered actions within the native maximum action count.
    ///     Use stable IDs for conditional or reordered buttons.
    public init(
        _ title: String? = nil,
        subtitle: String? = nil,
        image: UIImage,
        @CarPlayListHeaderButtonBuilder buttons: ()
            -> [CarPlayListHeaderButton] = { [] }
    ) {

        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.buttons = buttons()
    }
}
