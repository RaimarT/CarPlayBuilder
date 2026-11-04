// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder

struct SampleTrackScreen: CarPlayTemplate {

    let model: SampleModel
    let track: SampleTrack

    var body: some CarPlayTemplate {

        self.list
            .trailingBarButtons {

                CarPlayBarButton(self.isSaved ? "Unsave" : "Save") { _ in

                    self.model.toggleSaved(self.track)
                }
                .id("save-toolbar")
                CarPlayBarButton("About") { context in

                    try await context.present(SampleDialogs.about)
                }
                .id("about-toolbar")
            }
    }

    private var list: CarPlayList {

        CarPlayList(self.track.title) {

            CarPlaySection("Bundled demo audio") {

                CarPlayRow("Play", detail: self.track.subtitle) { context in

                    self.model.play(self.track)

                    guard self.model.isPlaying else {

                        return
                    }

                    try await context.showNowPlaying()
                }
                .id("play")
                CarPlayRow(self.isSaved ? "Remove from Saved" : "Save track") { _ in

                    self.model.toggleSaved(self.track)
                }
                .id("save")
                if let errorMessage = self.model.errorMessage {

                    CarPlayRow("Playback unavailable", detail: errorMessage)
                        .disabled()
                }
            }
        }
    }

    private var isSaved: Bool {

        self.model.savedIDs.contains(self.track.id)
    }
}
