// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A title and SF Symbol name describing a status or recovery action.
///
/// Default list status rows use the title; grid buttons use both values.
/// Supply localized titles from the app. Use custom status builders to provide
/// list artwork or presentation beyond this label.
public struct CarPlayStatusLabel: Sendable, Equatable {

    /// Localizable text displayed by the status row or button.
    public var title: String

    /// The SF Symbol used by default grid presentation.
    ///
    /// An unavailable symbol falls back to an empty image, as with other default
    /// grid status artwork.
    public var systemImage: String

    /// Creates a status label without resolving its image or localizing its title.
    ///
    /// - Parameters:
    ///   - title: App-provided text for the status or recovery action.
    ///   - systemImage: An SF Symbol name resolved when rendering a grid.
    public init(title: String, systemImage: String) {

        self.title = title
        self.systemImage = systemImage
    }
}
