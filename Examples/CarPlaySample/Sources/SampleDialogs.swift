// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder

@MainActor
enum SampleDialogs {

    static var about: CarPlayAlert {

        CarPlayAlert(
            "CarPlayBuilder Sample\n"
                + "All demo content is bundled or simulated offline."
        ) {

            CarPlayAlertAction("Close", style: .cancel)
        }
    }

    static func clearSaved(_ model: SampleModel) -> CarPlayActionSheet {

        CarPlayActionSheet(
            "Clear Saved?",
            message: "Remove your saved tracks from this demo session."
        ) {

            CarPlayAlertAction("Clear Saved", style: .destructive) { context in

                model.clearSaved()
                try await context.selectTab(id: "saved")
            }
            CarPlayAlertAction("Cancel", style: .cancel)
        }
    }
}
