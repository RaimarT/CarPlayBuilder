// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Identifies a tab with a title, image, both, or a system-provided label.
@MainActor
public enum CarPlayTabLabel {

    /// A text label. CarPlay supplies no custom tab image.
    case title(String)
    /// A custom image. CarPlay may inherit the root template’s title.
    case image(UIImage)
    /// A text label and custom image.
    case titleAndImage(String, UIImage)
    /// A system-provided title and image, such as favorites or search.
    case system(UITabBarItem.SystemItem)
}
