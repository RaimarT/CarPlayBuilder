// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// The native modal variant and its presentation text.
@MainActor
enum CarPlayModalKind {

    case alert([String])
    case actionSheet(String?, String?)
}
