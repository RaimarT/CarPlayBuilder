// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A native grid screen composed of image buttons.
///
/// Supply one to eight buttons. The host validates content before presentation
/// and preserves button identity using explicit IDs or positions.
public struct CarPlayGrid: CarPlayTemplate {

    /// Primitive templates have no compositional body.
    ///
    /// The renderer uses `_resolve()` instead; accessing `body` traps.
    public typealias Body = Never
    private let title: String?
    private let buttons: () -> [CarPlayButton]

    /// Creates a grid whose buttons are evaluated during each render.
    ///
    /// - Parameters:
    ///   - title: An optional navigation title, updatable while mounted.
    ///   - content: One to eight buttons. Use stable IDs for dynamic collections.
    public init(
        _ title: String? = nil,
        @CarPlayButtonBuilder content: @escaping @MainActor () -> [CarPlayButton]
    ) {

        self.title = title
        self.buttons = content
    }

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolve() -> CarPlayTemplateContent {

        .init(
            kind: .grid(
                self.title,
                self.buttons()
            )
        )
    }
}

extension CarPlayGrid: CarPlayLoadableTemplate {

    /// The native item accepted by custom loading-state builders.
    public typealias LoadingItem = CarPlayButton
}
