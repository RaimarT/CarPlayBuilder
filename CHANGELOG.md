# Changelog

Changes follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0]

First stable release of CarPlayBuilder, a standalone Swift package under the MIT
license with no external dependencies.

### Added

- Declarative lists, grids, tabs, alerts, and action sheets using Swift value
  types, result builders, stable identities, and observable application state.
- Scene integration, navigation, lifecycle tasks, cancellation, and navigation
  events with before/after snapshots and native or programmatic origins.
- Contextual error handling and screen-level recovery, preserving original
  errors and identifying the originating screen, control, or lifecycle task.
- Customizable loading, empty, failure, and retry presentations, including typed
  content builders and content retention during refresh.
- Artwork loading with caching, observable per-URL state, refresh, invalidation,
  concurrency limits, and customizable request, decoder, and image closures.
  Default decoding and display preparation run off the main actor.
- Now Playing controls, Up Next and album/artist destinations, tab badges and
  selection callbacks, section actions, row metadata, and selection policies.
- Native empty-list presentation and spinner, image layouts on iOS 26+, and rich
  list headers on iOS 26.4+.
- Public API documentation, a DocC catalog, README integration samples, Swift
  Testing coverage, and CI for formatting, simulator tests, and documentation.

### Requirements

- iOS 17 or later; newer native features require their respective OS versions.
- Swift 6.2 or later and an Xcode installation with the iOS 26.4 SDK or later.
  CI validates Xcode 26.6.
- A host app with the appropriate CarPlay entitlement and scene configuration.

[Unreleased]: https://github.com/RaimarT/CarPlayBuilder/compare/1.0.0...HEAD
[1.0.0]: https://github.com/RaimarT/CarPlayBuilder/releases/tag/1.0.0
