// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

struct SampleTrack: Identifiable, Equatable, Sendable {

    let id: String
    let title: String
    let subtitle: String
    let symbol: String

    static let all = [
        SampleTrack(
            id: "morning",
            title: "Morning drive",
            subtitle: "A bright, looping demo melody",
            symbol: "sun.max"
        ),
        SampleTrack(
            id: "coast",
            title: "Coastal road",
            subtitle: "A mellow, looping demo melody",
            symbol: "water.waves"
        ),
        SampleTrack(
            id: "night",
            title: "Night ride",
            subtitle: "A quiet, looping demo melody",
            symbol: "moon.stars"
        )
    ]
}
