// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation

/// Distinguishes explicit IDs from positional fallbacks without collisions.
enum CarPlayContentIdentity: Hashable {

    case explicit(AnyHashable)
    case position(Int)
}
