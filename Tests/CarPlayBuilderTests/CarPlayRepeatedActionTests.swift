// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Covers per-control busy state, duplicate suppression, and native availability.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CarPlayRepeatedActionTests {

    @Test(arguments: [
        CarPlayRepeatedActionPolicy.allowConcurrent,
        .ignoreWhileRunning
    ])
    func `policy gates synchronously and completes every selection`(
        policy: CarPlayRepeatedActionPolicy
    ) async {

        let state = CarPlayActionState()
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let release = AsyncStream<Void>.makeStream()
        let started = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        var enabled = true
        var calls = 0
        state.update(enabled: true, policy: policy) { enabled = $0 }
        for _ in 0 ..< 2 {

            state.perform(in: scope, action: {

                calls += 1
                started.continuation.yield(())
                var iterator = release.stream.makeAsyncIterator()
                _ = await iterator.next()
            }, completion: { completed.continuation.yield(()) })
        }
        let expected = policy == .allowConcurrent ? 2 : 1
        var start = started.stream.makeAsyncIterator()
        for _ in 0 ..< expected {

            _ = await start.next()
        }
        #expect(calls == expected)
        #expect(enabled == (policy == .allowConcurrent))
        release.continuation.finish()
        var finish = completed.stream.makeAsyncIterator()
        _ = await finish.next()
        _ = await finish.next()
        #expect(enabled)
        scope.cancel()
    }

    @Test
    func `rows stay busy through reorder and respect app disabled state`(
    ) async throws {

        let release = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        var calls = 0
        let row = CarPlayRow("Save") { _ in

            calls += 1
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
        }.id("save").repeatedActionPolicy(.ignoreWhileRunning)
        let node = try self.mount(self.list([row, CarPlayRow("Other").id("other")]))
        let list = try #require(node.template as? CPListTemplate)
        let item = try #require(list.sections[0].items[0] as? CPListItem)
        let handler = try #require(item.handler)
        handler(item) { completed.continuation.yield(()) }
        #expect(!item.isEnabled)
        handler(item) { completed.continuation.yield(()) }
        try node.update(self.list([
            CarPlayRow("Other").id("other"),
            row.disabled()
        ])._resolve())
        #expect(list.sections[0].items[1] === item)
        #expect(!item.isEnabled)
        release.continuation.finish()
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        _ = await iterator.next()
        #expect(calls == 1)
        #expect(!item.isEnabled)
        try node.update(self.list([row])._resolve())
        #expect(item.isEnabled)
        node.cancel()
    }

    @Test(arguments: 0 ..< 4)
    func `mounted controls disable while running and keep app availability`(
        kind: Int
    ) async {

        let release = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        var calls = 0
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let control = self.control(kind, scope: scope) { _ in

            calls += 1
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
            completed.continuation.yield(())
        }
        control.activate()
        #expect(!control.isEnabled())
        control.activate()
        control.update(true)
        #expect(!control.isEnabled())
        release.continuation.finish()
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(calls == 1)
        #expect(!control.isEnabled())
        control.update(false)
        #expect(control.isEnabled())
        control.cancel()
        #expect(!control.isEnabled())
        scope.cancel()
    }

    @Test(arguments: [false, true])
    func `failures and cancellation release busy state`(cancel: Bool) async {

        let state = CarPlayActionState()
        let started = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        var errors = 0
        var enabled = true
        let scope = CarPlayTaskScope(onError: { _ in errors += 1 })
        state.update(enabled: true, policy: .ignoreWhileRunning) { enabled = $0 }
        state.perform(in: scope, action: {

            started.continuation.yield(())
            if cancel {

                try await Task.sleep(for: .seconds(30))
            }
            throw ActionFailure.expected
        }, completion: { completed.continuation.yield(()) })
        var start = started.stream.makeAsyncIterator()
        _ = await start.next()
        if cancel {

            #expect(!enabled)
            scope.cancel()
        }
        var finish = completed.stream.makeAsyncIterator()
        _ = await finish.next()
        #expect(enabled)
        #expect(errors == (cancel ? 0 : 1))
        scope.cancel()
    }

    @Test
    func `replaced header buttons inherit busy state and retire old handlers`(
    ) async {

        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let release = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        var calls = 0
        let action: CarPlayAction = { _ in

            calls += 1
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
            completed.continuation.yield(())
        }
        let old = CarPlayMountedListHeaderButton(
            content: .init("Save", action: action)
                .repeatedActionPolicy(.ignoreWhileRunning),
            context: .init(),
            scope: scope
        )
        old.activate()
        old.retire()
        let value = CarPlayListHeaderButton(image: UIImage(), action: action)
            .repeatedActionPolicy(.ignoreWhileRunning)
        let replacement = CarPlayMountedListHeaderButton(
            content: value,
            context: .init(),
            scope: scope,
            actionState: old.actionState
        )
        replacement.update(value)
        #expect(!replacement.item.isEnabled)
        old.activate()
        replacement.activate()
        release.continuation.finish()
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(calls == 1)
        #expect(replacement.item.isEnabled)
        replacement.cancel()
        scope.cancel()
    }

    @Test
    @available(iOS 26.0, *)
    func `artwork elements keep busy state when their native row is replaced`(
    ) async throws {

        let release = AsyncStream<Void>.makeStream()
        let completed = AsyncStream<Void>.makeStream()
        var calls = 0
        let action: CarPlayAction = { _ in

            calls += 1
            var iterator = release.stream.makeAsyncIterator()
            _ = await iterator.next()
        }
        let node = try self.mount(self.imageList([1, 2], action: action))
        let list = try #require(node.template as? CPListTemplate)
        let old = try #require(list.sections[0].items[0] as? CPListImageRowItem)
        old.listImageRowHandler?(old, 0) { completed.continuation.yield(()) }
        #expect(!old.elements[0].isEnabled)
        old.listImageRowHandler?(old, 0) { completed.continuation.yield(()) }
        try node.update(self.imageList([2, 1], action: action)._resolve())
        let updated = try #require(list.sections[0].items[0] as? CPListImageRowItem)
        #expect(updated !== old)
        #expect(!updated.elements[1].isEnabled)
        updated.listImageRowHandler?(updated, 1) { completed.continuation.yield(()) }
        release.continuation.finish()
        var iterator = completed.stream.makeAsyncIterator()
        for _ in 0 ..< 3 {

            _ = await iterator.next()
        }
        #expect(calls == 1)
        #expect(updated.elements[1].isEnabled)
        node.cancel()
    }
}

private extension CarPlayRepeatedActionTests {

    func list(_ rows: [CarPlayRow]) -> CarPlayList {

        CarPlayList { CarPlaySection { rows }.id("section") }
    }

    func mount(_ content: some CarPlayTemplate) throws -> CarPlayMountedTemplate {

        try CarPlayMountedTemplate(
            content: content._resolve(),
            context: .init(),
            onError: { Issue.record("Error: \($0)") }
        )
    }

    @available(iOS 26.0, *)
    func imageList(_ ids: [Int], action: @escaping CarPlayAction) -> CarPlayList {

        CarPlayList {

            CarPlaySection {

                CarPlayImageRow(style: .row) {

                    for id in ids {

                        CarPlayImageElement("Save", image: UIImage(), action: action)
                            .id(id).repeatedActionPolicy(.ignoreWhileRunning)
                    }
                }.id("images")
            }.id("section")
        }
    }

    func control(
        _ kind: Int,
        scope: CarPlayTaskScope,
        action: @escaping CarPlayAction
    ) -> Control {

        switch kind {

        case 0:
            return self.bar(scope, action: action)

        case 1:
            return self.section(scope, action: action)

        case 2:
            return self.header(scope, action: action)

        default:
            return self.nowPlaying(scope, action: action)
        }
    }

    func bar(_ scope: CarPlayTaskScope, action: @escaping CarPlayAction) -> Control {

        let value = CarPlayBarButton("Save", action: action)
            .repeatedActionPolicy(.ignoreWhileRunning)
        let mounted = CarPlayMountedBarButton(
            content: value,
            context: .init(),
            scope: scope
        )
        return Control(
            isEnabled: { mounted.item.isEnabled },
            activate: mounted.activate,
            update: { mounted.update(value.disabled($0)) },
            cancel: mounted.cancel
        )
    }

    func section(
        _ scope: CarPlayTaskScope,
        action: @escaping CarPlayAction
    ) -> Control {

        let value = CarPlaySectionHeaderButton("Save", action: action)
            .repeatedActionPolicy(.ignoreWhileRunning)
        let mounted = CarPlayMountedSectionHeaderButton(
            content: value,
            context: .init(),
            scope: scope
        )
        return Control(
            isEnabled: { mounted.item.isEnabled },
            activate: mounted.activate,
            update: { mounted.update(value.disabled($0)) },
            cancel: mounted.cancel
        )
    }

    func header(
        _ scope: CarPlayTaskScope,
        action: @escaping CarPlayAction
    ) -> Control {

        let value = CarPlayListHeaderButton("Save", action: action)
            .repeatedActionPolicy(.ignoreWhileRunning)
        let mounted = CarPlayMountedListHeaderButton(
            content: value,
            context: .init(),
            scope: scope
        )
        return Control(
            isEnabled: { mounted.item.isEnabled },
            activate: mounted.activate,
            update: { mounted.update(value.disabled($0)) },
            cancel: mounted.cancel
        )
    }

    func nowPlaying(
        _ scope: CarPlayTaskScope,
        action: @escaping CarPlayAction
    ) -> Control {

        let value = CarPlayNowPlayingButton(image: UIImage(), action: action)
            .repeatedActionPolicy(.ignoreWhileRunning)
        let mounted = CarPlayMountedNowPlayingButton(
            content: value,
            playback: Playback(),
            context: .init(),
            scope: scope
        )
        return Control(
            isEnabled: { mounted.item.isEnabled },
            activate: mounted.activate,
            update: { mounted.update(value.disabled($0)) },
            cancel: mounted.cancel
        )
    }

    struct Control {

        let isEnabled: @MainActor () -> Bool
        let activate: CarPlayCallback
        let update: @MainActor (Bool) -> Void
        let cancel: CarPlayCallback
    }

    @MainActor
    final class Playback: CarPlayNowPlayingPlayback {

        var hasUpNext = false

        func cyclePlaybackRate() {}

        func toggleShuffle() {}

        func cycleRepeatMode() {}
    }

    enum ActionFailure: Error {

        case expected
    }
}
