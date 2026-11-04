// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import SwiftUI

@main
struct CarPlaySampleApp: App {

    @State private var model = SampleModel.shared

    var body: some Scene {

        WindowGroup {

            SampleContentView(model: self.model)
        }
    }
}
