// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

enum SampleDiscoveryScenario: Hashable, Sendable {

    case loaded
    case empty
    case retry

    var title: String {

        switch self {

        case .loaded:
            "Discover"
        case .empty:
            "Empty library"
        case .retry:
            "Offline & retry"
        }
    }
}
