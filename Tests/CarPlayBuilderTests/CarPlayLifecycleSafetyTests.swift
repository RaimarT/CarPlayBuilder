// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers terminal teardown and reentrancy from synchronous visibility callbacks.
@MainActor
struct CarPlayLifecycleSafetyTests {

    @Test
    func `cancellation during appearance stops callbacks and lifecycle work`(
    ) async throws {

        var mounted: CarPlayMountedTemplate?
        var events: [String] = []
        let content = CarPlayList {}.task {

            events.append("task")
        }.onAppear {

            events.append("appear")
            mounted?.cancel()
        }.onAppear {

            events.append("late callback")
        }._resolve()
        mounted = try self.mount(content)
        let node = try #require(mounted)
        node.setVisible(true, for: node.template)
        #expect(events == ["appear"])
        node.setVisible(true, for: node.template)
        await Task.yield()
        #expect(events == ["appear"])
        #expect(throws: CarPlayError.disconnected) {

            try node.update(content)
        }
        mounted = nil
    }

    @Test
    func `reentrant disappearance cancellation remains terminal`() throws {

        var mounted: CarPlayMountedTemplate?
        var appearances = 0
        var disappearances = 0
        let content = CarPlayList {}.onAppear {

            appearances += 1
        }.onDisappear {

            disappearances += 1
            mounted?.cancel()
        }._resolve()
        mounted = try self.mount(content)
        let node = try #require(mounted)
        node.setVisible(true, for: node.template)
        node.cancel()
        node.cancel()
        node.setVisible(true, for: node.template)
        #expect(appearances == 1)
        #expect(disappearances == 1)
        mounted = nil
    }
}

private extension CarPlayLifecycleSafetyTests {

    func mount(_ content: CarPlayTemplateContent) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: content,
            context: .init(),
            onError: { Issue.record("Unexpected error: \($0)") }
        )
    }
}
