// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder

@available(iOS 26, *)
struct SampleArtworkScreen: CarPlayTemplate {

    let model: SampleModel

    var body: some CarPlayTemplate {

        if #available(iOS 26.4, *) {

            self.list.listHeader(self.header)
        } else {

            self.list
        }
    }

    private var list: CarPlayList {

        CarPlayList("Artwork") {

            CarPlaySection("Featured loops") {

                CarPlayImageRow("Choose a drive", style: .imageGrid) {

                    for track in self.model.tracks {

                        CarPlayImageElement(
                            track.title,
                            subtitle: track.subtitle,
                            image: SampleArtwork.image(for: track)
                        ) { context in

                            try await context.push {

                                SampleTrackScreen(model: self.model, track: track)
                            }
                        }
                        .id(track.id)
                    }
                }
                .id("featured-artwork")
            }
        }
    }

    @available(iOS 26.4, *)
    private var header: CarPlayListHeader {

        let track = SampleTrack.all[0]
        return CarPlayListHeader(
            "Made for the drive",
            subtitle: "Original offline demo loops",
            image: SampleArtwork.image(for: track)
        ) {

            CarPlayListHeaderButton("Play") { context in

                self.model.play(track)

                guard self.model.isPlaying else {

                    return
                }

                try await context.showNowPlaying()
            }
            .id("play-featured")
        }
    }
}
