// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation
import Testing
@testable import CarPlayBuilder

/// Extend the serialized suite because Now Playing uses a shared native template.
extension CarPlayNowPlayingTests {

    @Test
    func `composed controls use supplied order and ignore visibility flags`() {

        let player = CompositionPlayback()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: player,
            configuration: .init(showsPlaybackRateButton: false),
            onError: { Issue.record("Error: \($0)") },
            buttons: {

                CarPlayNowPlayingButton.more { _ in }
                CarPlayNowPlayingButton.repeatMode
                CarPlayNowPlayingButton.playbackRate
                CarPlayNowPlayingButton.addToLibrary { _ in }
                CarPlayNowPlayingButton.shuffle
            },
            upNext: { CarPlayList {} }
        )
        coordinator.connect(context: .init())
        let buttons = CPNowPlayingTemplate.shared.nowPlayingButtons
        #expect(buttons.count == 5)
        #expect(buttons[0] is CPNowPlayingMoreButton)
        #expect(buttons[1] is CPNowPlayingRepeatButton)
        #expect(buttons[2] is CPNowPlayingPlaybackRateButton)
        #expect(buttons[3] is CPNowPlayingAddToLibraryButton)
        #expect(buttons[4] is CPNowPlayingShuffleButton)
        coordinator.perform(.playbackRate)
        coordinator.perform(.shuffle)
        coordinator.perform(.repeat)
        #expect(player.rates == 1)
        #expect(player.shuffles == 1)
        #expect(player.repeats == 1)
        coordinator.disconnect()
    }

    @Test
    func `observed composition reorders controls and preserves custom state`(
    ) async throws {

        let state = CompositionState()
        let renders = AsyncStream<Void>.makeStream()
        let coordinator = self.composition(state, rendered: {

            renders.continuation.yield(())
        })
        coordinator.connect(context: .init())
        var iterator = renders.stream.makeAsyncIterator()
        _ = await iterator.next()
        let template = CPNowPlayingTemplate.shared
        let original = try #require(template.nowPlayingButtons.first)
        #expect(original is CPNowPlayingImageButton)
        state.reversed = true
        state.selected = true
        state.disabled = true
        _ = await iterator.next()
        #expect(template.nowPlayingButtons.last === original)
        #expect(original.isSelected)
        #expect(!original.isEnabled)
        state.image = UIImage()
        _ = await iterator.next()
        #expect(template.nowPlayingButtons.last !== original)
        coordinator.disconnect()
    }

    @Test(arguments: [false, true])
    func `invalid composition preserves controls and recovers on a valid update`(
        duplicateIDs: Bool
    ) async {

        let state = CompositionState()
        let renders = AsyncStream<Void>.makeStream()
        let errors = AsyncStream<Void>.makeStream()
        let coordinator = self.validatedComposition(
            state,
            rendered: { renders.continuation.yield(()) },
            onError: {

                #expect($0 is CarPlayError)
                errors.continuation.yield(())
            }
        )
        coordinator.connect(context: .init())
        var render = renders.stream.makeAsyncIterator()
        _ = await render.next()
        let original = CPNowPlayingTemplate.shared.nowPlayingButtons
        state.count = duplicateIDs ? 2 : 6
        state.duplicates = duplicateIDs
        var error = errors.stream.makeAsyncIterator()
        _ = await error.next()
        _ = await render.next()
        #expect(CPNowPlayingTemplate.shared.nowPlayingButtons == original)
        state.count = 0
        _ = await render.next()
        #expect(CPNowPlayingTemplate.shared.nowPlayingButtons.isEmpty)
        coordinator.disconnect()
    }

    @Test
    func `custom mounted controls use the latest action and reject stale taps`(
    ) async {

        let completed = AsyncStream<Void>.makeStream()
        let scope = CarPlayTaskScope(onError: { Issue.record("Error: \($0)") })
        let image = UIImage()
        let mounted = CarPlayMountedNowPlayingButton(
            content: .init(image: image) { _ in Issue.record("Old action") },
            playback: CompositionPlayback(),
            context: .init(),
            scope: scope
        )
        let native = mounted.item
        var calls = 0
        let updated = CarPlayNowPlayingButton(image: image) { _ in

            calls += 1
            completed.continuation.yield(())
        }.selected()
        mounted.update(updated)
        #expect(mounted.item === native)
        #expect(native.isSelected)
        mounted.activate()
        var iterator = completed.stream.makeAsyncIterator()
        _ = await iterator.next()
        mounted.update(updated.disabled())
        mounted.activate()
        mounted.update(updated)
        mounted.cancel()
        mounted.activate()
        #expect(calls == 1)
        scope.cancel()
    }

    @Test
    func `custom control actions navigate using the connected scene context`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let completed = AsyncStream<String>.makeStream()
        interface.completed = { completed.continuation.yield($0) }
        let host = self.compositionHost(interface)
        try await host.connect()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: CompositionPlayback(),
            onError: { Issue.record("Error: \($0)") },
            buttons: {

                CarPlayNowPlayingButton(image: UIImage()) { context in

                    try await context.push { CarPlayList("Custom action") {} }
                }
            },
            upNext: { CarPlayList {} }
        )
        coordinator.connect(context: host.context)
        coordinator.perform(.custom)
        var iterator = completed.stream.makeAsyncIterator()
        #expect(await iterator.next() == "push")
        #expect((interface.templates.last as? CPListTemplate)?.title ==
            "Custom action")
        coordinator.disconnect()
        host.disconnect()
    }

    @Test
    func `album artist destinations are lazy and labels reset on disconnect`(
    ) async throws {

        let interface = CarPlayTestInterface()
        let completed = AsyncStream<String>.makeStream()
        interface.completed = { completed.continuation.yield($0) }
        let host = self.compositionHost(interface)
        try await host.connect()
        let template = CPNowPlayingTemplate.shared
        let defaultTitle = template.upNextTitle
        var title = "Original album"
        var evaluations = 0
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: CompositionPlayback(),
            configuration: .init(upNextTitle: "Episodes"),
            onError: { Issue.record("Error: \($0)") },
            albumArtist: {

                evaluations += 1
                return CarPlayList(title) {}
            }
        ) { CarPlayList("Queue") {} }
        coordinator.connect(context: host.context)
        #expect(template.upNextTitle == "Episodes")
        #expect(template.isAlbumArtistButtonEnabled)
        #expect(evaluations == 0)
        title = "Current album"
        coordinator.nowPlayingTemplateAlbumArtistButtonTapped(template)
        var iterator = completed.stream.makeAsyncIterator()
        #expect(await iterator.next() == "push")
        #expect(evaluations == 1)
        #expect((interface.templates.last as? CPListTemplate)?.title == title)
        coordinator.disconnect()
        #expect(template.upNextTitle == defaultTitle)
        #expect(!template.isAlbumArtistButtonEnabled)
        host.disconnect()
    }

    @Test
    func `album artist errors propagate and disconnected taps stay inert`() async {

        let failed = AsyncStream<Void>.makeStream()
        var evaluations = 0
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: CompositionPlayback(),
            onError: {

                #expect($0 as? CarPlayError == .disconnected)
                failed.continuation.yield(())
            },
            albumArtist: {

                evaluations += 1
                return CarPlayList("Album") {}
            },
            buttons: {},
            upNext: { CarPlayList {} }
        )
        coordinator.connect(context: .init())
        coordinator.nowPlayingTemplateAlbumArtistButtonTapped(.shared)
        var iterator = failed.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(evaluations == 0)
        coordinator.disconnect()
        coordinator.nowPlayingTemplateAlbumArtistButtonTapped(.shared)
        #expect(evaluations == 0)
    }

    @Test(arguments: [false, true])
    func `a new destination tap or reconnect cancels pending album navigation`(
        reconnect: Bool
    ) async throws {

        let interface = CarPlayTestInterface()
        let completed = AsyncStream<String>.makeStream()
        interface.completed = { completed.continuation.yield($0) }
        let host = self.compositionHost(interface)
        try await host.connect()
        var evaluations = 0
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: CompositionPlayback(),
            onError: { Issue.record("Error: \($0)") },
            albumArtist: {

                evaluations += 1
                return CarPlayList("Cancelled album") {}
            }
        ) { CarPlayList("Queue") {} }
        coordinator.connect(context: host.context)
        coordinator.nowPlayingTemplateAlbumArtistButtonTapped(.shared)
        if reconnect {

            coordinator.connect(context: host.context)
        }
        coordinator.nowPlayingTemplateUpNextButtonTapped(.shared)
        var iterator = completed.stream.makeAsyncIterator()
        #expect(await iterator.next() == "push")
        #expect(evaluations == 0)
        #expect(interface.templates.count == 2)
        #expect((interface.templates.last as? CPListTemplate)?.title == "Queue")
        coordinator.disconnect()
        host.disconnect()
    }

    @Test
    func `custom action failures reach the configured error handler`() async {

        let errors = AsyncStream<Void>.makeStream()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: CompositionPlayback(),
            onError: {

                #expect($0 is CompositionFailure)
                errors.continuation.yield(())
            },
            buttons: {

                CarPlayNowPlayingButton(image: UIImage()) { _ in

                    throw CompositionFailure.expected
                }
            },
            upNext: { CarPlayList {} }
        )
        coordinator.connect(context: .init())
        coordinator.perform(.custom)
        var iterator = errors.stream.makeAsyncIterator()
        _ = await iterator.next()
        coordinator.disconnect()
    }
}

private extension CarPlayNowPlayingTests {

    func composition(
        _ state: CompositionState,
        rendered: @escaping CarPlayCallback
    ) -> CarPlayNowPlayingCoordinator {

        CarPlayNowPlayingCoordinator(
            playback: CompositionPlayback(),
            onError: { Issue.record("Error: \($0)") },
            buttons: {

                self.composedButtons(state, rendered: rendered)
            },
            upNext: { CarPlayList {} }
        )
    }

    func composedButtons(
        _ state: CompositionState,
        rendered: CarPlayCallback
    ) -> [CarPlayNowPlayingButton] {

        let image = CarPlayNowPlayingButton(image: state.image) { _ in }
            .id("image").selected(state.selected).disabled(state.disabled)
        let more = CarPlayNowPlayingButton.more { _ in }.id("more")
        let buttons = state.reversed ? [more, image] : [image, more]
        rendered()

        return buttons
    }

    func validatedComposition(
        _ state: CompositionState,
        rendered: @escaping CarPlayCallback,
        onError: @escaping CarPlayErrorHandler
    ) -> CarPlayNowPlayingCoordinator {

        CarPlayNowPlayingCoordinator(
            playback: CompositionPlayback(),
            onError: onError,
            buttons: {

                self.validationButtons(state, rendered: rendered)
            },
            upNext: { CarPlayList {} }
        )
    }

    func validationButtons(
        _ state: CompositionState,
        rendered: CarPlayCallback
    ) -> [CarPlayNowPlayingButton] {

        let buttons = (0 ..< state.count).map { index in

            CarPlayNowPlayingButton(image: state.image) { _ in }
                .id(state.duplicates ? 0 : index)
        }
        rendered()

        return buttons
    }

    func compositionHost(_ interface: CarPlayTestInterface) -> CarPlayHost {

        CarPlayHost(
            interface: interface,
            onError: { Issue.record("Error: \($0)") }
        ) { CarPlayList {}._resolve() }
    }

    @MainActor
    @Observable
    final class CompositionState {

        var image = UIImage()
        var selected = false
        var disabled = false
        var reversed = false
        var count = 1
        var duplicates = false
    }

    @MainActor
    final class CompositionPlayback: CarPlayNowPlayingPlayback {

        var hasUpNext = true
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

    enum CompositionFailure: Error {

        case expected
    }
}
