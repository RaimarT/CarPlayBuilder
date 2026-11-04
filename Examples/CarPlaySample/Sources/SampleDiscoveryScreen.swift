// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder

struct SampleDiscoveryScreen: CarPlayTemplate {

    let model: SampleModel
    let discovery: SampleDiscoveryModel

    var body: some CarPlayTemplate {

        self.list
            .loadingState(
                self.discovery.resource.state,
                isEmpty: self.discovery.resource.value?.isEmpty != false,
                retainsContentDuringRefresh: true,
                retry: { await self.discovery.resource.reload() }
            )
            .task {

                await self.discovery.resource.loadIfNeeded()
            }
            .onDisappear {

                // This resource belongs to this demo screen, not the app.
                self.discovery.resource.cancel()
            }
            .trailingBarButtons {

                CarPlayBarButton("Refresh") { _ in

                    await self.discovery.resource.reload()
                }
                .id("refresh")
                .repeatedActionPolicy(.ignoreWhileRunning)
            }
    }

    private var list: CarPlayList {

        CarPlayList(self.discovery.scenario.title) {

            CarPlaySection("Simulated discovery") {

                for track in self.discovery.resource.value ?? [] {

                    CarPlayNavigationLink(track.title, detail: track.subtitle) {

                        SampleTrackScreen(model: self.model, track: track)
                    }
                    .id(track.id)
                }
            }
            .id("discovery")
        }
    }
}
