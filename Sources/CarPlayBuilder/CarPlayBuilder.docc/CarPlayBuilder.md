# ``CarPlayBuilder``

Compose native CarPlay screens with Swift values and observable application state.

## Overview

CarPlayBuilder targets iOS 17 and later with Swift 6.2 or later. It has no external
dependencies. Your application supplies CarPlay entitlements, a configured scene,
models, networking, audio playback, and media metadata.

Retain one ``CarPlayHost`` per scene and call its `connect(animated:)` method after
CarPlay supplies an interface controller. Disconnect the host when the scene ends.
Compose reusable components by implementing ``CarPlayTemplate/body``. The host
tracks observable state read during evaluation and reconciles native content.

Use stable IDs for dynamic collections. Start visibility-bound work with the
`task(id:priority:_:)` modifier and use ``CarPlayContext`` for async navigation.
Template lifecycle and selection callbacks run on the main actor. Keep template
evaluation free of side effects.

Shared ``CarPlayResource`` loads outlive any individual screen waiting for them;
the resource owner cancels them explicitly. Artwork loads share requests and
cancel the underlying request only when its last consumer leaves, except explicit
store invalidation, which cancels all consumers of the invalidated work.

Read ``CarPlayArtworkStore/state(for:)`` for observable loading and original-error
failure state. Its image lookup supports a separate failure placeholder.
`loadImage(from:)` retries failures; ``CarPlayArtworkStore/reloadImage(from:)``
also refreshes cached images while joining in-flight work. Invalidate one URL or
all images to clear cached/failure state and cancel pending work. Late results
cannot restore invalidated images. Cache eviction returns state to idle on the
next read without a proactive observation notification.

Use `CarPlayArtworkLoader`'s `imageModifier` to process decoded images before the
artwork store caches them. The async throwing hook receives the image and size
hint. Only processed results enter the cache; failures can be retried and
cancelled processing cannot publish an image. Keep one store per processing
configuration, since cache keys remain the original URLs.

Request and image modifiers are sendable async throwing closures invoked off the
main actor. They can await an app-owned actor or explicitly access main-actor
state when needed. Shared captures must be sendable or protected by an actor.
The loader's `imageDecoder` converts data to display-ready artwork off the main
actor after HTTP validation and before image modification. Its default creates a
UIKit image and prepares it for display. Supply a synchronous sendable throwing
decoder for app-owned downsampling or format handling. The cache stores only the
final processed image, and decoder errors remain available to direct callers.

Use the `loadingState` modifier to provide custom status rows for lists or buttons
for grids. Failure builders receive the original error; omitted builders use
``CarPlayLoadingConfiguration`` defaults. Configure loading, empty, and retry
values with ``CarPlayStatusLabel`` pairs; static label factories supply English
titles and SF Symbols. Its failure provider maps the original error to a
``CarPlayErrorPresentation`` containing a label and optional message. Lists show
the title and message; grids show the title and symbol. Reuse the provider for
app-owned error UI without coupling presentation to recovery actions. Set `retainsContentDuringRefresh` to keep
usable current content visible while loading and append recovery content after a
failed refresh. Initial and empty loads still show status content. Retained and
status items together must respect native item and identity limits.

Use ``CarPlayRow/explicitContent(_:)`` to mark explicit content and
``CarPlayRow/playingIndicatorLocation(_:)`` to choose the leading or trailing
Now Playing indicator. Set its visibility and progress with
``CarPlayRow/playback(isPlaying:progress:)``. These modifiers update presentation
without controlling playback or restricting access to content.

Use ``CarPlayTab/badge(_:)`` for a Boolean attention indicator and
``CarPlayTabs/onSelectionChange(_:)`` to observe native or programmatic selection
changes by stable ID. Initial presentation and content updates do not notify;
repeated selection of the same ID is suppressed. Badge visibility stays app-owned.

Use the coordinator's `buttons:` initializer with ``CarPlayNowPlayingButton``
values to compose up to five ordered controls. Stable IDs preserve compatible
native buttons as observable state changes. Custom images support selected and
enabled state; standard controls use the app's playback adapter and media metadata.
Invalid counts and duplicate IDs reach the coordinator's error handler.

Set ``CarPlayNowPlayingConfiguration/upNextTitle`` for a localized queue label.
An optional `albumArtist:` destination makes the native album/artist text tappable
and lazily pushes related content. Destination work cancels on a new destination
tap, reconnection, or disconnect. Disconnect restores the shared template's default
queue label and disables destination controls.

Use ``CarPlayList/emptyView(titleVariants:subtitleVariants:)`` for native empty
text without adding rows. Supply localized variants in preference order. CarPlay
chooses the first that fits and displays the fallback only with zero items.
Loading-state rows take precedence; a custom status builder producing no rows can
leave the fallback visible. Omitting the modifier restores native defaults.

On iOS 26.4 or later, attach ``CarPlayListHeader`` with
``CarPlayList/listHeader(_:)`` to display artwork, text, and ordered
``CarPlayListHeaderButton`` actions above the sections. Header updates preserve
native identity and loading presentation. Stable IDs retain compatible actions;
removed buttons ignore stale taps. Actions share screen cancellation and errors.

Attach ``CarPlayTemplate/onError(_:)`` for per-screen recovery. Return
``CarPlayErrorDisposition/handled`` to stop propagation or
``CarPlayErrorDisposition/unhandled`` to continue through enclosing handlers and
the host. Selection and lifecycle errors use the latest accepted handlers;
rejected observed renders use the mounted root's last accepted handlers.
Use ``CarPlayTemplate/onErrorWithContext(_:)`` for origin-aware recovery.
``CarPlayErrorContext`` identifies the operation, mounted screen, selected control,
and lifecycle task ID where available. Child errors retain their original context
through tab-container recovery. Host and Now Playing initializers also accept
`onErrorWithContext`, replacing their legacy callback when supplied.
Normal cancellation stays silent. Explicit navigation and initial mounting errors
still throw to the caller. Modal and Now Playing actions retain their own routing.

On iOS 18.4 or later, ``CarPlayList/showsSpinnerWhileEmpty(_:)`` adds a native
activity indicator alongside empty-view text when the list has zero items.
Pass app-owned loading state to control it. Loading-state rows suppress the native
empty view; an empty custom loading builder leaves the spinner available.

Use ``CarPlayRepeatedActionPolicy/ignoreWhileRunning`` with a control's
`repeatedActionPolicy(_:)` modifier to suppress repeat selections and temporarily
disable the native control. ``CarPlayRepeatedActionPolicy/allowConcurrent`` is the
default. Stable IDs preserve busy state through updates; finishing work respects
app-owned disabled state. Ignored list callbacks still complete. Policy enforcement
shares the control's normal cancellation and error-recovery behavior.

See the repository README for complete scene setup and composition samples.

### Define a reusable screen

Keep the screen description separate from the scene-owned host. This screen can
be returned from the host's root closure or a navigation destination:

```swift
import CarPlayBuilder

@MainActor
struct WelcomeScreen: CarPlayTemplate {
    var body: some CarPlayTemplate {
        CarPlayList("Welcome") {
            CarPlaySection {
                CarPlayRow("Connected to CarPlay").disabled()
            }
        }
    }
}
```

For dynamic content, read an app-owned observable model in the builder and assign
stable IDs to its rows and sections. The host preserves native identities across
valid updates. A mounted list's title and a mounted screen's template kind cannot
change; navigate to a new screen or replace the root to change either.

Pass `onNavigation` to ``CarPlayHost`` to observe accepted stack and modal changes,
including native Back navigation. ``CarPlayNavigationEvent`` carries the operation,
origin, animation flag, and before/after snapshots. Screen IDs match contextual
error reporting. Delivery follows navigation-gate release; failed requests,
no-ops, and duplicate native notifications are suppressed. Tab selection retains
its separate callback. Snapshots hold sendable values, not native templates.

## Topics

### Scene ownership and navigation

- ``CarPlayHost``
- ``CarPlayContext``
- ``CarPlayNavigationEvent``
- ``CarPlayNavigationHandler``
- ``CarPlayNavigationKind``
- ``CarPlayNavigationOrigin``
- ``CarPlayNavigationState``
- ``CarPlayNavigationScreen``
- ``CarPlayError``
- ``CarPlayErrorDisposition``

### Templates and composition

- ``CarPlayTemplate``
- ``CarPlayList``
- ``CarPlayGrid``
- ``CarPlayTabs``
- ``CarPlayTab``
- ``CarPlayTabLabel``
- ``AnyCarPlayTemplate``
- ``CarPlayModifiedTemplate``
- ``CarPlayTemplateBuilder``
- ``CarPlayArrayBuilder``

### Rows, buttons, and artwork layouts

- ``CarPlayListHeader``
- ``CarPlayListHeaderButton``
- ``CarPlaySection``
- ``CarPlaySectionHeaderButton``
- ``CarPlayRow``
- ``CarPlayRepeatedActionPolicy``
- ``CarPlayNavigationLink(_:detail:image:destination:)``
- ``CarPlayButton``
- ``CarPlayBarButton``
- ``CarPlayImageRow``
- ``CarPlayImageElement``

### Modal presentations

- ``CarPlayModal``
- ``CarPlayAlert``
- ``CarPlayActionSheet``
- ``CarPlayAlertAction``

### Loading and artwork

- ``CarPlayResource``
- ``CarPlayLoadState``
- ``CarPlayLoadableTemplate``
- ``CarPlayLoadingConfiguration``
- ``CarPlayErrorPresentation``
- ``CarPlayErrorPresentationProvider``
- ``CarPlayStatusLabel``
- ``CarPlayArtworkStore``
- ``CarPlayArtworkLoading``
- ``CarPlayArtworkLoader``

### Now Playing integration

- ``CarPlayNowPlaying``
- ``CarPlayNowPlayingCoordinator``
- ``CarPlayNowPlayingPlayback``
- ``CarPlayNowPlayingConfiguration``
- ``CarPlayNowPlayingButton``

### Collection builders

- ``CarPlaySectionBuilder``
- ``CarPlayRowBuilder``
- ``CarPlayButtonBuilder``
- ``CarPlayTabBuilder``
- ``CarPlayBarButtonBuilder``
- ``CarPlayListHeaderButtonBuilder``
- ``CarPlayNowPlayingButtonBuilder``
- ``CarPlayAlertActionBuilder``
- ``CarPlayImageElementBuilder``

### Rendering implementation boundaries

- ``CarPlayTemplateContent``
- ``CarPlayModalContent``

### Shared closure types

- ``CarPlayAction``
- ``CarPlayTaskAction``
- ``CarPlayCallback``
- ``CarPlayErrorHandler``
- ``CarPlayErrorRecovery``
- ``CarPlayErrorContext``
- ``CarPlayErrorSource``
- ``CarPlayErrorControl``
- ``CarPlayContextualErrorHandler``
- ``CarPlayContextualErrorRecovery``
- ``CarPlayTabSelectionHandler``
- ``CarPlayLoadingContent``
- ``CarPlayFailureContent``
