// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers toolbar validation, identity retention, and stale-action cleanup.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayToolbarTests {

    @Test
    func `toolbar identity survives reordering and updates appearance`() throws {

        let image = UIImage()
        let node = try self.mount(self.list([1, 2], image: image, disabled: false))
        let list = try #require(node.template as? CPListTemplate)
        let original = list.leadingNavigationBarButtons[0]
        try node.update(self.list([2, 1], image: image, disabled: true)._resolve())
        #expect(list.leadingNavigationBarButtons[1] === original)
        #expect(!original.isEnabled)
        #expect(list.trailingNavigationBarButtons[0].image === image)
        try node.update(CarPlayList {}._resolve())
        #expect(list.leadingNavigationBarButtons.isEmpty)
        #expect(list.trailingNavigationBarButtons.isEmpty)
        node.cancel()
    }

    @Test
    func `mounted bar button uses the latest action and stops after cancellation`(
    ) async {

        let completed = AsyncStream<Void>.makeStream()
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        var calls = 0
        let mounted = CarPlayMountedBarButton(
            content: CarPlayBarButton("Old") { _ in Issue.record("Stale action") },
            context: .init(),
            scope: scope
        )
        mounted.update(CarPlayBarButton("New") { _ in

            calls += 1
            completed.continuation.yield(())
        })
        #expect(mounted.item.title == "New")
        mounted.activate()
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        mounted.update(CarPlayBarButton("Disabled") { _ in calls += 1 }.disabled())
        mounted.activate()
        mounted.cancel()
        mounted.activate()
        #expect(calls == 1)
        scope.cancel()
    }

    @Test
    func `bar button can switch between text and image and report action errors`(
    ) async {

        let failed = AsyncStream<Void>.makeStream()
        let scope = CarPlayTaskScope(onError: { _ in failed.continuation.yield(()) })
        let image = UIImage()
        let mounted = CarPlayMountedBarButton(
            content: CarPlayBarButton("Text") { _ in },
            context: .init(),
            scope: scope
        )
        let original = mounted.item
        mounted
            .update(CarPlayBarButton(image: image) { _ in
                throw ToolbarError.expected
            })
        #expect(mounted.item === original)
        #expect(original.title == nil)
        #expect(original.image === image)
        mounted.activate()
        var iterator = failed.stream.makeAsyncIterator()
        _ = await iterator.next()
        scope.cancel()
    }

    @Test
    func `toolbar limits duplicate IDs and unsupported placements are rejected`() {

        let invalid: [AnyCarPlayTemplate] = [
            AnyCarPlayTemplate(CarPlayList {}.leadingBarButtons {

                for _ in 0 ..< 3 {

                    CarPlayBarButton("Too many") { _ in }
                }
            }),
            AnyCarPlayTemplate(CarPlayList {}.trailingBarButtons {

                CarPlayBarButton("One") { _ in }.id(1)
                CarPlayBarButton("Two") { _ in }.id(1)
            }),
            AnyCarPlayTemplate(CarPlayList {}.leadingBarButtons {

                CarPlayBarButton("") { _ in }
            }),
            AnyCarPlayTemplate(CarPlayNowPlaying().leadingBarButtons {

                CarPlayBarButton("Invalid") { _ in }
            }),
            AnyCarPlayTemplate(CarPlayTabs {

                CarPlayTab(id: 1, label: .title("Tab")) {

                    CarPlayList {}
                        .trailingBarButtons { CarPlayBarButton("No") { _ in } }
                }
            })
        ]
        for template in invalid {

            #expect(throws: CarPlayError.self) { try self.mount(template) }
        }
    }

    @Test
    func `grid supports toolbar composition`() throws {

        let node = try self.mount(CarPlayGrid {

            CarPlayButton("Grid", image: UIImage()) { _ in }
        }.trailingBarButtons { CarPlayBarButton("Refresh") { _ in } })
        let grid = try #require(node.template as? CPGridTemplate)
        #expect(grid.trailingNavigationBarButtons[0].title == "Refresh")
    }
}

private extension CarPlayToolbarTests {

    func list(_ ids: [Int], image: UIImage, disabled: Bool) -> some CarPlayTemplate {

        CarPlayList {}.leadingBarButtons {

            for id in ids {

                CarPlayBarButton("\(id)") { _ in }.id(id).disabled(disabled)
            }
        }.trailingBarButtons {

            CarPlayBarButton(image: image) { _ in }
        }
    }

    func mount(_ template: some CarPlayTemplate) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: { Issue.record("Error: \($0)") }
        )
    }
}

private extension CarPlayToolbarTests {

    enum ToolbarError: Error {

        case expected
    }
}
