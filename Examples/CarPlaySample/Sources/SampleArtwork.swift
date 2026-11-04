// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import UIKit

@MainActor
enum SampleArtwork {

    private static let images = Dictionary(
        uniqueKeysWithValues: SampleTrack.all.map { track in

            (track.id, Self.render(track))
        }
    )

    static func image(for track: SampleTrack) -> UIImage {

        self.images[track.id] ?? UIImage()
    }

    private static func render(_ track: SampleTrack) -> UIImage {

        let size = CGSize(width: 240, height: 240)
        return UIGraphicsImageRenderer(size: size).image { context in

            self.color(for: track).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let configuration = UIImage.SymbolConfiguration(pointSize: 96)
            let symbol = UIImage(
                systemName: track.symbol,
                withConfiguration: configuration
            )?.withTintColor(.white, renderingMode: .alwaysOriginal)
            symbol?.draw(in: CGRect(x: 64, y: 64, width: 112, height: 112))
        }
    }

    private static func color(for track: SampleTrack) -> UIColor {

        switch track.id {

        case "morning":
            .systemOrange
        case "coast":
            .systemTeal
        default:
            .systemIndigo
        }
    }
}
