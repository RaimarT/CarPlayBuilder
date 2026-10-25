// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

extension CarPlayTemplateContent {

    /// The renderer’s supported template kinds and their resolved child values.
    indirect enum Kind {

        case list(String?, [CarPlaySection])
        case grid(String?, [CarPlayButton])
        case tabs([Tab])
        case nowPlaying
    }
}
