# Changelog

## [Unreleased]

- Add GitHub Actions checks for pinned SwiftFormat lint, iOS simulator tests,
  and DocC warnings as errors, with downloadable test/documentation artifacts
  and shared local CI scripts. Normalize existing formatting for the lint check.

- Give navigation operations independent ownership IDs so reentrant callbacks
  cannot release newer work's navigation gate during deferred cleanup.
- Preserve reentrantly acquired Now Playing ownership during teardown, including
  native property observers and button cancellation; detach old controls first.

- Expose observable per-URL artwork state with original errors and separate
  failure placeholders. Add shared refresh, single/all-image invalidation, and
  protection against stale completions while preserving concurrency limits.
- Review expanded public APIs, preserve image-lookup method references, clarify
  cache eviction and callback defaults, and align public error closure spelling.

- Observe completed host navigation with immutable before/after stack and modal
  snapshots, stable screen IDs, native/programmatic origin, and deduplication of
  delegate callbacks. Include connection, disconnection, and modal action dismissal.

- Add contextual error handlers and screen recovery with operation source,
  originating mounted-screen identity/title, control IDs, and lifecycle task IDs.
  Preserve original errors, child-tab origin, legacy callbacks, and cancellation.

- Map loading failures to reusable `CarPlayErrorPresentation` values containing
  an error-specific title, symbol, and optional message. Replace the fixed failure
  label and `failureMessage` with a single `failure` provider; custom builders
  retain the original error and bypass default mapping.

- Split mounted-template reconciliation into list, row, grid, tab, and toolbar
  components, preserving screen-owned lifecycle and error routing.

- Make mounted-screen cancellation terminal, including teardown during appearance.
- Re-resolve tab selections after awaited root navigation to reject removed tabs.
- Give shared Now Playing controls one active coordinator, cancelling superseded
  work and preserving newer controls when an older coordinator disconnects.

- Add opt-in ignore-while-running selection policies with temporary native
  disabling, stable busy identity, duplicate completion, and app-state preservation.

- Add the iOS 18.4 native empty-list spinner with state updates, native-default
  restoration, and preservation through loading presentation.

- Add per-screen error recovery with explicit handled/unhandled propagation,
  current-handler routing for running work, and tab-container/host fallback.

- Add iOS 26.4 rich list headers with artwork, title, subtitle, and ordered actions,
  preserving native identity and screen-owned cancellation and error handling.

- Configure native list empty-view title/subtitle variants, with in-place updates,
  native-default restoration, and preservation through loading presentation.

- Compose ordered Now Playing buttons with standard controls, custom images,
  stable IDs, observed enabled/selected state, and scene-owned actions.
- Add a custom Up Next title and lazy album/artist destinations, with shared
  navigation cancellation and cleanup of native labels and destination controls.

- Add Boolean tab badges and stable-ID selection-change callbacks for native and
  programmatic selection, suppressing duplicates and invalidating stale delegates.

- Add row explicit-content indicators and configurable leading/trailing Now
  Playing indicators, with in-place updates that preserve artwork and progress.

- Add section header subtitles, artwork, index titles, and titled actions with
  enabled state, stable button identity, and screen-owned selection work.

- Share generic closure aliases for loading, empty, failure, and internal status
  content builders across list and grid presentations.

- Name shared closure signatures for selection actions, tasks, callbacks,
  error handlers, and internal content providers while preserving actor isolation.

- Group each loading, failure, empty, and retry title/symbol pair in
  `CarPlayStatusLabel`, with static defaults and label-based loading configuration.

- Add typed list/grid builders for loading, empty, and failure states with
  original-error recovery, refresh-content retention, and preserved lifecycle work.
- Customize default grid status symbols and list failure-message mapping.

- Expose a sendable `Data`-to-`UIImage` decoder closure with default UIKit decoding
  and display preparation, replacing the internal decoding test hooks.
- Replace required tab titles and images with `CarPlayTabLabel`, supporting
  title-only, image-only, combined, and system labels.

- Verify image creation and display preparation execute off the main thread when
  artwork loading starts on the main actor.

- Decode and prepare downloaded artwork for display off the main actor before
  image modification and caching, preventing deferred first-display decoding.
- Run sendable request and image modifiers off the main actor, allowing
  nonisolated processing and explicit actor hops for shared state.
- Add an async throwing artwork image modifier after decoding and before caching,
  with cancellation checks and retry support for processing failures.
- Document the public API with DocC comments and a package overview catalog.
- Add type-checked README samples for scene setup, navigation, loading, artwork,
  modal actions, and Now Playing integration.
- Publish the standalone `CarPlayBuilder` Swift package for iOS 17+ and Swift 6.2+.
- Provide declarative screens, result builders, observed state, and navigation.
- Include artwork loading, loading and failure states, and Now Playing controls.
- Include iOS simulator unit tests using Swift Testing.
- Use SPDX headers and the MIT license crediting Raimar Tasche.
