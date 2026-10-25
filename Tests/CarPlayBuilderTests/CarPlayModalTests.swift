// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers modal validation, dismissal ordering, and repeated-selection guards.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayModalTests {

    @Test
    func `alert actions dismiss before running and ignore repeated taps`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let completed = AsyncStream<Void>.makeStream()
        let host = self.host(interface)
        var calls = 0
        try await host.connect()
        try await host.context.present(CarPlayAlert(titleVariants: [
            "Long",
            "Short"
        ]) {

            CarPlayAlertAction("Continue") { context in

                calls += 1
                #expect(interface.presentedTemplate == nil)
                try await context.push { CarPlayList("Next") {} }
                completed.continuation.yield(())
            }
        })
        let alert = try #require(interface.presentedTemplate as? CPAlertTemplate)
        #expect(alert.titleVariants == ["Long", "Short"])
        alert.actions[0].handler(alert.actions[0])
        alert.actions[0].handler(alert.actions[0])
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(calls == 1)
        #expect(interface.templates.count == 2)
        host.disconnect()
    }

    @Test
    func `action sheet preserves titles messages styles and explicit dismissal`(
    ) async
        throws {

        let interface = CarPlayTestInterface()
        let host = self.host(interface)
        try await host.connect()
        try await host.context.present(CarPlayActionSheet(
            "Options",
            message: "Choose"
        ) {

            CarPlayAlertAction("Delete", style: .destructive)
            CarPlayAlertAction("Cancel", style: .cancel)
        })
        let sheet = try #require(interface
            .presentedTemplate as? CPActionSheetTemplate)
        #expect(sheet.title == "Options")
        #expect(sheet.message == "Choose")
        #expect(sheet.actions.map(\.style) == [.destructive, .cancel])
        try await host.context.dismiss()
        try await host.context.dismiss()
        #expect(interface.presentedTemplate == nil)
        host.disconnect()
    }

    @Test
    func `default cancel action dismisses without requiring an app callback`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let dismissed = AsyncStream<Void>.makeStream()
        interface.completed = { operation in

            if operation == "dismiss" {

                dismissed.continuation.yield(())
            }
        }
        let host = self.host(interface)
        try await host.connect()
        try await host.context.present(CarPlayAlert("Cancel") {

            CarPlayAlertAction("Cancel", style: .cancel)
        })
        let alert = try #require(interface.presentedTemplate as? CPAlertTemplate)
        alert.actions[0].handler(alert.actions[0])
        var iterator = dismissed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(interface.presentedTemplate == nil)
        host.disconnect()
    }

    @Test
    func `active modal rejects conflicting navigation`() async throws {

        let interface = CarPlayTestInterface()
        let host = self.host(interface)
        try await host.connect()
        try await host.context.present(self.alert)
        await #expect(throws: CarPlayError.operationInProgress) {

            try await host.context.present(self.alert)
        }
        await #expect(throws: CarPlayError.operationInProgress) {

            try await host.context.push { CarPlayList {} }
        }
        try await host.context.dismiss()
        try await host.context.push { CarPlayList {} }
        host.disconnect()
    }

    @Test(arguments: ["present", "dismiss"])
    func `rejected modal operations allow retry`(operation: String) async throws {

        let interface = CarPlayTestInterface()
        let host = self.host(interface)
        try await host.connect()
        if operation == "dismiss" {

            try await host.context.present(self.alert)
        }
        interface.reject = operation
        await #expect(throws: CarPlayError.presentationRejected) {

            if operation == "present" {

                try await host.context.present(self.alert)
            } else {

                try await host.context.dismiss()
            }
        }
        if operation == "present" {

            try await host.context.present(self.alert)
        }
        try await host.context.dismiss()
        #expect(interface.presentedTemplate == nil)
        host.disconnect()
    }

    @Test
    func `modal action errors reach the host error handler`() async throws {

        let interface = CarPlayTestInterface()
        let failed = AsyncStream<Void>.makeStream()
        let host = CarPlayHost(interface: interface, onError: { error in

            #expect(error is ModalFailure)
            failed.continuation.yield(())
        }) { CarPlayList {}._resolve() }
        try await host.connect()
        try await host.context.present(CarPlayAlert("Fail") {

            CarPlayAlertAction("Go") { _ in throw ModalFailure.expected }
        })
        let alert = try #require(interface.presentedTemplate as? CPAlertTemplate)
        alert.actions[0].handler(alert.actions[0])
        var iterator = failed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(interface.presentedTemplate == nil)
        host.disconnect()
    }

    @Test(arguments: ["present", "dismiss"])
    func `disconnect during modal operation rejects stale completion`(
        operation: String
    ) async throws {

        let interface = CarPlayTestInterface()
        let host = self.host(interface)
        try await host.connect()
        if operation == "dismiss" {

            try await host.context.present(self.alert)
        }
        interface.duringOperation = { name in

            if name == operation {

                host.disconnect()
            }
        }
        await #expect(throws: CarPlayError.disconnected) {

            if operation == "present" {

                try await host.context.present(self.alert)
            } else {

                try await host.context.dismiss()
            }
        }
        #expect(interface.delegate == nil)
    }

    @Test
    func `invalid alerts are rejected before native creation`() {

        let invalid: [CarPlayModalContent] = [
            CarPlayAlert("") { CarPlayAlertAction("OK") }._resolveModal(),
            CarPlayAlert("Empty") {}._resolveModal(),
            CarPlayAlert(titleVariants: []) { CarPlayAlertAction("OK") }
                ._resolveModal(),
            CarPlayAlert("Title") { CarPlayAlertAction("") }._resolveModal(),
            CarPlayAlert("Title") {

                CarPlayAlertAction("One", style: .cancel)
                CarPlayAlertAction("Two", style: .cancel)
            }._resolveModal(),
            CarPlayAlert("Too many") {

                for index in 0 ... CPAlertTemplate.maximumActionCount {

                    CarPlayAlertAction("\(index)")
                }
            }._resolveModal()
        ]
        for content in invalid {

            #expect(throws: CarPlayError.self) { try content.makeTemplate { _ in } }
        }
    }

    @Test
    func `disconnect cancels running modal actions`() async throws {

        let interface = CarPlayTestInterface()
        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        let host = self.host(interface)
        try await host.connect()
        try await host.context.present(CarPlayAlert("Run") {

            CarPlayAlertAction("Go") { _ in

                started.continuation.yield(())

                do {

                    try await Task.sleep(for: .seconds(30))
                } catch {

                    cancelled.continuation.yield(())
                    throw error
                }
            }
        })
        let alert = try #require(interface.presentedTemplate as? CPAlertTemplate)
        alert.actions[0].handler(alert.actions[0])
        var iterator = started.stream.makeAsyncIterator()
        _ = await iterator.next()
        host.disconnect()
        var cancellation = cancelled.stream.makeAsyncIterator()
        _ = await cancellation.next()
    }
}

private extension CarPlayModalTests {

    var alert: CarPlayAlert {

        CarPlayAlert("Alert") { CarPlayAlertAction("OK") }
    }

    func host(_ interface: CarPlayTestInterface) -> CarPlayHost {

        CarPlayHost(
            interface: interface,
            onError: { Issue.record("Error: \($0)") }
        ) {

            CarPlayList {}._resolve()
        }
    }
}

private extension CarPlayModalTests {

    enum ModalFailure: Error {

        case expected
    }
}
