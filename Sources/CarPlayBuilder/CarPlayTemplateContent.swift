// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// The opaque resolved representation of a declarative template tree.
///
/// Applications compose templates through `body`. The renderer consumes this
/// representation to validate, create, and update native CarPlay objects.
@MainActor
public struct CarPlayTemplateContent {

    var kind: Kind
    var listHeader: CarPlayListHeader?
    var emptyViewTitleVariants: [String]?
    var emptyViewSubtitleVariants: [String]?
    var emptyViewSpinner: Bool?
    var tabSelectionHandler: CarPlayTabSelectionHandler?
    var leadingButtons: [CarPlayBarButton] = []
    var trailingButtons: [CarPlayBarButton] = []
    var errorHandlers: [CarPlayContextualErrorRecovery] = []
    var tasks: [LifecycleTask] = []
    var appear: [CarPlayCallback] = []
    var disappear: [CarPlayCallback] = []
}
