// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Routes native control taps to app-owned playback or asynchronous actions.
enum CarPlayNowPlayingAction: Equatable {

    case playbackRate
    case shuffle
    case `repeat`
    case addToLibrary
    case more
    case custom
}
