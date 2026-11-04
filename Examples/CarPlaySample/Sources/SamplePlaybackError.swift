// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation

enum SamplePlaybackError: LocalizedError {

    case missingAudio
    case couldNotStart

    var errorDescription: String? {

        switch self {

        case .missingAudio:
            "The bundled demo audio could not be found."
        case .couldNotStart:
            "The audio player could not start playback."
        }
    }
}
