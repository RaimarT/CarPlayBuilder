// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A collection builder for `CarPlayImageElement` values.
///
/// Accepts individual values, arrays, loops, conditionals, and empty content.
@available(iOS 26.0, *)
public typealias CarPlayImageElementBuilder =
    CarPlayArrayBuilder<CarPlayImageElement>
