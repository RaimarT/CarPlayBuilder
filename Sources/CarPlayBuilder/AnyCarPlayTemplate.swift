// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A type-erased template for storing screens with different concrete types.
///
/// Use this wrapper when a property or conditional composition needs a single
/// concrete type. Resolving the wrapper preserves the wrapped screen’s behavior.
public struct AnyCarPlayTemplate: CarPlayTemplate {

    /// Primitive templates have no compositional body.
    ///
    /// The renderer uses `_resolve()` instead; accessing `body` traps.
    public typealias Body = Never
    private let resolve: CarPlayContentProvider

    /// Wraps a template while retaining its resolution behavior.
    ///
    /// - Parameter content: The screen value to erase. Observable state read
    ///   while resolving it remains part of the host’s dependency tracking.
    public init(_ content: some CarPlayTemplate) {

        self.resolve = content._resolve
    }

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolve() -> CarPlayTemplateContent {

        self.resolve()
    }
}
