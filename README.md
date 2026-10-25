# CarPlayBuilder

Build native CarPlay interfaces with Swift value types, result builders, and
observable application state. Compose lists, grids, tabs, alerts, artwork rows,
and Now Playing controls without managing native template updates yourself.

CarPlayBuilder is a Swift package with no external dependencies. Your app owns
its models, networking, audio player, queue, and MediaPlayer metadata.

## Requirements

- iOS 17 or later.
- Swift 6.2 or later and an Xcode version supporting that toolchain.
- An app configured for CarPlay with the appropriate entitlement and scene.
- iOS 26 or later for `CarPlayImageRow` and `CarPlayImageElement` layouts.

The package does not grant CarPlay access or configure your app’s capabilities.
See Apple’s [CarPlay entitlement guidance](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
and [scene integration documentation](https://developer.apple.com/documentation/carplay/cptemplateapplicationscene).

## Installation

In Xcode, choose **File → Add Package Dependencies** and enter:

```text
https://github.com/RaimarT/CarPlayBuilder.git
```

Add the **CarPlayBuilder** library product to your app target. Until a versioned
release is available, select the `main` branch. Prefer a release version for
production dependencies once tags are published.

For a Swift package consumer, add this dependency to its `Package.swift`:

```swift
.package(
    url: "https://github.com/RaimarT/CarPlayBuilder.git",
    branch: "main"
)
```

Then add the product to the consuming target’s dependencies:

```swift
.product(name: "CarPlayBuilder", package: "CarPlayBuilder")
```

Import `CarPlayBuilder` in source files using the API. Import `CarPlay` or `UIKit`
when referring directly to types from those frameworks.

## Quick start

This complete screen uses an observable model and stable row identities.
Selecting a row pushes a detail screen. Keep both types in your app; the library
has no dependency on your domain models.

```swift
import CarPlayBuilder
import Observation

@MainActor
@Observable
final class LibraryModel {
    var titles = ["Morning briefing", "Latest news"]
}

@MainActor
struct LibraryScreen: CarPlayTemplate {
    let model: LibraryModel

    var body: some CarPlayTemplate {
        CarPlayList("Library") {
            CarPlaySection("Episodes") {
                for title in model.titles {
                    CarPlayNavigationLink(title) {
                        CarPlayList(title) {
                            CarPlaySection {
                                CarPlayRow("Episode details").disabled()
                            }
                        }
                    }
                    .id(title)
                }
            }
            .id("episodes")
        }
    }
}
```

The sample uses unique, fixed titles as IDs. In a real app, use persistent model
IDs so title changes or duplicate labels do not change an item’s identity.

The host tracks observable properties read while evaluating the root and its
content closures. Mutating those properties on the main actor updates native
content. Keep `body` and builders free of side effects; put asynchronous work in
`.task` or selection actions.

## Connect a CarPlay scene

Configure your app’s CarPlay scene to use a delegate such as the following.
This sample uses `LibraryModel` and `LibraryScreen` from the quick start.

```swift
import CarPlay
import CarPlayBuilder
import Foundation

@MainActor
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private let model = LibraryModel()
    private var host: CarPlayHost?
    private var connectionTask: Task<Void, Never>?

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        connectionTask?.cancel()
        host?.disconnect()

        let model = model
        let host = CarPlayHost(
            interfaceController: interfaceController,
            onError: { error in
                NSLog("CarPlay: %@", error.localizedDescription)
            }
        ) {
            LibraryScreen(model: model)
        }
        self.host = host
        connectionTask = Task { @MainActor in
            do {
                try await host.connect()
            } catch {
                guard !Task.isCancelled else { return }
                NSLog("CarPlay connection: %@", error.localizedDescription)
            }
        }
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        connectionTask?.cancel()
        connectionTask = nil
        host?.disconnect()
        host = nil
    }
}
```

Own one host per scene. It retains screens and selection work but holds the
interface controller weakly. It uses the controller’s delegate to observe native
visibility and Back navigation. Always call `disconnect()` during scene teardown.

Errors thrown by `connect()` or explicit context navigation belong to the caller.
Errors from selection actions, lifecycle tasks, and observed updates first try
screen recovery handlers, then reach the host's `onError` if unhandled. Normal
cancellation of screen-owned work is not reported there.

## Navigation, tabs, and grids

Selection actions receive a scene-scoped `CarPlayContext`. Await operations in
sequence: the host rejects overlapping navigation and blocks stack changes while
a modal is presented.

| Operation | Behavior |
| --- | --- |
| `push { ... }` | Lazily creates a destination and retains it until removed. |
| `pop()` | Requests native Back navigation. |
| `popToRoot()` | Returns to the root; already at root is a no-op. |
| `selectTab(id:)` | Returns to a tabbed root and selects its stable ID. |
| `replaceRoot { ... }` | Replaces the root and stack after native acceptance. |
| `showNowPlaying()` | Shows the shared system screen; your app supplies audio. |
| `present(...)` / `dismiss()` | Presents or dismisses a modal outside the stack. |

A disconnected context throws `CarPlayError.disconnected`. Invalid content,
conflicting operations, and native rejection use the other `CarPlayError` cases;
underlying native errors and cancellation can also propagate.

Tabs require a `CarPlayTabLabel`: `.title`, `.image`, `.titleAndImage`, or
`.system`. Image-only labels may inherit the root template’s title.

This reusable root combines a list with a grid. The image uses an optional
SF Symbol lookup with a fallback, avoiding a forced unwrap.

```swift
import CarPlayBuilder
import UIKit

@MainActor
struct AppRoot: CarPlayTemplate {
    let model: LibraryModel

    var body: some CarPlayTemplate {
        CarPlayTabs {
            CarPlayTab(
                id: "library",
                label: .titleAndImage(
                    "Library",
                    UIImage(systemName: "books.vertical") ?? UIImage()
                )
            ) {
                LibraryScreen(model: model)
            }
            CarPlayTab(
                id: "browse",
                label: .system(.search)
            ) {
                CarPlayGrid("Browse") {
                    CarPlayButton(
                        "Library",
                        image: UIImage(systemName: "books.vertical") ?? UIImage()
                    ) { context in
                        try await context.selectTab(id: "library")
                    }
                    .id("open-library")
                }
            }
        }
    }
}
```

Tab containers must be roots, with unique IDs and list or grid children. A grid
requires one to eight buttons. List and tab counts follow native CarPlay limits.
The app’s entitlement still determines which templates CarPlay permits.

A mounted screen keeps its template kind, and a mounted list keeps its title.
Push or replace a screen to change either. Rejected root replacements retain the
previous screens; successful replacements also become the root on reconnection.
For iOS 18 audio-app compatibility, keep grid screens at tab roots.

## Tab badges and selection changes

Use `.badge()` on a `CarPlayTab` to show the native attention indicator, or
`.badge(false)` to hide it. The badge is Boolean and has no count or custom text.
Its visibility can follow observable app state.

Attach `.onSelectionChange` to `CarPlayTabs` to receive the newly selected tab's
stable ID as `AnyHashable`. The callback runs synchronously on the main actor for
native tab selections and successful `context.selectTab(id:)` requests. It fires
once per ID change. Initial mounting, reselecting the same ID, and content updates
stay silent. Removing the selected tab silently establishes a new baseline.

```swift
import CarPlayBuilder

@MainActor
func makeBadgedTabs(
    hasNewEpisodes: Bool,
    selectionChanged: @escaping CarPlayTabSelectionHandler
) -> CarPlayTabs {
    CarPlayTabs {
        CarPlayTab(id: "library", label: .title("Library")) {
            CarPlayList("Library") {}
        }
        CarPlayTab(id: "new", label: .title("New episodes")) {
            CarPlayList("New episodes") {}
        }
        .badge(hasNewEpisodes)
    }
    .onSelectionChange(selectionChanged)
}
```

Use the callback for selection state, restoration bookkeeping, or analytics.
Assign stable IDs to preserve badges and selection identity through reordering.
The callback uses the latest rendered closure and stops when its root is removed
or the scene disconnects. Badges remain app-owned state; selecting a tab does not
automatically clear them.

## Rich list headers

On iOS 26.4 or later, use `.listHeader(...)` for a prominent artwork, title,
subtitle, and action area above all sections. It is independent of the navigation
title and individual section headers.

```swift
import CarPlayBuilder
import UIKit

@MainActor
func makeAlbum(artwork: UIImage, play: @escaping CarPlayAction) -> CarPlayList {
    let list = CarPlayList("Album") {
        CarPlaySection {
            CarPlayRow("First track").disabled()
        }
    }
    if #available(iOS 26.4, *) {
        let header = CarPlayListHeader(
            "Album title",
            subtitle: "Artist name",
            image: artwork
        ) {
            CarPlayListHeaderButton("Play", action: play).id("play")
        }
        return list.listHeader(header)
    }
    return list
}
```

Header values and actions can follow observable app state. Content updates keep
the native header, list, and rows intact. Give conditional or reordered actions
stable IDs with `.id(...)`. Compatible actions preserve identity; changing button
artwork replaces that native button. Use `.disabled(...)` to control selection.
Buttons accept a title, an image, or both; image-only buttons use `init(image:)`.
Provide ready-to-display artwork, and size button images for
`CPListTemplateDetailsHeader.maximumActionButtonSize`.

The host validates the native `maximumActionButtonCount`, unique explicit IDs,
and nonempty labels for actions without images before applying changes. Actions
use the screen navigation context, report unhandled errors to the host, and cancel
when the screen is removed or disconnected. Removed or replaced buttons ignore
stale taps. Already-running actions continue until completion or screen teardown.

Apply `.listHeader(...)` before `.loadingState` or other template-wide modifiers.
Loading presentation preserves the header. Pass `nil`, or omit the modifier on a
later render, to remove it. On earlier systems, omit the modifier and use ordinary
sections and rows for the same content or actions.

## Section headers

Sections accept a subtitle, ready-to-display image, header button, and section
index title. Subtitle, image, and button require a non-`nil` header title.
CarPlay displays only the first character of each index title. Size header
artwork for `CPMaximumListSectionImageSize` and the car display scale.

```swift
import CarPlayBuilder

@MainActor
func makeRecentlyPlayed() -> CarPlayList {
    CarPlayList("Library") {
        CarPlaySection(
            "Recently played",
            subtitle: "Continue listening",
            button: CarPlaySectionHeaderButton("Show all") { context in
                try await context.push {
                    CarPlayList("History") {
                        CarPlaySection {
                            CarPlayRow("Earlier episode").disabled()
                        }
                    }
                }
            },
            sectionIndexTitle: "R"
        ) {
            CarPlayRow("Latest episode").disabled()
        }
        .id("recent")
    }
}
```

Use `.disabled()` on a `CarPlaySectionHeaderButton` to disable selection. Button
labels must be nonempty. Header updates preserve existing rows; stable section
IDs also preserve header button identity through reordering. Actions use the
latest callback and the screen's normal navigation, cancellation, and error
handling. Removed buttons ignore stale taps. Already-running actions continue
until completion or screen removal, matching other screen selection actions.

## Alerts and toolbar actions

Modal actions dismiss their modal before running your callback. This permits a
callback to navigate or present another modal. Each modal needs at least one
titled action and at most one cancel action; alerts respect the native action
count limit. Repeated selection of the same modal is ignored.

```swift
import CarPlayBuilder

@MainActor
func confirmClear(context: CarPlayContext, model: LibraryModel) async throws {
    try await context.present(CarPlayActionSheet(
        "Clear library", message: "Remove the displayed episodes?"
    ) {
        CarPlayAlertAction("Clear", style: .destructive) { _ in
            model.titles.removeAll()
        }
        CarPlayAlertAction("Cancel", style: .cancel)
    })
}
```

Use `.leadingBarButtons { ... }` and `.trailingBarButtons { ... }` on a pushed list
or grid. Each side supports up to two buttons. Tab roots, tab containers, and
Now Playing do not support these toolbar modifiers.

```swift
import CarPlayBuilder

@MainActor
func makeDetails() -> some CarPlayTemplate {
    CarPlayList("Details") {
        CarPlaySection { CarPlayRow("Choose an action").disabled() }
    }
    .trailingBarButtons {
        CarPlayBarButton("Help") { context in
            try await context.present(CarPlayAlert("Help") {
                CarPlayAlertAction("Close", style: .cancel)
            })
        }
        .id("help")
    }
}
```

## Repeated-action policy

Selection actions allow concurrent invocations by default. Opt into
`.repeatedActionPolicy(.ignoreWhileRunning)` to ignore further taps on the same
control and temporarily disable its native presentation until running work ends.

```swift
import CarPlayBuilder

@MainActor
func makeSaveEpisode(save: @escaping CarPlayAction) -> CarPlayRow {
    CarPlayRow("Save episode", action: save)
        .id("save-episode")
        .repeatedActionPolicy(.ignoreWhileRunning)
}
```

The policy is supported by rows, grid buttons, toolbar buttons, section-header
buttons, rich-list-header buttons, artwork elements, and composed Now Playing
buttons. `.allowConcurrent` preserves the default behavior. Synchronous Now
Playing playback controls finish immediately and have no lasting busy interval.
Modal actions retain their existing dismissal and repeated-selection behavior.

Effective availability combines app state and running work: a control is enabled
only when the app enables it and its policy permits another invocation. Finishing
work never overrides `.disabled(true)`. Busy state updates immediately, before
asynchronous work starts; queued duplicate callbacks are checked internally even
when the native control is already disabled. Ignored list selections still call
their native completion callback.

Use stable IDs for conditional or reordered content. Running state follows the
same identity through updates and compatible native replacements, including
artwork changes. Row IDs are scoped to their section, and artwork element IDs are
scoped to their row. Removing a control retires its busy state; re-adding it starts
a new control lifetime. Removed controls ignore stale taps, while already-running
work retains its normal screen-owned lifetime.

Success, failure, and cooperative cancellation release running state. Errors keep
the normal per-screen recovery and host routing. Screen removal, disconnection,
and Now Playing reconnection cancel their owned work. Cancellation remains
cooperative. Changing policy while work runs considers all outstanding invocations
of that control, including work started with `.allowConcurrent`.

## Navigation events

Pass `onNavigation` when constructing the scene's host to observe completed
navigation and synchronize app state or record analytics:

```swift
import CarPlay
import CarPlayBuilder

@MainActor
func makeNavigationObservedHost(
    _ interfaceController: CPInterfaceController
) -> CarPlayHost {
    CarPlayHost(
        interfaceController: interfaceController,
        onErrorWithContext: { error, origin in
            print(error.localizedDescription, origin.source)
        },
        onNavigation: { event in
            print(event.kind, event.origin)
            print(event.current.stack.last?.title ?? "No screen")
        }
    ) {
        CarPlayList("Library") {}
    }
}
```

`CarPlayNavigationEvent` includes `kind`, `origin`, `animated`, and immutable
`previous`/`current` snapshots. Each snapshot contains a root-to-top `stack` and
an optional `modal`. Screen descriptors contain an ID, template kind, and title.
Mounted screen IDs match `CarPlayErrorContext.screenID`; modal IDs identify their
presentation. IDs last for that mounted lifetime and are not app route IDs.
Snapshots contain sendable values and retain no native templates or actions.

Events cover connection, push, pop, pop-to-root, root replacement, modal
presentation/dismissal, and disconnection. Native Back and observed native modal
dismissal use `.native` origin; host/context operations use `.programmatic`.
Selecting a modal action reports its dismissal before running the action.
Selecting a tab can report a `.poppedToRoot` stack change; use the tab container's
`.onSelectionChange` for the selected tab itself. Showing an already-stacked
Now Playing screen reports the resulting pop when the stack actually changes.

The callback runs synchronously on the main actor after the navigation gate is
released. Keep it inexpensive; schedule asynchronous follow-up when needed.
Rejected operations, stale completions after disconnect, duplicate delegate
notifications, and operations that leave the same stack/modal identities are
silent. If tab navigation pops to root but later cannot select the requested tab,
the completed stack change is still reported. Titles reflect navigation-time
snapshots; ordinary observed content updates do not emit navigation events.

Events describe host-owned templates. Continue using the host/context APIs for
navigation and leave its native controller delegate installed. Disconnection
reports the host's released state without requesting a native stack dismissal.

## Per-screen error recovery

Attach `.onError` to a template to recover from selection or lifecycle failures
near the screen that owns them. Return `.handled` when the screen owns recovery,
or `.unhandled` to continue propagation. The callback runs synchronously on the
main actor and receives the original error and the owning scene navigation context.

```swift
import CarPlayBuilder
import Foundation

@MainActor
func makeRecoverableLibrary(
    load: @escaping CarPlayTaskAction,
    showOffline: @escaping @MainActor () -> Void
) -> some CarPlayTemplate {
    CarPlayList("Library") {
        CarPlaySection {
            CarPlayRow("Your library").disabled()
        }
    }
    .task { try await load() }
    .onError { error, _ in
        guard let urlError = error as? URLError,
              urlError.code == .notConnectedToInternet else {
            return .unhandled
        }
        showOffline()
        return .handled
    }
}
```

Update observable app state to present offline content, authentication, or another
recovery flow. Run asynchronous follow-up through screen tasks or subsequent
selection actions. Returning `.handled` does not automatically retry failed work.

Multiple modifiers run from inner to outer; the first `.handled` stops the chain.
Tab selection actions and lifecycle tasks first try the tab's handlers, then its
tab container's handlers, then the host's error handler. A pushed screen has its
own recovery chain. Running actions use the latest accepted handlers when they
fail, and omitting a handler on a later render removes it. Row, grid, toolbar,
section-header, rich-header, and image-element actions share this behavior.

Rejected observed updates use the mounted screen root's last accepted handlers,
including when validation rejects a tab subtree. Recovery can update model state
to produce a valid render; invalid content and its handlers do not replace the
previous screen. Normal cancellation stays silent, and teardown stops propagation.

Explicitly awaited navigation and initial mounting failures still throw to their
caller. When navigation throws inside an unhandled selection action, that action's
screen can recover. Scene-owned modal actions and the separate Now Playing
coordinator continue using their existing error handlers.

### Error origin

Use `.onErrorWithContext` when recovery depends on which operation failed. It
receives the original error, a `CarPlayErrorContext`, and the scene's navigation
context. For example, handle refresh failures without intercepting row actions:

```swift
import CarPlayBuilder

@MainActor
func makeContextualLibrary(
    refresh: @escaping CarPlayTaskAction,
    showRefreshFailure: @escaping CarPlayContextualErrorHandler
) -> some CarPlayTemplate {
    CarPlayList("Library") {}
        .task(id: "refresh") { try await refresh() }
        .onErrorWithContext { error, origin, _ in
            guard origin.source == .lifecycleTask,
                  origin.taskID == AnyHashable("refresh") else {
                return .unhandled
            }
            showRefreshFailure(error, origin)
            return .handled
        }
}
```

| Context field | Meaning |
| --- | --- |
| `source` | Action, lifecycle task, observed rendering, or coordinator navigation. |
| `screenID` | UUID stable for the lifetime of the originating mounted template. |
| `screenTitle` | Accepted list/grid title when work started, or when rendering failed. |
| `control` | Row, image element, grid/button/header control, modal action, or Now Playing destination. |
| `controlID` | Explicit control ID, where supplied; modal actions use their zero-based index. |
| `taskID` | The value supplied to `.task(id:)` for lifecycle failures. |

Contextual and existing `.onError` modifiers share one ordered recovery chain.
When tab errors propagate to their container, they retain the originating child's
screen identity. Running actions retain their original IDs while using the latest
accepted recovery handlers. IDs are metadata and do not change task ownership.

`CarPlayHost` and both `CarPlayNowPlayingCoordinator` initializers accept an
`onErrorWithContext: { error, origin in ... }` callback. When supplied, it replaces
the initializer's legacy `onError` callback; existing error-only callers continue
receiving the original error. Modal and Now Playing reports have no mounted
screen identity. Controls without explicit IDs report `nil`; section header
buttons currently have no separate control ID.

Context callbacks run on the main actor. Arbitrary `Hashable` IDs may not be
sendable; extract sendable diagnostic fields before forwarding them to background
work. Cancellation stays silent. Explicit navigation and initial mount failures
continue throwing to their caller; navigation errors inside a selection report
that action's origin rather than producing a second report. Resource and artwork
loaders retain their separate error behavior.

## Asynchronous loading and cancellation

`CarPlayResource<Value>` shares one request among concurrent callers, publishes
observable state, and retains the last successful value during refreshes or
failures. It stores the original error in `.failed`. `loadIfNeeded()` runs only
from idle; retry a failure or refresh a loaded value with `reload()`.

The following screen is complete. Its caller supplies the data loader, keeping
networking and decoding in the application.

```swift
import CarPlayBuilder

@MainActor
struct FeedScreen: CarPlayTemplate {
    let resource: CarPlayResource<[String]>

    var body: some CarPlayTemplate {
        CarPlayList("Feed") {
            CarPlaySection {
                for title in resource.value ?? [] {
                    CarPlayRow(title).id(title)
                }
            }
        }
        .loadingState(
            resource.state,
            isEmpty: resource.value?.isEmpty ?? true,
            configuration: .init(empty: .init(
                title: "No episodes available", systemImage: "tray"
            ))
        ) {
            await resource.reload()
        }
        .task {
            await resource.loadIfNeeded()
        }
    }
}

@MainActor
func makeFeed(
    load: @escaping @MainActor () async throws -> [String]
) -> FeedScreen {
    FeedScreen(resource: CarPlayResource(load: load))
}
```

Own the resource in your scene or model when multiple screens share it. A screen
waiting for a shared resource does not cancel the underlying load when it hides;
call `resource.cancel()` when its owner needs to stop it. Cancellation restores
idle or loaded state and prevents stale requests from publishing results.

By contrast, `.task(id:)` work belongs to native visibility: it starts on
appearance, cancels on disappearance, and restarts on the next appearance or an
ID change. Completed work does not restart merely because content re-renders.
Multiple task modifiers run independently. Cancellation is cooperative, so custom
loaders should honor cancellation and avoid blocking the main actor.

`.onAppear` and `.onDisappear` handle synchronous visibility work. Selection
actions remain alive until completion and cancel when their screen is removed or
the scene disconnects. Native list completion runs when the action returns,
including after error or cancellation.

## Customize loading, empty, and failure presentation

Existing `.loadingState(...)` calls keep their default behavior. Lists accept row
builders and grids accept button builders for `loading`, `empty`, and `failure`.
Each builder runs only when its status is needed and can use conditionals, loops,
and observable app state. Omit a builder to use the default presentation. A
failure builder receives the original error, so the app can choose recovery
appropriate to authentication, offline access, or other domain conditions.

This screen customizes list status rows and keeps usable content visible during
refresh. Its resource is supplied by the owning scene or model.

```swift
import CarPlayBuilder

@MainActor
struct SavedEpisodesScreen: CarPlayTemplate {
    let resource: CarPlayResource<[String]>

    var body: some CarPlayTemplate {
        CarPlayList("Saved episodes") {
            CarPlaySection {
                for title in resource.value ?? [] {
                    CarPlayRow(title).id(title)
                }
            }
            .id("episodes")
        }
        .loadingState(
            resource.state,
            isEmpty: resource.value?.isEmpty ?? true,
            retainsContentDuringRefresh: true,
            loading: {
                CarPlayRow("Updating your library…").disabled()
            },
            empty: {
                CarPlayRow("No saved episodes").disabled()
                CarPlayRow("Refresh library") { _ in await resource.reload() }
            },
            failure: { error in
                CarPlayRow("Library unavailable", detail: error.localizedDescription)
                    .disabled()
                CarPlayRow("Try again") { _ in await resource.reload() }
            }
        )
        .task { await resource.loadIfNeeded() }
    }
}
```

Retention uses the current content supplied by the app, not a hidden snapshot of
previous native content. Pass `isEmpty: true` when there is no usable value.

| State | Default | With retention and nonempty content |
| --- | --- | --- |
| Idle | Loading status replaces content. | Same initial loading presentation. |
| Loading | Loading status replaces content. | Existing content remains; loading builder is skipped. |
| Failed | Failure status replaces content. | Recovery rows form a new list section, or recovery buttons follow existing grid buttons. |
| Loaded, empty | Empty status replaces content. | Same empty presentation. |
| Loaded, nonempty | Normal content. | Normal content. |

Custom builders own their actions. The `retry:` callback is used only by default
empty/failure presentation and is not added to custom content. Recovery actions
use the screen's normal cancellation, completion, and error handling.

For grids, supply native buttons instead of rows:

```swift
import CarPlayBuilder
import UIKit

@MainActor
func makeRecoveryGrid(resource: CarPlayResource<[String]>) -> some CarPlayTemplate {
    CarPlayGrid("Library") {
        for title in resource.value ?? [] {
            CarPlayButton(
                title,
                image: UIImage(systemName: "play.circle") ?? UIImage()
            ) { _ in }
            .id(title)
        }
    }
    .loadingState(
        resource.state,
        isEmpty: resource.value?.isEmpty ?? true,
        empty: {
            CarPlayButton(
                "Refresh", image: UIImage(systemName: "arrow.clockwise") ?? UIImage()
            ) { _ in await resource.reload() }
        }
    )
}
```

Native item limits and unique IDs still apply to the combined retained and status
content. Reserve space for recovery buttons if retaining a grid: eight content
buttons plus a recovery button exceeds CarPlay's grid limit and is rejected by
validation. Use unique IDs for custom grid buttons across the complete grid.

A builder can explicitly `return nil` to use defaults for a particular condition.
An empty builder produces no custom items; an empty list is allowed, while a grid
must still contain at least one button. Template kind, list title, toolbar
modifiers, and lifecycle tasks are preserved.

For simpler changes, use `CarPlayStatusLabel` values in
`CarPlayLoadingConfiguration`. Each label keeps its title and SF Symbol together.
The `.loading`, `.failure`, `.empty`, and `.retry` factories provide the standard
English labels; supply localized titles from the app when needed.

```swift
import CarPlayBuilder

let statusConfiguration = CarPlayLoadingConfiguration(
    loading: .loading,
    empty: .init(title: "No saved episodes", systemImage: "tray"),
    retry: .retry
)
```

Map errors to `CarPlayErrorPresentation` to choose a title, symbol, and optional
message together. For example, an offline failure can explain how to recover:

```swift
import CarPlayBuilder
import Foundation

let errorPresentation: CarPlayErrorPresentationProvider = { error in
    if (error as? URLError)?.code == .notConnectedToInternet {
        return .init(
            label: .init(title: "No connection", systemImage: "wifi.slash"),
            message: "Check your connection and try again."
        )
    }
    return .init(message: "Please try again later.")
}

let loadingConfiguration = CarPlayLoadingConfiguration(failure: errorPresentation)
```

Default lists display the error title and optional message; default grids display
its title and symbol. Without a provider, the standard failure label and the
error's `localizedDescription` are used. Supply app-localized, user-facing text
when technical error descriptions would be unhelpful. The synchronous sendable
provider runs once per default failure render on the main actor; keep it cheap.

Custom failure builders receive the original error and bypass this provider. They
can explicitly call the same provider to reuse its text and artwork. The provider
can also be called from the host's `onError` or a screen's `.onError` handler for
app-owned error UI. It does not present alerts or mark errors handled. Recovery actions and the optional
`retry:` callback remain separate from the presentation value.

## Native empty-list text

Use `.emptyView(titleVariants:subtitleVariants:)` on `CarPlayList` for a simple,
noninteractive empty view. Supply localized variants in preference order,
typically longest to shortest; CarPlay chooses the first that fits the display.

```swift
import CarPlayBuilder

@MainActor
func makeSavedEpisodes(_ titles: [String]) -> CarPlayList {
    CarPlayList("Saved episodes") {
        CarPlaySection {
            for title in titles {
                CarPlayRow(title).disabled()
            }
        }
    }
    .emptyView(
        titleVariants: ["No saved episodes", "No episodes"],
        subtitleVariants: ["Save episodes on your iPhone", "Save on iPhone"]
    )
}
```

The native empty view appears only when the list contains zero items and hides
automatically when rows appear. It adds no rows or actions. Text updates preserve
the mounted list, sections, and rows. Empty arrays clear the corresponding text;
omitting the modifier on a later render restores the list's native defaults.

Apply `.emptyView(...)` before template-wide modifiers such as `.loadingState`.
Loading, empty, or failure rows produced by `.loadingState` take precedence
because the list then contains items. A custom status builder returning `[]`
leaves the native fallback available when the resulting list has zero items.

On iOS 18.4 or later, `.showsSpinnerWhileEmpty(isLoading)` adds the native activity
indicator alongside empty-view text. It appears only when the list has zero items
and adds no placeholder row. Pass `false` when loading finishes; the modifier does
not manage requests or infer loading state. Omitting it on a later render restores
the native default. Apply it before template-wide modifiers.

```swift
import CarPlayBuilder

@MainActor
func makeLoadingEpisodes(isLoading: Bool) -> CarPlayList {
    let list = CarPlayList("Episodes") {}
        .emptyView(titleVariants: [isLoading ? "Loading episodes…" : "No episodes"])
    if #available(iOS 18.4, *) {
        return list.showsSpinnerWhileEmpty(isLoading)
    }
    return list
}
```

Default `.loadingState` rows suppress the native spinner because they count as
items. To use the native spinner during loading, supply `loading: { [] }` and
set spinner visibility from your app's loading state. The loading modifier
preserves empty-view text and spinner settings.

## Artwork and row presentation

Read cached images while describing a template and request images from a
lifecycle task. Cache insertions then invalidate observed content automatically.
This function accepts an app-owned store and URL, and produces a complete screen.

```swift
import CarPlayBuilder
import Foundation
import UIKit

@MainActor
func makeArtworkScreen(
    store: CarPlayArtworkStore, coverURL: URL
) -> some CarPlayTemplate {
    CarPlayList("Artwork") {
        CarPlaySection {
            CarPlayRow(
                "Episode",
                image: store.image(
                    for: coverURL,
                    placeholder: UIImage(systemName: "music.note")
                )
            )
            .id("episode")
        }
    }
    .task(id: coverURL) { await store.loadImage(from: coverURL) }
}
```

The store defaults to a 100-image cache and four concurrent requests. Repeated
URLs share work. Cancelling one consumer leaves other consumers running; the last
consumer cancels its load. Errors leave a cache miss so a later load can retry.
The cache is memory-only and may be evicted by the system.

Own a separate store per image size and authentication scope. The default size
hint is `CPListItem.maximumImageSize`. The default HTTP loader validates a 2xx
response and creates and prepares the image for display off the main actor,
avoiding deferred decompression on first display. It does not resize locally.
A custom `CarPlayArtworkLoading` implementation or loader request modifier
can provide authentication or size-specific variants. Outgoing request changes
do not change the cache key, which remains the original URL.

### Artwork state, retry, and invalidation

`CarPlayArtworkStore.state(for:)` exposes `CarPlayLoadState` without starting a
request. Queued and shared requests are `.loading`; `.loaded` means an image is
currently cached. `.failed(error)` preserves the original error. Cancellation,
invalidation, and missing URLs return `.idle`. Reading state or artwork from a
template participates in observation of loading, completion, and invalidation.

Use a separate failure placeholder for unavailable artwork:

```swift
import CarPlayBuilder
import Foundation
import UIKit

@MainActor
func makeArtworkRow(
    url: URL,
    artwork: CarPlayArtworkStore
) -> some CarPlayTemplate {
    CarPlayList("Artwork") {
        CarPlaySection {
            CarPlayRow(
                "Episode",
                image: artwork.image(
                    for: url,
                    placeholder: UIImage(systemName: "photo"),
                    failurePlaceholder: UIImage(systemName: "wifi.slash")
                )
            )
            if case .failed = artwork.state(for: url) {
                CarPlayRow("Retry artwork") { _ in
                    await artwork.loadImage(from: url)
                }
            }
        }
    }
    .task(id: url) { await artwork.loadImage(from: url) }
}
```

A missing failure placeholder falls back to the ordinary placeholder. A missing
URL always uses the ordinary placeholder. Placeholders are not cached or passed
through the decoder or image modifier. Inspect the original error through state
when an app needs error-specific placeholder selection or diagnostics.

| Operation | Behavior |
| --- | --- |
| `loadImage(from:)` | Uses cached artwork, joins pending work, or retries an uncached/failed URL. |
| `reloadImage(from:)` | Removes cached artwork and retries, joining any already-pending request. |
| `invalidateImage(for:)` | Removes the image and failure, cancels that URL's work, and resumes its consumers. |
| `invalidateAllImages()` | Clears both caches and cancels all active/queued work. |

Invalidation does not automatically start another request. Existing native image
content updates through observation. An unchanged `.task(id:)` does not restart
itself; explicitly load again or change its ID when a new request is needed.
For account changes, invalidate the old store and replace it if the loader's
credentials or image processing configuration changed.

Concurrent refresh callers share one request; one consumer's cancellation leaves
other consumers running. Explicit invalidation cancels the shared request for all
consumers. Late results cannot restore invalidated images or complete a newer
request for the same URL. Cancelled loaders continue occupying concurrency slots
until they exit, preserving the configured request limit even for custom loaders
that ignore cancellation.

Image and failure caches are separately limited by `cacheLimit` and may be evicted
by the system; zero/negative limits remain unbounded. Evicted state becomes idle
on the next read. Automatic eviction does not itself emit an observation change.
Artwork failures remain local to the store and do not automatically display
alerts or reach the scene's error handlers.

### Customize image decoding

`CarPlayArtworkLoader` accepts an `imageDecoder` closure that converts `Data` to
`UIImage`. It defaults to UIKit image creation followed by display preparation.
The synchronous throwing closure is `@Sendable` and is invoked off the main actor,
after HTTP validation and before `imageModifier`.

For example, this decoder sets the image scale to 2 and prepares it for display:

```swift
import CarPlayBuilder
import Foundation
import UIKit

@MainActor
func makeScaledArtworkStore() -> CarPlayArtworkStore {
    let loader = CarPlayArtworkLoader(imageDecoder: { data in
        guard let image = UIImage(data: data, scale: 2) else {
            throw URLError(.cannotDecodeContentData)
        }
        try Task.checkCancellation()
        guard let prepared = image.preparingForDisplay() else {
            throw URLError(.cannotDecodeContentData)
        }
        return prepared
    })
    return CarPlayArtworkStore(loader: loader)
}
```

Setting image scale changes its point size; it does not downsample the pixels.
A custom decoder can instead use app-owned downsampling or format support.
Return display-ready artwork, honor cancellation during expensive work, and
throw on failure. Decoder errors propagate to direct callers; the store leaves
a cache miss and permits retry. Cache hits do not decode again. Keep separate
stores for different decoding configurations.

### Modify loaded images

Pass an `imageModifier` to `CarPlayArtworkLoader` to transform decoded artwork
before the store caches or displays it. For example, this store tints downloaded
images blue:

```swift
import CarPlayBuilder
import UIKit

@MainActor
func makeTintedArtworkStore() -> CarPlayArtworkStore {
    let loader = CarPlayArtworkLoader(imageModifier: { image, _ in
        image.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
    })
    return CarPlayArtworkStore(loader: loader)
}
```

The async throwing closure receives the decoded `UIImage` and requested `CGSize`.
It runs after HTTP validation and decoding, and defaults to returning the image
unchanged. Use it for resizing, cropping, or overlays as well as tinting.

Both `requestModifier` and `imageModifier` are `@Sendable` async throwing closures,
invoked off the main actor. They can use nonisolated functions or await work on an
app-owned actor. Capture sendable values and use actor-safe access to shared
state; explicitly hop to the main actor when accessing UI-owned state. Keep
processing bounded and honor cancellation. The artwork store and native template
updates remain on the main actor.

The store caches only the transformed image. Cache hits and shared requests do
not repeat processing. A thrown error leaves a cache miss, permitting a later
retry; calling the loader directly propagates that error. Cancellation is checked
before and after processing, so cancelled results cannot be returned or cached.
Placeholders are not processed. Use separate stores for different processing
configurations, since the cache key remains the original URL.

Use `.trailingImage(image)` for a row’s accessory artwork. It takes precedence
over `.accessory(...)`; passing `nil` restores the configured indicator.
`.playback(isPlaying:progress:)` updates row presentation, with progress clamped
to 0...1. It does not control your audio player.

Use `.explicitContent()` to mark a row with the native explicit-content indicator;
pass `false` to remove it. This is a content label, not an access restriction.
Use `.playingIndicatorLocation(.trailing)` to move the Now Playing indicator from
its default leading position. The indicator appears while `isPlaying` is `true`.
These modifiers preserve artwork, accessories, and playback progress; CarPlay
controls their final layout.

```swift
import CarPlayBuilder

@MainActor
func makeCurrentEpisode(isExplicit: Bool, progress: Double) -> CarPlayRow {
    CarPlayRow("Current episode", detail: "Podcast")
        .explicitContent(isExplicit)
        .playingIndicatorLocation(.trailing)
        .playback(isPlaying: true, progress: progress)
}
```

On iOS 26+, embed image rows inside sections. Availability checks keep the rest
of the app compatible with iOS 17. This function takes app-owned artwork.

```swift
import CarPlayBuilder
import UIKit

@MainActor
func makeFeatured(artwork: UIImage) -> some CarPlayTemplate {
    CarPlayList("Featured") {
        CarPlaySection {
            if #available(iOS 26.0, *) {
                CarPlayImageRow("Highlights", style: .card) {
                    CarPlayImageElement("Episode", image: artwork) { context in
                        try await context.present(CarPlayAlert("Selected") {
                            CarPlayAlertAction("Close", style: .cancel)
                        })
                    }
                    .id("featured-episode")
                    .fullHeightImage()
                }
                .id("highlights")
            } else {
                CarPlayRow("Episode", image: artwork).disabled()
            }
        }
    }
}
```

Image-row styles are `.row`, `.card`, `.condensed`, `.grid`, and `.imageGrid`.
Cards support tint and full-height artwork; condensed and image-grid layouts
support image shape and accessory symbols. Partition larger collections to fit
the native element limit. Elements without actions are not selectable.

## Now Playing

Call `try await context.showNowPlaying()` after your app starts playback.
`CarPlayNowPlayingCoordinator` optionally adds native rate, shuffle, repeat,
Add to Library, More, and Up Next controls. It does not supply a player or queue.

Implement `CarPlayNowPlayingPlayback` in your app’s player adapter:

- `hasUpNext` reads observable queue state.
- `cyclePlaybackRate()`, `toggleShuffle()`, and `cycleRepeatMode()` implement your
  app’s behavior and update its player and media metadata.

This factory accepts an existing conforming player and a lazy Up Next screen.

```swift
import CarPlayBuilder

@MainActor
func makeNowPlaying(
    playback: any CarPlayNowPlayingPlayback,
    upNext: @escaping @MainActor () -> some CarPlayTemplate
) -> CarPlayNowPlayingCoordinator {
    CarPlayNowPlayingCoordinator(
        playback: playback,
        configuration: .init(
            showsPlaybackRateButton: true,
            showsShuffleButton: true,
            showsRepeatButton: true
        ),
        onError: { error in print(error.localizedDescription) },
        upNext: upNext
    )
}
```

Retain the coordinator in the scene. After the host connects successfully, call
`coordinator.connect(context: host.context)`. On scene disconnection, call both
`coordinator.disconnect()` and `host.disconnect()`. These calls cancel scene work;
your app decides whether audio continues.

The shared native Now Playing template has one active coordinator. Connecting a
coordinator supersedes the previous owner, removes its observation, and cancels
its actions and pending destination work. Disconnecting a superseded coordinator
does not clear the current owner's controls or labels. Reconnect explicitly to
reclaim ownership.

Only playback rate is enabled by default. Add to Library and More each require
both their configuration flag and callback. Supplying `isAddedToLibrary` uses an
observable selected bookmark button in place of the standard Add to Library
button. Saving and persistence remain application responsibilities.

### Compose Now Playing controls

Use the `buttons:` initializer to choose the leading-to-trailing order of up to
five controls. It replaces the configuration's visibility flags and legacy
Add to Library/More callbacks. The default initializer remains available with
its existing behavior. An empty button builder hides all auxiliary controls.

The builder observes app state while connected. Give conditional or reordered
buttons stable IDs with `.id(...)`. Compatible controls retain native identity;
changing an image or button kind replaces the affected native control. Invalid
counts or duplicate explicit IDs reach `onError` and preserve the last valid
buttons. Keep builders free of side effects.

Standard factories are `.playbackRate`, `.shuffle`, `.repeatMode`,
`.addToLibrary(action:)`, and `.more(action:)`. The first three call the app's
`CarPlayNowPlayingPlayback` adapter. All controls support `.disabled(...)`;
custom image controls also support `.selected(...)`. Standard selected appearance
continues to follow the app's system media metadata.

```swift
import CarPlayBuilder
import UIKit

@MainActor
func makeComposedNowPlaying(
    playback: any CarPlayNowPlayingPlayback,
    saveImage: UIImage,
    isSaved: @escaping @MainActor () -> Bool,
    save: @escaping CarPlayAction,
    album: @escaping @MainActor () -> some CarPlayTemplate,
    queue: @escaping @MainActor () -> some CarPlayTemplate
) -> CarPlayNowPlayingCoordinator {
    CarPlayNowPlayingCoordinator(
        playback: playback,
        configuration: .init(upNextTitle: "Episodes"),
        onError: { print($0.localizedDescription) },
        albumArtist: { album() },
        buttons: {
            CarPlayNowPlayingButton(image: saveImage, action: save)
                .id("save")
                .selected(isSaved())
            CarPlayNowPlayingButton.playbackRate.id("rate")
            CarPlayNowPlayingButton.repeatMode.id("repeat")
        },
        upNext: { queue() }
    )
}
```

Supply ready-to-display custom images sized for
`CPNowPlayingButtonMaximumImageSize`; CarPlay recolors them. Selection uses the
latest rendered callback. Custom actions receive the scene navigation context,
report unhandled errors to `onError`, and cancel on reconnection or disconnect.
Removed or replaced controls ignore stale taps; already-running actions continue
until completion or scene teardown.

### Now Playing destinations and labels

Set `CarPlayNowPlayingConfiguration.upNextTitle` to a localized label such as
“Queue” or “Episodes”. `nil` uses the native default. Up Next availability still
follows `playback.hasUpNext`.

Both initializer styles accept an optional `albumArtist:` closure. Supplying it
makes the native album/artist text tappable and lazily pushes the returned album,
playlist, or show screen. The closure runs when tapped, so it can read the current
track. Your app's MediaPlayer metadata supplies the album/artist text itself.

Up Next and album/artist navigation share one pending task: a new destination tap
cancels the previous pending navigation, and reconnecting or disconnecting cancels
it too. Native navigation errors reach `onError`; normal cancellation is ignored.
Disconnecting disables the destination controls and restores the default Up Next
label on the shared native template.

## Identity and updates

- Give dynamic sections, rows, grid buttons, toolbar buttons, and artwork elements
  stable IDs unique among siblings. Tabs always require an ID.
- Without an explicit ID, collection items use their position. Row identity is
  scoped to its section, so moving a row between sections creates a new item.
- Native row and section objects are reused when their identity and layout permit.
  iOS 26 grids update button artwork and titles in place; older systems replace
  buttons when those values change.
- Keep models and asynchronous callbacks on the main actor where required by the
  API. Put expensive synchronous decoding or processing behind an appropriate
  application-owned concurrency boundary.

## API documentation and development

Public declarations include DocC comments for Xcode Quick Help. Open `Package.swift`
in Xcode, select the `CarPlayBuilder` scheme and an iOS destination, and choose
**Product → Build Documentation** to browse the API and package overview.

The repository contains the library in `Sources/CarPlayBuilder` and Swift Testing
unit tests in `Tests/CarPlayBuilderTests`. There is no example app or Xcode test
project. Open the package in Xcode and run its tests on an installed iOS simulator.
A plain macOS `swift test` cannot build the iOS CarPlay and UIKit frameworks.

Tests cover builders, observation, reconciliation, navigation, modal actions,
toolbars, loading, artwork requests, and Now Playing controls with injected
transports. Test actual vehicle presentation and media behavior in a CarPlay app.

Follow [AGENTS.md](AGENTS.md) for code style and `.swiftformat` for formatting.
When contributing API changes, update their DocC comments, README samples, and
relevant tests. Record user-visible changes in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE). Copyright (c) 2026 Raimar Tasche.

## Continuous integration

GitHub Actions runs independent **SwiftFormat**, **iOS simulator tests**, and
**DocC** checks on pushes, pull requests, and manual workflow runs. The workflow
uses the [`macos-26` runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
with Xcode 26.6. Simulator selection uses an available
iPhone on iOS 26.4 or later so newer CarPlay layouts and list headers are covered.

SwiftFormat is pinned in `.swiftformat-version` and reads `.swiftformat`. CI
lints without rewriting files. Test results (`.xcresult`) are uploaded even when
tests fail, and successful DocC builds upload a `.doccarchive`; artifacts are
retained for seven days. Documentation warnings fail the DocC check.

Run the same checks locally with the selected Xcode command-line tools and the
pinned SwiftFormat version installed:

```sh
bash .github/scripts/ci.sh format
bash .github/scripts/ci.sh test
bash .github/scripts/ci.sh docs
```

Each invocation creates a fresh temporary output directory. Supply a second
argument to choose an output directory; test output directories must not already
contain `TestResults.xcresult`. The test script creates the ignored Swift package
workspace when needed. Builds target iOS 17 while the simulator uses a newer
runtime; the package's deployment minimum remains iOS 17.
