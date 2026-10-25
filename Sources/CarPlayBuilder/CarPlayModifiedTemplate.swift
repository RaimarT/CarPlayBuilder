// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A template with rendering or lifecycle modifiers applied to its content.
///
/// Instances are returned by template modifiers. Modifiers preserve the
/// underlying native template kind and compose in call order.
public struct CarPlayModifiedTemplate<Content: CarPlayTemplate>: CarPlayTemplate {

    /// Primitive templates have no compositional body.
    ///
    /// The renderer uses `_resolve()` instead; accessing `body` traps.
    public typealias Body = Never

    let content: Content
    let modify: (inout CarPlayTemplateContent) -> Void

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolve() -> CarPlayTemplateContent {

        var result = self.content._resolve()
        self.modify(&result)

        return result
    }
}

extension CarPlayModifiedTemplate: CarPlayLoadableTemplate
where Content: CarPlayLoadableTemplate {

    /// Preserves the underlying list or grid's status-builder item type.
    public typealias LoadingItem = Content.LoadingItem
}
