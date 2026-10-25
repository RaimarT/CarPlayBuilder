// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A modal presentation, separate from templates in the navigation stack.
@MainActor
public protocol CarPlayModal {

    /// Resolves the modal for validation and native construction.
    ///
    /// Applications normally use `CarPlayAlert` or `CarPlayActionSheet`.
    /// - Returns: Opaque content consumed by the scene host.
    func _resolveModal() -> CarPlayModalContent
}
