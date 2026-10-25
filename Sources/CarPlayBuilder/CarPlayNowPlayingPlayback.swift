// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation

/// App-owned playback operations used by the native Now Playing controls.
/// Observable properties read by `hasUpNext` are tracked while connected.
@MainActor
public protocol CarPlayNowPlayingPlayback: AnyObject {

    /// Whether the coordinator should enable the native Up Next button.
    ///
    /// Read observable state here so the connected coordinator tracks changes.
    var hasUpNext: Bool { get }

    /// Advances the app’s playback rate and updates its player and media metadata.
    func cyclePlaybackRate()
    /// Toggles the app’s shuffle behavior and publishes the resulting media state.
    func toggleShuffle()
    /// Advances the app’s repeat mode and publishes the resulting media state.
    func cycleRepeatMode()
}
