# CarPlayBuilder Sample

A small iOS app that uses the local CarPlayBuilder package. It includes three
original, generated audio loops and works offline after building.

## Run in Simulator

1. Use Swift 6.2 or later and Xcode with the iOS 26.4 SDK or later, matching the
   library's build requirements. The app's deployment minimum is iOS 17.
2. Open `CarPlaySample.xcodeproj` from this directory. No project generator or
   additional package dependency is needed.
3. Select the **CarPlaySample** scheme and an iPhone simulator, then run.
4. In Apple's iOS Simulator, choose **I/O → External Displays → CarPlay**.
5. Open **CarPlay Sample** from the CarPlay Home screen.

The project includes the audio CarPlay entitlement and scene manifest.
Simulator builds do not require your own development team. For a physical device,
choose your team and a unique bundle identifier in Signing & Capabilities. Your
provisioning profile must include Apple's approved CarPlay audio entitlement.
See Apple's [entitlement guide](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
and [simulator guide](https://developer.apple.com/documentation/carplay/using-the-carplay-simulator).

## Try it

- On CarPlay, open a track in **Library** to push its detail screen. Select
  **Play** to start its bundled audio and show the native Now Playing screen.
- Use native Play/Pause and Next controls. Audio loops until paused. Pausing
  releases the audio session; resuming continues the current loop.
- Save a track from its detail screen. The **Saved** tab and its badge update
  through Observation, without manually updating native templates.
- Save or remove tracks on the iPhone while viewing **Saved** in CarPlay. Both
  scenes share the same model, so the CarPlay list updates immediately.
- Disconnect and reconnect CarPlay. Its host and scene-owned tasks are torn down
  and recreated; app-owned audio playback continues until paused.

## Explore the Browse grid

The **Browse** tab is a native grid with eight stable buttons. Grids remain at
tab roots for compatibility with audio apps on iOS 18. Each destination below
pushes a list, presents a modal, or switches tabs.

| Button | What it demonstrates |
| --- | --- |
| Library / Saved | Programmatic tab selection through the scene context. |
| Discover | A one-second simulated load, followed by navigable results. Refresh retains existing rows. |
| Empty library | A successful load with zero results and the default empty/retry presentation. |
| Offline & retry | The first load deliberately fails. Select Retry to recover with local results. |
| Artwork | iOS 26 artwork tiles with generated cover images; iOS 26.4 adds a rich header with a Play action. Earlier systems show an explanatory alert. |
| Clear Saved | An action sheet with destructive and cancel actions. Confirming clears the in-memory collection and selects Saved. |
| About | A native alert, also available in track detail toolbars. |

Track details have reactive **Save/Unsave** and **About** toolbar buttons. The
discovery screens use a **Refresh** toolbar action with repeated taps ignored
while the request runs. Leaving a discovery screen cancels its screen-owned
resource; returning can resume from its last successful value.

The empty and offline scenarios are intentional demonstrations, not network
requests. Artwork is rendered locally and reused in library rows and Now Playing.

Saved tracks are kept in memory for this demo. Audio interruptions and unplugging
headphones pause playback; resume manually afterward. This is an integration
example, not a production music player or a network-streaming implementation.

## Where to look

| File | Responsibility |
| --- | --- |
| `Sources/SampleCarPlaySceneDelegate.swift` | Connects and disconnects one host per CarPlay scene; owns its connection task. |
| `Sources/SampleRootScreen.swift` | Library, Browse, and Saved tabs with an observable badge. |
| `Sources/SampleBrowseScreen.swift` | Eight-button grid, programmatic tab selection, and modal entry points. |
| `Sources/SampleDiscoveryScreen.swift` | Loading, empty, failure, retry, refresh retention, and visibility tasks. |
| `Sources/SampleDiscoveryModel.swift` | Screen-owned resource with deterministic offline scenarios. |
| `Sources/SampleArtworkScreen.swift` | Version-gated image rows and rich list headers. |
| `Sources/SampleArtwork.swift` | Cached, locally rendered artwork with SF Symbols. |
| `Sources/SampleDialogs.swift` | Native alert and destructive confirmation sheet. |
| `Sources/SampleLibraryScreen.swift` | Stable row IDs, playback indicators, empty state, and navigation links. |
| `Sources/SampleTrackScreen.swift` | Playback, saving, and navigation to native Now Playing. |
| `Sources/SampleModel.swift` | App-owned player, media metadata, remote commands, and shared observable state. |
| `Sources/SampleContentView.swift` | SwiftUI companion interface using the same model. |
| `Info.plist` | CarPlay scene registration and background audio mode. |
| `CarPlaySample.entitlements` | Audio CarPlay entitlement. |

`SampleModel.shared` deliberately provides a single app-lifetime model to both
SwiftUI and the UIKit-created CarPlay scene delegate. The library does not own
this model, audio playback, remote command handling, or system media metadata.

The Xcode project references the package at `../..`. Keep this directory inside
the repository when opening it; it does not download a published release.

## Build from the command line

From the repository root:

```sh
bash .github/scripts/ci.sh sample
```

This compiles for iOS Simulator without signing. To run the app, build normally
in Xcode so the simulator app includes its CarPlay entitlement.

The bundled WAV files are generated specifically for this MIT-licensed sample,
with no downloaded or third-party recordings. Regenerate them with:

```sh
python3 Examples/CarPlaySample/Resources/generate-audio.py
```
