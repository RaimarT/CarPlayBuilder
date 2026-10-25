// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Retains native control identity and always dispatches its latest action.
@MainActor
final class CarPlayMountedNowPlayingButton {

    private(set) var content: CarPlayNowPlayingButton
    private let playback: any CarPlayNowPlayingPlayback
    private let context: CarPlayContext
    private let scope: CarPlayTaskScope
    let actionState: CarPlayActionState
    private var active = true
    private lazy var native = self.makeNative()

    var item: CPNowPlayingButton {

        self.native
    }

    init(
        content: CarPlayNowPlayingButton,
        playback: any CarPlayNowPlayingPlayback,
        context: CarPlayContext,
        scope: CarPlayTaskScope,
        actionState: CarPlayActionState? = nil
    ) {

        self.content = content
        self.playback = playback
        self.context = context
        self.scope = scope
        self.actionState = actionState ?? CarPlayActionState()
    }

    func matches(_ content: CarPlayNowPlayingButton) -> Bool {

        self.content.kind == content.kind && self.content.image === content.image
    }

    func update(_ content: CarPlayNowPlayingButton) {

        self.content = content

        self.updateAvailability()

        if content.image != nil, self.item.isSelected != content.isSelected {

            self.item.isSelected = content.isSelected
        }
    }

    func activate() {

        guard self.active, self.content.isEnabled else {

            return
        }

        self.updateAvailability()

        if let action = self.content.action {

            let context = self.context
            self.actionState.perform(
                in: self.scope,
                control: .nowPlayingButton,
                controlID: self.content.identity
            ) {

                try await action(context)
            }
            return
        }

        switch self.content.kind {

        case .playbackRate:
            self.playback.cyclePlaybackRate()

        case .shuffle:
            self.playback.toggleShuffle()

        case .repeat:
            self.playback.cycleRepeatMode()

        default:
            break
        }
    }

    func cancel() {

        self.active = false
        self.actionState.cancel()
    }

    /// Retires a replaced native button while transferring its busy state.
    func retire() {

        self.active = false
    }

    private func updateAvailability() {

        self.actionState.update(
            enabled: self.content.isEnabled,
            policy: self.content.repeatPolicy
        ) { [weak self] enabled in

            if let self, self.item.isEnabled != enabled {

                self.item.isEnabled = enabled
            }
        }
    }
}

private extension CarPlayMountedNowPlayingButton {

    func makeNative() -> CPNowPlayingButton {

        let handler: (CPNowPlayingButton) -> Void = { [weak self] _ in

            Task { @MainActor [weak self] in

                self?.activate()
            }
        }
        if let image = self.content.image {

            return CPNowPlayingImageButton(image: image, handler: handler)
        }

        switch self.content.kind {

        case .playbackRate:
            return CPNowPlayingPlaybackRateButton(handler: handler)

        case .shuffle:
            return CPNowPlayingShuffleButton(handler: handler)

        case .repeat:
            return CPNowPlayingRepeatButton(handler: handler)

        case .addToLibrary:
            return CPNowPlayingAddToLibraryButton(handler: handler)

        case .custom,
             .more:
            return CPNowPlayingMoreButton(handler: handler)
        }
    }
}
