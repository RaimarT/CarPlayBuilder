// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder
import UIKit

struct SampleBrowseScreen: CarPlayTemplate {

    let model: SampleModel

    var body: some CarPlayTemplate {

        // Keep grids at tab roots for compatibility with iOS 18 audio apps.
        CarPlayGrid("Browse") {

            self.tabButton("Library", symbol: "music.note.list", tab: "library")
            self.tabButton("Saved", symbol: "bookmark", tab: "saved")
            self.discoveryButton(.loaded, symbol: "sparkles")
            self.discoveryButton(.empty, symbol: "tray")
            self.discoveryButton(.retry, symbol: "arrow.clockwise")
            self.artworkButton
            CarPlayButton("Clear Saved", image: Self.icon("trash")) { context in

                try await context.present(SampleDialogs.clearSaved(self.model))
            }
            .id("clear-saved")
            .disabled(self.model.savedIDs.isEmpty)
            CarPlayButton("About", image: Self.icon("info.circle")) { context in

                try await context.present(SampleDialogs.about)
            }
            .id("about")
        }
    }

    private func tabButton(
        _ title: String,
        symbol: String,
        tab: String
    ) -> CarPlayButton {

        CarPlayButton(title, image: Self.icon(symbol)) { context in

            try await context.selectTab(id: tab)
        }
        .id(tab)
    }

    private func discoveryButton(
        _ scenario: SampleDiscoveryScenario,
        symbol: String
    ) -> CarPlayButton {

        CarPlayButton(scenario.title, image: Self.icon(symbol)) { context in

            let discovery = SampleDiscoveryModel(scenario: scenario)
            try await context.push {

                SampleDiscoveryScreen(model: self.model, discovery: discovery)
            }
        }
        .id(scenario)
    }

    private var artworkButton: CarPlayButton {

        CarPlayButton("Artwork", image: Self.icon("square.grid.2x2")) { context in

            if #available(iOS 26, *) {

                try await context.push {

                    SampleArtworkScreen(model: self.model)
                }
            } else {

                try await context.present(CarPlayAlert("Artwork needs iOS 26") {

                    CarPlayAlertAction("Close", style: .cancel)
                })
            }
        }
        .id("artwork")
    }

    private static func icon(_ name: String) -> UIImage {

        UIImage(systemName: name) ?? UIImage()
    }
}
