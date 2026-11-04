# Changelog

Changes follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0]

Adds a runnable sample app demonstrating CarPlayBuilder's existing APIs. The
library's public API and platform requirements are unchanged from 1.0.0.

### Added

- A standalone iOS sample project using a local package reference, with a SwiftUI
  companion interface and shared observable state across iPhone and CarPlay.
- Library and Saved lists, an eight-button Browse grid, stable row identities,
  tab badges, programmatic tab selection, and navigation to track details.
- Deterministic offline demonstrations of loading, empty results, failure and
  retry, and refresh with retained content using screen-owned resources.
- Reactive Save/Unsave toolbar actions, native alerts, and a confirmation sheet
  for clearing saved tracks.
- Locally generated artwork in library rows and native Now Playing, image rows
  on iOS 26+, and a rich list header with a Play action on iOS 26.4+.
- Three bundled, original audio loops with app-owned playback, system media
  metadata, remote commands, and audio interruption handling.
- A sample setup guide covering simulator use, scene registration, entitlements,
  playback ownership, and the implementation of each demo.
- Sample app compilation and Swift formatting checks in CI.

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

[Unreleased]: https://github.com/RaimarT/CarPlayBuilder/compare/1.1.0...HEAD
[1.1.0]: https://github.com/RaimarT/CarPlayBuilder/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/RaimarT/CarPlayBuilder/releases/tag/1.0.0
