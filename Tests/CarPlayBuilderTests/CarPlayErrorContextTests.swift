// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

/// Verifies origin metadata without changing error identity or recovery order.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayErrorContextTests {

    @Test
    func `tab failures retain child origin through legacy and contextual handlers`(
    ) async throws {

        let failure = ContextFailure()
        var origins: [UUID?] = []
        var calls: [String] = []
        let node = try CarPlayMountedTemplate(content: CarPlayTabs {

            CarPlayTab(id: "library", label: .title("Library")) {

                self.list(failure).onErrorWithContext { error, origin, _ in

                    #expect(error as? ContextFailure === failure)
                    #expect(origin.source == .action)
                    #expect(origin.control == .row)
                    #expect(origin.controlID == AnyHashable("play"))
                    #expect(origin.screenTitle == "Library")
                    origins.append(origin.screenID)
                    calls.append("child")
                    return .unhandled
                }
            }
        }.onError { _, _ in

            calls.append("legacy")
            return .unhandled
        }._resolve(), context: .init(), onErrorWithContext: { _, origin in

            origins.append(origin.screenID)
            calls.append("host")
        })
        let tabs = try #require(node.template as? CPTabBarTemplate)
        try await self.tap(tabs.templates[0])
        #expect(calls == ["child", "legacy", "host"])
        #expect(origins.count == 2 && origins[0] == origins[1])
        #expect(origins[0] != nil && origins[0] != node.screenID)
        node.cancel()
    }

    @Test
    func `lifecycle failures include task and mounted screen identity`(
    ) async throws {

        let reported = AsyncStream<CarPlayErrorContext>.makeStream()
        let node = try CarPlayMountedTemplate(
            content: CarPlayList("Downloads") {}
                .task(id: "refresh") { throw ContextFailure() }._resolve(),
            context: .init(),
            onErrorWithContext: { _, origin in

                reported.continuation.yield(origin)
            }
        )
        node.setVisible(true, for: node.template)
        var iterator = reported.stream.makeAsyncIterator()
        let origin = try #require(await iterator.next())
        #expect(origin.source == .lifecycleTask)
        #expect(origin.taskID == AnyHashable("refresh"))
        #expect(origin.screenID == node.screenID)
        #expect(origin.screenTitle == "Downloads")
        #expect(origin.control == nil)
        node.cancel()
    }

    @Test
    func `inflight actions retain original control IDs and use latest handlers`(
    ) async throws {

        let release = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        var received: CarPlayErrorContext?
        let node = try CarPlayMountedTemplate(content: CarPlayList("Library") {

            CarPlaySection {

                CarPlayRow("Play") { _ in

                    var iterator = release.stream.makeAsyncIterator()
                    _ = await iterator.next()
                    throw ContextFailure()
                }.id("original")
            }
        }._resolve(), context: .init())
        try self.beginTap(node.template) { completed.continuation.yield(()) }
        try node.update(self.list(ContextFailure()).onErrorWithContext {
            _, origin, _ in

            received = origin
            return .handled
        }._resolve())
        release.continuation.yield(())
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(received?.controlID == AnyHashable("original"))
        #expect(received?.screenID == node.screenID)
        node.cancel()
    }

    @Test
    func `observed rendering failures identify the accepted screen`() async throws {

        let model = ContextModel()
        let reported = AsyncStream<CarPlayErrorContext>.makeStream()
        let screen = try CarPlayScreen(content: {

            CarPlayGrid("Browse") {

                for id in 0 ..< model.count {

                    CarPlayButton("Item", image: UIImage()) { _ in }.id(id)
                }
            }._resolve()
        }, context: .init(), onErrorWithContext: { error, origin in

            #expect(error is CarPlayError)
            reported.continuation.yield(origin)
        })
        model.count = 9
        var iterator = reported.stream.makeAsyncIterator()
        let origin = try #require(await iterator.next())
        #expect(origin.source == .rendering)
        #expect(origin.screenTitle == "Browse")
        #expect(origin.screenID == screen.node.screenID)
        #expect(origin.controlID == nil && origin.taskID == nil)
        screen.cancel()
    }

    @Test
    func `modal errors reach contextual host handler with the action index`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let reported = AsyncStream<CarPlayErrorContext>.makeStream()
        let host = CarPlayHost(interface: interface, onError: { _ in

            Issue.record("Contextual callback must replace legacy fallback")
        }, onErrorWithContext: { _, origin in

            reported.continuation.yield(origin)
        }) { CarPlayList {}._resolve() }
        try await host.connect()
        try await host.context.present(CarPlayAlert("Problem") {

            CarPlayAlertAction("Retry") { _ in throw ContextFailure() }
        })
        let alert = try #require(interface.presentedTemplate as? CPAlertTemplate)
        alert.actions[0].handler(alert.actions[0])
        var iterator = reported.stream.makeAsyncIterator()
        let origin = try #require(await iterator.next())
        #expect(origin.source == .action)
        #expect(origin.control == .modalAction)
        #expect(origin.controlID == AnyHashable(0))
        #expect(origin.screenID == nil)
        host.disconnect()
    }

    @Test
    func `bar button actions report explicit IDs`() async throws {

        let reported = AsyncStream<CarPlayErrorContext>.makeStream()
        let scope = CarPlayTaskScope(onErrorWithContext: { _, origin in

            reported.continuation.yield(origin)
        })
        let button = CarPlayMountedBarButton(content: CarPlayBarButton("Retry") {
            _ in throw ContextFailure()
        }.id("retry"), context: .init(), scope: scope)
        button.activate()
        var iterator = reported.stream.makeAsyncIterator()
        let origin = try #require(await iterator.next())
        #expect(origin.control == .barButton)
        #expect(origin.controlID == AnyHashable("retry"))
        scope.cancel()
    }

    @Test
    func `handled contextual recovery suppresses legacy fallback`() async throws {

        let node = try CarPlayMountedTemplate(
            content: self.list(ContextFailure())
                .onErrorWithContext { _, origin, _ in

                    #expect(origin.control == .row)
                    return .handled
                }._resolve(),
            context: .init(),
            onError: { _ in

                Issue.record("Handled failure must stop propagation")
            }
        )
        try await self.tap(node.template)
        node.cancel()
    }
}

private extension CarPlayErrorContextTests {

    func list(_ failure: ContextFailure) -> some CarPlayTemplate {

        CarPlayList("Library") {

            CarPlaySection {

                CarPlayRow("Play") { _ in throw failure }.id("play")
            }
        }
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

    final class ContextFailure: Error {}

    @MainActor
    @Observable
    final class ContextModel {

        var count = 1
    }
}
