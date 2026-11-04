// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import SwiftUI

struct SampleContentView: View {

    let model: SampleModel

    var body: some View {

        NavigationStack {

            List {

                Section {

                    Text("Open CarPlay to browse the same library. "
                         + "Saving tracks here updates the car's Saved tab.")
                }
                self.playbackSection
                Section("Demo tracks") {

                    ForEach(self.model.tracks) { track in

                        SampleTrackRow(model: self.model, track: track)
                    }
                }
                if let errorMessage = self.model.errorMessage {

                    Section("Playback unavailable") {

                        Text(errorMessage)
                    }
                }
            }
            .navigationTitle("CarPlay Sample")
        }
    }

    private var playbackSection: some View {

        Section("Now Playing") {

            if let track = self.model.currentTrack {

                Label(track.title, systemImage: track.symbol)
                Text("Generated demo audio loops until paused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(
                    self.model.isPlaying ? "Pause" : "Play",
                    systemImage: self.model.isPlaying ? "pause.fill" : "play.fill"
                ) {

                    self.model.togglePlayback()
                }
                Button("Next track", systemImage: "forward.end.fill") {

                    self.model.nextTrack()
                }
            } else {

                Text("Choose a track to start playback.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SampleTrackRow: View {

    let model: SampleModel
    let track: SampleTrack

    var body: some View {

        HStack {

            Button {

                self.model.play(self.track)
            } label: {

                Label {

                    VStack(alignment: .leading) {

                        Text(self.track.title)
                        Text(self.track.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {

                    Image(systemName: self.track.symbol)
                }
            }
            Spacer()
            Button(
                self.isSaved ? "Remove from Saved" : "Save track",
                systemImage: self.isSaved ? "bookmark.fill" : "bookmark"
            ) {

                self.model.toggleSaved(self.track)
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
    }

    private var isSaved: Bool {

        self.model.savedIDs.contains(self.track.id)
    }
}
