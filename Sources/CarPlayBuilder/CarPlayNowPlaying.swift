// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Uses the system Now Playing screen; the application owns playback and MediaPlayer
/// metadata.
public struct CarPlayNowPlaying: CarPlayTemplate {

    /// Primitive templates have no compositional body.
    ///
    /// The renderer uses `_resolve()` instead; accessing `body` traps.
    public typealias Body = Never
    /// Creates a value referring to the shared native Now Playing template.
    ///
    /// Use the scene context to show it. The package does not start audio playback.
    public init() {}

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolve() -> CarPlayTemplateContent {

        .init(kind: .nowPlaying)
    }
}
