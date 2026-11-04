// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder

struct SampleRootScreen: CarPlayTemplate {

    let model: SampleModel

    var body: some CarPlayTemplate {

        CarPlayTabs {

            CarPlayTab(id: "library", label: .title("Library")) {

                SampleLibraryScreen(model: self.model, savedOnly: false)
            }
            CarPlayTab(id: "browse", label: .title("Browse")) {

                SampleBrowseScreen(model: self.model)
            }
            CarPlayTab(id: "saved", label: .title("Saved")) {

                SampleLibraryScreen(model: self.model, savedOnly: true)
            }
            .badge(!self.model.savedIDs.isEmpty)
        }
    }
}
