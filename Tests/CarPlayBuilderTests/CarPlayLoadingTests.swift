// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Foundation
import Testing
@testable import CarPlayBuilder

/// Covers loading, failure, empty, and retry presentation on lists and grids.
@MainActor
struct CarPlayLoadingTests {

    @Test
    func `list presents loading empty failure and loaded content`() {

        let cases: [(CarPlayLoadState, Bool, String)] = [
            (.idle, true, "Loading…"),
            (.loading, false, "Loading…"),
            (.loaded, true, "No items available"),
            (.failed(LoadingFailure.expected), false, "Unable to load"),
            (.loaded, false, "Content")
        ]
        for (state, isEmpty, title) in cases {

            let content = self.list.loadingState(state, isEmpty: isEmpty)._resolve()

            guard case let .list(_, sections) = content.kind else {

                Issue.record("Loading changed the template kind")
                continue
            }

            #expect(sections[0].rows[0].title == title)
            if case .failed = state {

                #expect(sections[0].rows[0].detail == "Original failure")
            }
        }
    }

    @Test
    func `grid offers an enabled retry after failure`() async throws {

        var retried = false
        let content = CarPlayGrid("Grid") {}.loadingState(
            .failed(LoadingFailure.expected),
            retry: { retried = true }
        )._resolve()

        guard case let .grid(title, buttons) = content.kind else {

            Issue.record("Loading changed the template kind")
            return
        }

        #expect(title == "Grid")
        #expect(buttons.count == 2)
        #expect(!buttons[0].isEnabled)
        #expect(buttons[1].isEnabled)
        try await buttons[1].action(.init())
        #expect(retried)
    }

    @Test
    func `loading preserves lifecycle tasks and hides retry`() {

        let content = self.list.task {}.loadingState(
            .loading,
            retry: {}
        )._resolve()
        #expect(content.tasks.count == 1)

        guard case let .list(_, sections) = content.kind else {

            Issue.record("Expected a list")
            return
        }

        #expect(sections[0].rows.count == 1)
        #expect(sections[0].rows[0].action == nil)
    }

    private var list: CarPlayList {

        CarPlayList("Library") {

            CarPlaySection {

                CarPlayRow("Content")
            }
        }
    }

    @Test
    func `grid loading and empty states provide status artwork and retry policy`() {

        for state in [CarPlayLoadState.idle, .loading, .loaded] {

            let content = CarPlayGrid {}.loadingState(
                state,
                isEmpty: true,
                retry: {}
            )._resolve()

            guard case let .grid(_, buttons) = content.kind else {

                Issue.record("Expected a grid")
                return
            }

            #expect(!buttons[0].isEnabled)
            if case .loaded = state {

                #expect(buttons.count == 2)
                #expect(buttons[0].titles == ["No items available"])
            } else {

                #expect(buttons.count == 1)
                #expect(buttons[0].titles == ["Loading…"])
            }
        }
    }
}

private extension CarPlayLoadingTests {

    enum LoadingFailure: LocalizedError {

        case expected
        var errorDescription: String? {

            "Original failure"
        }
    }
}
