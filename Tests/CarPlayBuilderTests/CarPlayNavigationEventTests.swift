// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers accepted transitions, native reconciliation, and silent failures/no-ops.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayNavigationEventTests {

    @Test
    func `successful operations publish ordered immutable snapshots`() async throws {

        let probe = Probe()
        let host = probe.host()
        try await host.connect(animated: false)
        try await host.context.push(animated: true) { CarPlayList("One") {} }
        try await host.context.push { CarPlayGrid("Two") {

            CarPlayButton("Play", image: UIImage()) { _ in }
        } }
        try await host.context.pop()
        try await host.context.popToRoot()
        try await host.context.popToRoot()
        try await host.context.replaceRoot { CarPlayList("New root") {} }
        try await host.context
            .present(CarPlayAlert("Hello") { CarPlayAlertAction("OK") })
        try await host.context.dismiss()
        host.disconnect()
        host.disconnect()
        self.verifySequence(probe.events)
    }

    @Test(
        arguments: ["push", "pop", "popRoot", "root", "present", "dismiss"],
        [false, true]
    )
    func `rejected operations publish no event and can be retried`(
        operation: String,
        throwing: Bool
    ) async throws {

        let probe = Probe()
        let host = probe.host()
        try await host.connect()
        try await host.context.push { CarPlayList("Details") {} }
        if operation == "dismiss" {

            try await host.context
                .present(CarPlayAlert("Options") { CarPlayAlertAction("OK") })
        }
        let count = probe.events.count
        if throwing {

            probe.interface.failure = CarPlayError.presentationRejected
        } else {

            probe.interface.reject = operation
        }
        await #expect(throws: CarPlayError.self) {

            try await self.perform(operation, context: host.context)
        }
        #expect(probe.events.count == count)
        probe.interface.failure = nil
        try await self.perform(operation, context: host.context)
        #expect(probe.events.count == count + 1)
        host.disconnect()
    }

    @Test
    func `tab navigation reports its stack pop without duplicate events`(
    ) async throws {

        let probe = Probe()
        let host = CarPlayHost(interface: probe.interface, onNavigation: {

            probe.events.append($0)
            if $0.kind == .poppedToRoot {

                #expect(probe.interface.selected != nil)
            }
        }) {

            CarPlayTabs {

                CarPlayTab(id: "first", label: .title("First")) { CarPlayList {} }
                CarPlayTab(id: "second", label: .title("Second")) { CarPlayList {} }
            }._resolve()
        }
        try await host.connect()
        try await host.context.push { CarPlayList("Details") {} }
        try await host.context.selectTab(id: "second")
        try await host.context.selectTab(id: "first")
        #expect(probe.events.map(\.kind) == [.connected, .pushed, .poppedToRoot])
        #expect(probe.events.last?.current.stack.first?.kind == .tabs)
        host.disconnect()
    }

    @Test
    func `native Back reports once across duplicate delegate notifications`(
    ) async throws {

        let probe = Probe()
        let host = probe.host()
        try await host.connect()
        try await host.context.push { CarPlayList("Details") {} }
        let removed = try #require(probe.interface.templates.last)
        let root = try #require(probe.interface.templates.first)
        probe.interface.templates.removeLast()
        host.templateDidDisappear(removed, animated: true)
        host.templateDidAppear(root, animated: true)
        host.templateDidDisappear(removed, animated: true)
        #expect(probe.events.count == 3)
        #expect(probe.events.last?.kind == .popped)
        #expect(probe.events.last?.origin == .native)
        #expect(probe.events.last?.previous.stack.count == 2)
        #expect(probe.events.last?.current.stack.count == 1)
        host.disconnect()
        host.templateDidAppear(root, animated: false)
        #expect(probe.events.count == 4)
    }

    @Test
    func `native modal dismissal clears host state and preserves stack`(
    ) async throws {

        let probe = Probe()
        let host = probe.host()
        try await host.connect()
        try await host.context
            .present(CarPlayAlert("Alert") { CarPlayAlertAction("OK") })
        let modal = try #require(probe.interface.presentedTemplate)
        probe.interface.presentedTemplate = nil
        host.templateDidDisappear(modal, animated: true)
        #expect(probe.events.last?.kind == .modalDismissed)
        #expect(probe.events.last?.origin == .native)
        #expect(probe.events.last?.previous.stack == probe.events.last?.current
            .stack)
        try await host.context.push { CarPlayList("Next") {} }
        #expect(probe.events.last?.kind == .pushed)
        host.disconnect()
    }

    @Test(arguments: ["push", "root", "present"])
    func `disconnect invalidates awaited navigation without stale events`(
        operation: String
    ) async throws {

        let probe = Probe()
        let host = probe.host()
        try await host.connect()
        probe.interface.duringOperation = { _ in host.disconnect() }
        await #expect(throws: CarPlayError.self) {

            try await self.perform(operation, context: host.context)
        }
        #expect(probe.events.map(\.kind) == [.connected, .disconnected])
        #expect(probe.events.last?.current.stack.isEmpty == true)
    }

    @Test
    func `failed initial connection and repeated connect are silent`() async throws {

        let probe = Probe()
        let host = probe.host()
        probe.interface.reject = "root"
        await #expect(throws: CarPlayError.self) { try await host.connect() }
        #expect(probe.events.isEmpty)
        try await host.connect()
        try await host.connect()
        try await host.context.dismiss()
        try await host.context.popToRoot()
        #expect(probe.events.map(\.kind) == [.connected])
        host.disconnect()
    }

    @Test
    func `modal dismissal event precedes its action and subsequent navigation`(
    ) async throws {

        let probe = Probe()
        let host = probe.host()
        let completed = AsyncStream<Void>.makeStream()
        try await host.connect()
        try await host.context.present(CarPlayAlert("Continue") {

            CarPlayAlertAction("Open") { context in

                #expect(probe.events.last?.kind == .modalDismissed)
                try await context.push { CarPlayList("Next") {} }
                completed.continuation.yield(())
            }
        })
        let alert = try #require(probe.interface
            .presentedTemplate as? CPAlertTemplate)
        alert.actions[0].handler(alert.actions[0])
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(probe.events.map(\.kind) == [
            .connected,
            .modalPresented,
            .modalDismissed,
            .pushed
        ])
        host.disconnect()
    }

    @Test
    func `callbacks can disconnect after a completed operation`() async throws {

        let interface = CarPlayTestInterface()
        var events: [CarPlayNavigationKind] = []
        var host: CarPlayHost?
        host = CarPlayHost(interface: interface, onNavigation: { event in

            events.append(event.kind)
            if event.kind == .pushed {

                host?.disconnect()
            }
        }) { CarPlayList("Root") {}._resolve() }
        let connected = try #require(host)
        try await connected.connect()
        try await connected.context.push { CarPlayList("Next") {} }
        #expect(events == [.connected, .pushed, .disconnected])
        await #expect(throws: CarPlayError.disconnected) {

            try await connected.context.pop()
        }
        host = nil
    }
}

private extension CarPlayNavigationEventTests {

    func verifySequence(_ events: [CarPlayNavigationEvent]) {

        #expect(events.map(\.kind) == [
            .connected,
            .pushed,
            .pushed,
            .popped,
            .poppedToRoot,
            .rootReplaced,
            .modalPresented,
            .modalDismissed,
            .disconnected
        ])
        #expect(events.allSatisfy { $0.origin == .programmatic })
        #expect(events[0].animated == false)
        #expect(events[1].animated)
        #expect(events[2].current.stack.map(\.title) == ["Root", "One", "Two"])
        #expect(events[2].current.stack.last?.kind == .grid)
        #expect(events[6].current.modal?.title == "Hello")
        #expect(events[7].previous.modal == events[6].current.modal)
        #expect(events[8].current.stack.isEmpty)
        #expect(events[0].current.stack.first?.id
            == events[4].current.stack.first?.id)
        #expect(events[0].current.stack.first?.id
            != events[5].current.stack.first?.id)
    }

    func perform(_ operation: String, context: CarPlayContext) async throws {

        switch operation {

        case "push":
            try await context.push { CarPlayList("Destination") {} }

        case "pop":
            try await context.pop()

        case "popRoot":
            try await context.popToRoot()

        case "root":
            try await context.replaceRoot { CarPlayList("Replacement") {} }

        case "present":
            try await context
                .present(CarPlayAlert("Alert") { CarPlayAlertAction("OK") })

        default:
            try await context.dismiss()
        }
    }

    @MainActor
    final class Probe {

        let interface = CarPlayTestInterface()
        var events: [CarPlayNavigationEvent] = []

        func host() -> CarPlayHost {

            CarPlayHost(interface: self.interface, onNavigation: { [weak self] in

                self?.events.append($0)
            }) { CarPlayList("Root") {}._resolve() }
        }
    }
}
