// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

extension CarPlayMountedTemplate {

    var navigationScreen: CarPlayNavigationScreen {

        switch self.content.kind {

        case let .list(title, _):
            .init(id: self.screenID, kind: .list, title: title)

        case let .grid(title, _):
            .init(id: self.screenID, kind: .grid, title: title)

        case .tabs:
            .init(id: self.screenID, kind: .tabs, title: nil)

        case .nowPlaying:
            .init(id: self.screenID, kind: .nowPlaying, title: nil)
        }
    }
}
