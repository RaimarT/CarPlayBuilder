// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Type erasure lets iOS 17 list rows coexist with iOS 26 image rows.
@MainActor
struct CarPlayImageRowContent {

    let layout: AnyHashable
    let elementIDs: [AnyHashable]
    let actions: [CarPlayAction?]
    let identities: [AnyHashable?]
    let policies: [CarPlayRepeatedActionPolicy]
    let make: @MainActor () -> CPListImageRowItem
    let update: @MainActor (CPListImageRowItem) -> Void
}
