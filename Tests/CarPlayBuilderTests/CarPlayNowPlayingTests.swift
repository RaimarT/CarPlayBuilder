// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

/// Covers shared Now Playing controls and scene-owned action cancellation.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct CarPlayNowPlayingTests {

    @Test(arguments: 0 ..< 32)
    func `configuration independently controls all five native buttons`(mask: Int) {

        let player = Playback()
        let config = CarPlayNowPlayingConfiguration(
            showsPlaybackRateButton: mask & 1 != 0,
            showsShuffleButton: mask & 2 != 0,
            showsRepeatButton: mask & 4 != 0,
            showsAddToLibraryButton: mask & 8 != 0,
            showsMoreButton: mask & 16 != 0
        )
        let coordinator = self.coordinator(player, config: config)
        coordinator.connect(context: .init())
        let buttons = CPNowPlayingTemplate.shared.nowPlayingButtons
        #expect(buttons.count == mask.nonzeroBitCount)
        #expect(buttons.contains { $0 is CPNowPlayingPlaybackRateButton } ==
            config.showsPlaybackRateButton)
        #expect(buttons.contains { $0 is CPNowPlayingShuffleButton } ==
            config.showsShuffleButton)
        #expect(buttons.contains { $0 is CPNowPlayingRepeatButton } ==
            config.showsRepeatButton)
        #expect(buttons.contains { $0 is CPNowPlayingAddToLibraryButton } ==
            config.showsAddToLibraryButton)
        #expect(buttons.contains { $0 is CPNowPlayingMoreButton } == config
            .showsMoreButton)
        coordinator.disconnect()
        #expect(CPNowPlayingTemplate.shared.nowPlayingButtons.isEmpty)
    }

    @Test
    func `optional buttons require handlers and disconnected actions are ignored`() {

        let player = Playback()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: player,
            configuration: .init(
                showsAddToLibraryButton: true,
                showsMoreButton: true
            ),
            onError: { Issue.record("Error: \($0)") }
        ) { CarPlayList {} }
        coordinator.perform(.playbackRate)
        #expect(player.rates == 0)
        coordinator.connect(context: .init())
        #expect(CPNowPlayingTemplate.shared.nowPlayingButtons.count == 1)
        coordinator.perform(.addToLibrary)
        coordinator.perform(.more)
        coordinator.perform(.playbackRate)
        #expect(player.rates == 1)
        coordinator.disconnect()
        coordinator.perform(.playbackRate)
        #expect(player.rates == 1)
    }

    @Test
    func `playback controls dispatch without rebuilding native buttons`() {

        let player = Playback()
        let coordinator = self.coordinator(player)
        coordinator.connect(context: .init())
        let buttons = CPNowPlayingTemplate.shared.nowPlayingButtons
        coordinator.perform(.playbackRate)
        coordinator.perform(.shuffle)
        coordinator.perform(.repeat)
        #expect(player.rates == 1)
        #expect(player.shuffles == 1)
        #expect(player.repeats == 1)
        #expect(buttons == CPNowPlayingTemplate.shared.nowPlayingButtons)
        coordinator.disconnect()
    }

    @Test
    func `observable queue changes update availability without replacing buttons`(
    ) async {

        let player = Playback()
        let coordinator = self.coordinator(player)
        coordinator.connect(context: .init())
        let template = CPNowPlayingTemplate.shared
        let buttons = template.nowPlayingButtons
        let changed = AsyncStream<Void>.makeStream()
        let observation = template
            .observe(\.isUpNextButtonEnabled, options: [.new]) {
                _, change in

                if change.newValue == true {

                    changed.continuation.yield(())
                }
            }
        player.hasUpNext = true
        var iterator = changed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(template.isUpNextButtonEnabled)
        #expect(template.nowPlayingButtons == buttons)
        observation.invalidate()
        coordinator.disconnect()
        #expect(!template.isUpNextButtonEnabled)
    }

    @Test
    func `add to library and more invoke app callbacks`() async {

        let completed = AsyncStream<String>.makeStream()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: Playback(),
            configuration: .init(
                showsAddToLibraryButton: true,
                showsMoreButton: true
            ),
            onError: { Issue.record("Error: \($0)") },
            addToLibrary: { _ in completed.continuation.yield("save") },
            more: { _ in completed.continuation.yield("more") }
        ) { CarPlayList {} }
        coordinator.connect(context: .init())
        coordinator.perform(.addToLibrary)
        coordinator.perform(.more)
        var iterator = completed.stream.makeAsyncIterator()
        let first = await iterator.next()
        let second = await iterator.next()
        #expect(Set([first, second].compactMap { $0 }) == ["save", "more"])
        coordinator.disconnect()
    }

    @Test(arguments: [false, true])
    func `bookmark initially reflects the app saved state`(saved: Bool) throws {

        let player = Playback()
        let library = Library()
        library.savedIDs = saved ? [0] : []
        let coordinator = self.coordinator(player, isAddedToLibrary: {

            library.savedIDs.contains(player.trackID)
        })
        coordinator.connect(context: .init())

        defer {

            coordinator.disconnect()
        }

        let button = try #require(CPNowPlayingTemplate.shared.nowPlayingButtons
            .compactMap { $0 as? CPNowPlayingImageButton }.first)
        #expect(button.isSelected == saved)
        #expect(button.image != nil)
    }

    @Test
    func `bookmark reconnects with the latest saved state`() throws {

        let player = Playback()
        let library = Library()
        let coordinator = self.coordinator(player, isAddedToLibrary: {

            library.savedIDs.contains(player.trackID)
        })
        coordinator.connect(context: .init())
        let before = try #require(CPNowPlayingTemplate.shared.nowPlayingButtons
            .compactMap { $0 as? CPNowPlayingImageButton }.first)
        library.savedIDs = [0]
        coordinator.disconnect()
        coordinator.connect(context: .init())

        defer {

            coordinator.disconnect()
        }

        let after = try #require(CPNowPlayingTemplate.shared.nowPlayingButtons
            .compactMap { $0 as? CPNowPlayingImageButton }.first)
        #expect(!before.isSelected)
        #expect(after.isSelected)
        #expect(after !== before)
    }

    @Test
    func `bookmark observes saving clearing and track changes without flicker`(
    ) async throws {

        let player = Playback()
        let library = Library()
        let coordinator = self.coordinator(player, isAddedToLibrary: {

            library.savedIDs.contains(player.trackID)
        })
        coordinator.connect(context: .init())

        defer {

            coordinator.disconnect()
        }

        let buttons = CPNowPlayingTemplate.shared.nowPlayingButtons
        let button = try #require(buttons.compactMap {

            $0 as? CPNowPlayingImageButton
        }.first)
        let changed = AsyncStream<Bool>.makeStream()
        let observation = button.observe(\.isSelected, options: [.new]) { _, value in

            if let selected = value.newValue {

                changed.continuation.yield(selected)
            }
        }

        defer {

            observation.invalidate()
        }

        await self.checkSavedUpdates(player, library, changed.stream)
        #expect(CPNowPlayingTemplate.shared.nowPlayingButtons == buttons)
    }

    @Test
    func `additional action errors are reported`() async {

        let failed = AsyncStream<Void>.makeStream()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: Playback(),
            configuration: .init(showsMoreButton: true),
            onError: { error in

                #expect(error is ActionFailure)
                failed.continuation.yield(())
            },
            more: { _ in throw ActionFailure.expected }
        ) { CarPlayList {} }
        coordinator.connect(context: .init())
        coordinator.perform(.more)
        var iterator = failed.stream.makeAsyncIterator()
        _ = await iterator.next()
        coordinator.disconnect()
    }

    @Test(arguments: [false, true])
    func `reconnection and disconnection cancel callbacks`(reconnect: Bool) async {

        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: Playback(),
            configuration: .init(showsAddToLibraryButton: true),
            onError: { Issue.record("Error: \($0)") },
            addToLibrary: { _ in

                started.continuation.yield(())

                do {

                    try await Task.sleep(for: .seconds(30))
                } catch {

                    cancelled.continuation.yield(())
                    throw error
                }
            }
        ) { CarPlayList {} }
        coordinator.connect(context: .init())
        coordinator.perform(.addToLibrary)
        var iterator = started.stream.makeAsyncIterator()
        _ = await iterator.next()
        if reconnect {

            coordinator.connect(context: .init())
        } else {

            coordinator.disconnect()
        }
        var cancellation = cancelled.stream.makeAsyncIterator()
        _ = await cancellation.next()
        coordinator.disconnect()
    }

    @Test
    func `more can present a modal and up next pushes the injected destination`(
    ) async
        throws {

        let interface = CarPlayTestInterface()
        let completed = AsyncStream<String>.makeStream()
        interface.completed = { completed.continuation.yield($0) }
        let host = CarPlayHost(interface: interface, onError: { _ in }) {

            CarPlayList {}._resolve()
        }
        try await host.connect()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: Playback(),
            configuration: .init(showsMoreButton: true),
            onError: { Issue.record("Error: \($0)") },
            more: { context in

                try await context.present(CarPlayActionSheet("More") {

                    CarPlayAlertAction("Cancel", style: .cancel)
                })
            }
        ) { CarPlayList("Up Next") {} }
        coordinator.connect(context: host.context)
        coordinator.perform(.more)
        var iterator = completed.stream.makeAsyncIterator()
        #expect(await iterator.next() == "present")
        #expect(interface.presentedTemplate is CPActionSheetTemplate)
        try await host.context.dismiss()
        #expect(await iterator.next() == "dismiss")
        coordinator.nowPlayingTemplateUpNextButtonTapped(.shared)
        #expect(await iterator.next() == "push")
        #expect((interface.templates.last as? CPListTemplate)?.title == "Up Next")
        coordinator.disconnect()
        host.disconnect()
    }

    @Test
    func `up next failures propagate and disconnected taps are ignored`() async {

        let failed = AsyncStream<Void>.makeStream()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: Playback(),
            onError: { error in

                #expect(error is CarPlayError)
                #expect(error.localizedDescription ==
                    CarPlayError.disconnected.localizedDescription)
                failed.continuation.yield(())
            }
        ) { CarPlayList {} }
        coordinator.connect(context: .init())
        coordinator.nowPlayingTemplateUpNextButtonTapped(.shared)
        var iterator = failed.stream.makeAsyncIterator()
        _ = await iterator.next()
        coordinator.disconnect()
        coordinator.nowPlayingTemplateUpNextButtonTapped(.shared)
    }
}

private extension CarPlayNowPlayingTests {

    func checkSavedUpdates(
        _ player: Playback,
        _ library: Library,
        _ changes: AsyncStream<Bool>
    ) async {

        var iterator = changes.makeAsyncIterator()
        library.savedIDs = [0]
        #expect(await iterator.next() == true)
        player.trackID = 1
        #expect(await iterator.next() == false)
        library.savedIDs = [0, 1]
        #expect(await iterator.next() == true)
        library.savedIDs = []
        #expect(await iterator.next() == false)
    }

    func coordinator(
        _ playback: Playback,
        isAddedToLibrary: (@MainActor () -> Bool)? = nil,
        config: CarPlayNowPlayingConfiguration = .init(
            showsShuffleButton: true,
            showsRepeatButton: true,
            showsAddToLibraryButton: true,
            showsMoreButton: true
        )
    ) -> CarPlayNowPlayingCoordinator {

        CarPlayNowPlayingCoordinator(
            playback: playback,
            configuration: config,
            onError: { Issue.record("Error: \($0)") },
            addToLibrary: { _ in },
            more: { _ in },
            isAddedToLibrary: isAddedToLibrary
        ) { CarPlayList {} }
    }
}

private extension CarPlayNowPlayingTests {

    @MainActor
    @Observable
    final class Playback: CarPlayNowPlayingPlayback {

        var hasUpNext = false
        var trackID = 0
        var rates = 0
        var shuffles = 0
        var repeats = 0

        func cyclePlaybackRate() {

            self.rates += 1
        }

        func toggleShuffle() {

            self.shuffles += 1
        }

        func cycleRepeatMode() {

            self.repeats += 1
        }
    }

    @MainActor
    @Observable
    final class Library {

        var savedIDs: Set<Int> = []
    }

    enum ActionFailure: Error {

        case expected
    }
}
