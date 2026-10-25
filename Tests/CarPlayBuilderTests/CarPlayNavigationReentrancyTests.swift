// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Verifies that completed operations cannot release a newer navigation lease.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayNavigationReentrancyTests {

    @available(iOS 26.0, *)
    @Test
    func `older cleanup preserves navigation started inside its callback`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let release = AsyncStream<Void>.makeStream()
        interface.beforePopRoot = {

            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
        }
        var pending: Task<Void, any Error>?
        var host: CarPlayHost?
        host = CarPlayHost(interface: interface, onNavigation: { event in

            if event.kind == .pushed, pending == nil {

                pending = Task.immediate { @MainActor [weak host] in

                    try await host?.context.popToRoot()
                }
            }
        }) { CarPlayList("Root") {}._resolve() }
        let connected = try #require(host)
        try await connected.connect()
        try await connected.context.push { CarPlayList("First") {} }
        #expect(pending != nil)
        await #expect(throws: CarPlayError.operationInProgress) {

            try await connected.context.push { CarPlayList("Overlapping") {} }
        }
        release.continuation.yield(())
        try await pending?.value
        try await connected.context.push { CarPlayList("After completion") {} }
        connected.disconnect()
        host = nil
    }
}
