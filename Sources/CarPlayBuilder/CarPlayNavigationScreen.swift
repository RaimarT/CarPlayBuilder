// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation

/// An immutable description of a host-owned template at navigation completion.
public struct CarPlayNavigationScreen: Sendable, Equatable, Identifiable {

    /// Stable mounted-template identity, matching error context screen IDs.
    ///
    /// A modal uses its presentation identity. Reconnecting or replacing a screen
    /// creates a new identity; this is not an application route identifier.
    public let id: UUID

    /// Native template category, independent of its title.
    public let kind: Kind

    /// List/grid title, first alert title variant, or action-sheet title.
    ///
    /// Tab containers and Now Playing have no title in this description.
    public let title: String?
}
