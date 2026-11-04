// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import AVFAudio
import Foundation
import MediaPlayer
import Observation

@MainActor
@Observable
final class SampleModel {

    /// UIKit creates the CarPlay delegate. Both scenes use this app-owned model.
    static let shared = SampleModel()

    let tracks = SampleTrack.all
    private(set) var savedIDs: Set<String> = []
    private(set) var currentTrack: SampleTrack?
    private(set) var isPlaying = false
    var errorMessage: String?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var commandTargets: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {

        self.registerRemoteCommands()
        self.observeAudioSession()
    }

    isolated deinit {

        for (command, target) in self.commandTargets {

            command.removeTarget(target)
        }
        for observer in self.observers {

            NotificationCenter.default.removeObserver(observer)
        }
    }

    var savedTracks: [SampleTrack] {

        self.tracks.filter { self.savedIDs.contains($0.id) }
    }

    func toggleSaved(_ track: SampleTrack) {

        if self.savedIDs.contains(track.id) {

            self.savedIDs.remove(track.id)
        } else {

            self.savedIDs.insert(track.id)
        }
    }

    func clearSaved() {

        self.savedIDs.removeAll()
    }

    func play(_ track: SampleTrack) {

        self.errorMessage = nil

        do {

            try self.startPlayback(track)
        } catch {

            self.pause()
            self.errorMessage = error.localizedDescription
        }
    }

    func togglePlayback() {

        if self.isPlaying {

            self.pause()
        } else {

            self.resume()
        }
    }

    func resume() {

        guard let player else {

            return
        }

        do {

            try self.activateAudioSession()

            guard player.play() else {

                throw SamplePlaybackError.couldNotStart
            }

            self.isPlaying = true
            self.errorMessage = nil
            self.updateNowPlaying()
        } catch {

            self.errorMessage = error.localizedDescription
        }
    }

    func pause() {

        self.player?.pause()
        self.isPlaying = false
        self.updateNowPlaying()

        do {

            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {

            self.errorMessage = error.localizedDescription
        }
    }

    func nextTrack() {

        let index = self.tracks.firstIndex { $0.id == self.currentTrack?.id }
        self.play(self.tracks[((index ?? -1) + 1) % self.tracks.count])
    }

    private func startPlayback(_ track: SampleTrack) throws {

        let player = try self.makePlayer(track)
        try self.activateAudioSession()
        self.player?.stop()
        self.player = player
        self.currentTrack = track

        guard player.play() else {

            throw SamplePlaybackError.couldNotStart
        }

        self.isPlaying = true
        self.updateNowPlaying()
    }

    private func activateAudioSession() throws {

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func makePlayer(_ track: SampleTrack) throws -> AVAudioPlayer {

        guard let url = Bundle.main.url(forResource: track.id, withExtension: "wav")
        else {

            throw SamplePlaybackError.missingAudio
        }

        let player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = -1
        player.volume = 0.35

        return player
    }

    private func updateNowPlaying() {

        guard let currentTrack else {

            return
        }

        // These generated loops have no endpoint or seek controls.
        let image = SampleArtwork.image(for: currentTrack)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrack.title,
            MPMediaItemPropertyArtist: "CarPlayBuilder Sample",
            MPMediaItemPropertyAlbumTitle: "Bundled demo loops",
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(boundsSize: image.size) {

                _ in image
            },
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: self.isPlaying ? 1.0 : 0.0
        ]
    }

    private func registerRemoteCommands() {

        let center = MPRemoteCommandCenter.shared()
        self.register(center.playCommand) { [weak self] in

            self?.resume()
        }
        self.register(center.pauseCommand) { [weak self] in

            self?.pause()
        }
        self.register(center.togglePlayPauseCommand) { [weak self] in

            self?.togglePlayback()
        }
        self.register(center.nextTrackCommand) { [weak self] in

            self?.nextTrack()
        }
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
    }

    private func register(
        _ command: MPRemoteCommand,
        action: @escaping @MainActor @Sendable () -> Void
    ) {

        command.isEnabled = true
        let target = command.addTarget { _ in

            // MediaPlayer may deliver commands outside the main actor.
            Task { @MainActor in

                action()
            }
            return .success
        }
        self.commandTargets.append((command, target))
    }

    private func observeAudioSession() {

        self.observe(
            AVAudioSession.interruptionNotification,
            key: AVAudioSessionInterruptionTypeKey,
            pausingValue: AVAudioSession.InterruptionType.began.rawValue
        )
        let unplugged = AVAudioSession.RouteChangeReason.oldDeviceUnavailable
        self.observe(
            AVAudioSession.routeChangeNotification,
            key: AVAudioSessionRouteChangeReasonKey,
            pausingValue: unplugged.rawValue
        )
    }

    private func observe(
        _ name: Notification.Name,
        key: String,
        pausingValue: UInt
    ) {

        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] notification in

            guard notification.userInfo?[key] as? UInt == pausingValue else {

                return
            }

            Task { @MainActor [weak self] in

                self?.pause()
            }
        }
        self.observers.append(observer)
    }
}
