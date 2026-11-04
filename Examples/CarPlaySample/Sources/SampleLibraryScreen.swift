// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder

struct SampleLibraryScreen: CarPlayTemplate {

    let model: SampleModel
    let savedOnly: Bool

    var body: some CarPlayTemplate {

        CarPlayList(self.savedOnly ? "Saved" : "Library") {

            if !self.savedOnly {

                self.playbackSection
            }
            CarPlaySection(self.savedOnly ? "Saved tracks" : "Demo tracks") {

                for track in self.tracks {

                    CarPlayNavigationLink(
                        track.title,
                        detail: track.subtitle,
                        image: SampleArtwork.image(for: track)
                    ) {

                        SampleTrackScreen(model: self.model, track: track)
                    }
                    .id(track.id)
                    .playback(
                        isPlaying: self.model.isPlaying
                            && self.model.currentTrack?.id == track.id
                    )
                }
            }
            .id("tracks")
        }
        .emptyView(
            titleVariants: ["No saved tracks"],
            subtitleVariants: ["Save a track from Library or your iPhone."]
        )
    }

    private var tracks: [SampleTrack] {

        self.savedOnly ? self.model.savedTracks : self.model.tracks
    }

    private var playbackSection: CarPlaySection {

        CarPlaySection {

            CarPlayRow(
                "Now Playing",
                detail: self.model.currentTrack?.title ?? "Choose a demo track"
            ) { context in

                try await context.showNowPlaying()
            }
            .id("now-playing")
            .disabled(self.model.currentTrack == nil)
            if let errorMessage = self.model.errorMessage {

                CarPlayRow("Playback unavailable", detail: errorMessage).disabled()
            }
        }
        .id("playback")
    }
}
