// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

/// Covers local recovery, propagation, accepted handlers, and task lifetimes.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayErrorRecoveryTests {

    @Test(arguments: [CarPlayErrorDisposition.handled, .unhandled])
    func `selection errors stop locally or reach the host`(
        disposition: CarPlayErrorDisposition
    ) async throws {

        var local = 0
        var fallback = 0
        let node = try self.mount(self.failingList.onError { error, _ in

            #expect(error is RecoveryFailure)
            local += 1
            return disposition
        }, onError: { _ in fallback += 1 })
        try await self.tap(node.template)
        #expect(local == 1)
        #expect(fallback == (disposition == .handled ? 0 : 1))
        node.cancel()
    }

    @Test
    func `inner handlers run before outer handlers and stop after recovery`(
    ) async throws {

        var calls: [String] = []
        let node = try self.mount(self.failingList.onError { _, _ in

            calls.append("inner")
            return .unhandled
        }.onError { _, _ in

            calls.append("outer")
            return .handled
        }.onError { _, _ in

            Issue.record("Propagation should have stopped")
            return .unhandled
        })
        try await self.tap(node.template)
        #expect(calls == ["inner", "outer"])
        node.cancel()
    }

    @Test(arguments: [false, true])
    func `running actions use updated handlers or fall back after removal`(
        remove: Bool
    ) async throws {

        let release = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        let initial = CarPlayList {

            CarPlaySection {

                CarPlayRow("Wait") { _ in

                    var iterator = release.stream.makeAsyncIterator()
                    _ = await iterator.next()
                    throw RecoveryFailure.expected
                }
            }
        }.onError { _, _ in

            Issue.record("Stale handler")
            return .handled
        }
        var calls: [String] = []
        let node = try self.mount(initial, onError: { _ in calls.append("host") })
        try self.beginTap(node.template) { completed.continuation.yield(()) }
        try node.update(self.replacement(remove: remove) {

            calls.append("updated")
        }._resolve())
        release.continuation.yield(())
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(calls == [remove ? "host" : "updated"])
        node.cancel()
    }

    @Test(arguments: [CarPlayErrorDisposition.handled, .unhandled])
    func `tab actions propagate through their container before reaching the host`(
        disposition: CarPlayErrorDisposition
    ) async throws {

        var calls: [String] = []
        let node = try self.mount(CarPlayTabs {

            CarPlayTab(id: "tab", label: .title("Library")) {

                self.failingList.onError { _, _ in

                    calls.append("tab")
                    return .unhandled
                }
            }
        }.onError { _, _ in

            calls.append("container")
            return disposition
        }, onError: { _ in calls.append("host") })
        let tabs = try #require(node.template as? CPTabBarTemplate)
        try await self.tap(tabs.templates[0])
        let expected = disposition == .handled
            ? ["tab", "container"] : ["tab", "container", "host"]
        #expect(calls == expected)
        node.cancel()
    }

    @Test
    func `lifecycle failures use local recovery`() async throws {

        let recovered = AsyncStream<Void>.makeStream()
        let node = try self.mount(CarPlayList {}.task {

            throw RecoveryFailure.expected
        }.onError { error, _ in

            #expect(error is RecoveryFailure)
            recovered.continuation.yield(())
            return .handled
        })
        node.setVisible(true, for: node.template)
        var iterator = recovered.stream.makeAsyncIterator()
        _ = await iterator.next()
        node.cancel()
    }

    @Test
    func `normal cancellation bypasses both local and host handlers`() async throws {

        let node = try self.mount(CarPlayList {

            CarPlaySection {

                CarPlayRow("Cancel") { _ in throw CancellationError() }
            }
        }.onError { _, _ in

            Issue.record("Cancellation reached recovery")
            return .unhandled
        })
        try await self.tap(node.template)
        node.cancel()
    }

    @Test
    func `rejected observed updates use accepted handlers and can recover`(
    ) async throws {

        let model = RecoveryModel()
        let recovered = AsyncStream<Void>.makeStream()
        let screen = try self.recoveringScreen(model) {

            recovered.continuation.yield(())
        }
        let grid = try #require(screen.node.template as? CPGridTemplate)
        let original = grid.gridButtons[0]
        model.count = 9
        var iterator = recovered.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(model.count == 1)
        #expect(grid.gridButtons.count == 1)
        #expect(grid.gridButtons[0] === original)
        screen.cancel()
    }

    @Test
    func `explicit navigation failures throw without invoking recovery`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let host = CarPlayHost(interface: interface, onError: { _ in

            Issue.record("Explicit failure reached host")
        }) {

            CarPlayList {}.onError { _, _ in

                Issue.record("Explicit failure reached screen")
                return .handled
            }._resolve()
        }
        try await host.connect()
        await #expect(throws: CarPlayError.self) {

            try await host.context.push { CarPlayGrid {} }
        }
        host.disconnect()
    }

    @Test
    func `teardown inside recovery stops further propagation`() {

        var calls: [String] = []
        let router = CarPlayErrorRouter(context: .init(), onError: { _, _ in

            calls.append("host")
        })
        router.update([{ _, _, _ in

            calls.append("local")
            router.cancel()
            return .unhandled
        }])
        router.report(RecoveryFailure.expected, context: .init(source: .action))
        router.report(RecoveryFailure.expected, context: .init(source: .action))
        #expect(calls == ["local"])
    }

    @Test
    func `recovery receives the owning scene navigation context`() async throws {

        let interface = CarPlayTestInterface()
        var received: CarPlayContext?
        let host = CarPlayHost(interface: interface, onError: { _ in

            Issue.record("Unexpected host error")
        }) {

            self.failingList.onError { _, context in

                received = context
                return .handled
            }._resolve()
        }
        try await host.connect()
        let template = try #require(interface.templates.first)
        try await self.tap(template)
        #expect(received?.host === host)
        host.disconnect()
    }
}

private extension CarPlayErrorRecoveryTests {

    var failingList: CarPlayList {

        CarPlayList {

            CarPlaySection {

                CarPlayRow("Fail") { _ in throw RecoveryFailure.expected }
            }
        }
    }

    func replacement(
        remove: Bool,
        recovered: @escaping CarPlayCallback
    ) -> AnyCarPlayTemplate {

        if remove {

            return AnyCarPlayTemplate(self.failingList)
        }
        return AnyCarPlayTemplate(self.failingList.onError { _, _ in

            recovered()
            return .handled
        })
    }

    func mount(
        _ template: some CarPlayTemplate,
        onError: @escaping CarPlayErrorHandler = {
            Issue.record("Unexpected host error: \($0)")
        }
    ) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: template._resolve(),
            context: .init(),
            onError: onError
        )
    }

    func tap(_ template: CPTemplate) async throws {

        let completed = AsyncStream<Void>.makeStream()
        try self.beginTap(template) { completed.continuation.yield(()) }
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func beginTap(
        _ template: CPTemplate,
        completion: @escaping CarPlayCallback
    ) throws {

        let list = try #require(template as? CPListTemplate)
        let row = try #require(list.sections[0].items[0] as? CPListItem)
        let handler = try #require(row.handler)
        handler(row, completion)
    }

    func recoveringScreen(
        _ model: RecoveryModel,
        recovered: @escaping CarPlayCallback
    ) throws -> CarPlayScreen {

        let image = UIImage()
        return try CarPlayScreen(content: {

            let rejected = model.count > 8
            return CarPlayGrid {

                for id in 0 ..< model.count {

                    CarPlayButton("Button", image: image) { _ in }.id(id)
                }
            }.onError { error, _ in

                #expect(error is CarPlayError)
                #expect(!rejected, "Rejected handlers must not replace valid ones")
                model.count = 1
                recovered()
                return .handled
            }._resolve()
        }, context: .init(), onError: { Issue.record("Host error: \($0)") })
    }

    @MainActor
    @Observable
    final class RecoveryModel {

        var count = 1
    }

    enum RecoveryFailure: Error {

        case expected
    }
}
