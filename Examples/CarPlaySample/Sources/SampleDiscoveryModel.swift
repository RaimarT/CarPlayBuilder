// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlayBuilder
import Foundation

@MainActor
final class SampleDiscoveryModel {

    let scenario: SampleDiscoveryScenario
    let resource: CarPlayResource<[SampleTrack]>

    init(scenario: SampleDiscoveryScenario) {

        self.scenario = scenario
        // The resource serializes its main-actor loader, including retries.
        var attempts = 0
        self.resource = CarPlayResource {

            attempts += 1
            try await Task.sleep(for: .seconds(1))
            try Task.checkCancellation()

            if scenario == .retry, attempts == 1 {

                throw URLError(.notConnectedToInternet)
            }

            return scenario == .empty ? [] : SampleTrack.all
        }
    }
}
