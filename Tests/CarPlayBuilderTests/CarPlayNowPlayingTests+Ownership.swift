// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Shared native template tests inherit this suite's serialization.
extension CarPlayNowPlayingTests {

    @Test
    func `superseded disconnect preserves the current owners controls and labels`() {

        let first = self.ownedCoordinator("First", queue: false)
        let second = self.ownedCoordinator("Second", queue: true)
        first.connect(context: .init())
        second.connect(context: .init())
        let template = CPNowPlayingTemplate.shared
        let buttons = template.nowPlayingButtons
        first.disconnect()
        first.disconnect()
        #expect(template.nowPlayingButtons == buttons)
        #expect(template.upNextTitle == "Second")
        #expect(template.isUpNextButtonEnabled)
        #expect(template.isAlbumArtistButtonEnabled)
        second.disconnect()
        #expect(template.nowPlayingButtons.isEmpty)
        #expect(!template.isUpNextButtonEnabled)
        #expect(!template.isAlbumArtistButtonEnabled)
    }

    @Test
    func `superseded coordinator can reclaim ownership without stale cleanup`() {

        let first = self.ownedCoordinator("First", queue: false)
        let second = self.ownedCoordinator("Second", queue: true)
        first.connect(context: .init())
        second.connect(context: .init())
        first.connect(context: .init())
        let template = CPNowPlayingTemplate.shared
        let buttons = template.nowPlayingButtons
        second.disconnect()
        #expect(template.nowPlayingButtons == buttons)
        #expect(template.upNextTitle == "First")
        #expect(!template.isUpNextButtonEnabled)
        #expect(!template.isAlbumArtistButtonEnabled)
        first.disconnect()
    }

    @Test
    func `ownership handoff cancels previous control actions`() async {

        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Void>.makeStream()
        let first = CarPlayNowPlayingCoordinator(
            playback: OwnershipPlayback(hasUpNext: false),
            configuration: .init(showsMoreButton: true),
            onError: { Issue.record("Unexpected error: \($0)") },
            more: { _ in

                started.continuation.yield(())

                do {

                    try await Task.sleep(for: .seconds(30))
                } catch {

                    cancelled.continuation.yield(())
                    throw error
                }
            }
        ) { CarPlayList {} }
        let second = self.ownedCoordinator("Second", queue: true)
        first.connect(context: .init())
        first.perform(.more)
        var start = started.stream.makeAsyncIterator()
        _ = await start.next()
        second.connect(context: .init())
        var finish = cancelled.stream.makeAsyncIterator()
        _ = await finish.next()
        let buttons = CPNowPlayingTemplate.shared.nowPlayingButtons
        first.disconnect()
        #expect(CPNowPlayingTemplate.shared.nowPlayingButtons == buttons)
        second.disconnect()
    }

    @Test(arguments: [false, true])
    func `button cancellation cannot detach a reentrant connection`(
        reclaim: Bool
    ) throws {

        let firstPlayer = OwnershipPlayback(hasUpNext: true)
        let secondPlayer = OwnershipPlayback(hasUpNext: true)
        let first = CarPlayNowPlayingCoordinator(playback: firstPlayer) {

            CarPlayList {}
        }
        let second = CarPlayNowPlayingCoordinator(playback: secondPlayer) {

            CarPlayList {}
        }
        let target = reclaim ? first : second
        first.connect(context: .init())
        let button = try #require(CPNowPlayingTemplate.shared.nowPlayingButtons
            .first)
        let observation = button.observe(\.isEnabled, options: [.new]) {
            _, change in

            if change.newValue == false {

                MainActor.assumeIsolated { target.connect(context: .init()) }
            }
        }
        first.disconnect()
        observation.invalidate()
        target.perform(.playbackRate)
        #expect((reclaim ? firstPlayer : secondPlayer).rates == 1)
        target.disconnect()
    }

    @Test(arguments: 0 ..< 3, [false, true])
    func `teardown preserves reentrant ownership across native setters`(
        setter: Int,
        reclaim: Bool
    ) {

        let template = CPNowPlayingTemplate.shared
        let defaultTitle = template.upNextTitle
        let first = self.ownedCoordinator("First", queue: true)
        let second = self.ownedCoordinator("Second", queue: true)
        let target = reclaim ? first : second
        first.connect(context: .init())
        let observation = self.observeHandoff(
            template,
            setter: setter,
            defaultTitle: defaultTitle
        ) {

            target.connect(context: .init())
        }
        first.disconnect()
        observation.invalidate()
        #expect(template.upNextTitle == (reclaim ? "First" : "Second"))
        #expect(template.isUpNextButtonEnabled)
        #expect(template.isAlbumArtistButtonEnabled)
        #expect(template.nowPlayingButtons.count == 1)
        target.disconnect()
    }
}

private extension CarPlayNowPlayingTests {

    func observeHandoff(
        _ template: CPNowPlayingTemplate,
        setter: Int,
        defaultTitle: String,
        action: @escaping CarPlayCallback
    ) -> NSKeyValueObservation {

        switch setter {

        case 0:
            template.observe(\.isUpNextButtonEnabled, options: [.new]) { _, change in

                if change.newValue == false {

                    MainActor.assumeIsolated { action() }
                }
            }

        case 1:
            template.observe(\.isAlbumArtistButtonEnabled, options: [.new]) {
                _, change in

                if change.newValue == false {

                    MainActor.assumeIsolated { action() }
                }
            }

        default:
            template.observe(\.upNextTitle, options: [.new]) { _, change in

                if change.newValue == defaultTitle {

                    MainActor.assumeIsolated { action() }
                }
            }
        }
    }

    func ownedCoordinator(_ title: String, queue: Bool)
        -> CarPlayNowPlayingCoordinator {

        let albumArtist: (@MainActor () -> any CarPlayTemplate)? = if queue {

            { CarPlayList("Album") {} }
        } else {

            nil
        }
        return CarPlayNowPlayingCoordinator(
            playback: OwnershipPlayback(hasUpNext: queue),
            configuration: .init(upNextTitle: title),
            onError: { Issue.record("Unexpected error: \($0)") },
            albumArtist: albumArtist
        ) { CarPlayList("Queue") {} }
    }

    @MainActor
    final class OwnershipPlayback: CarPlayNowPlayingPlayback {

        let hasUpNext: Bool
        var rates = 0

        init(hasUpNext: Bool) {

            self.hasUpNext = hasUpNext
        }

        func cyclePlaybackRate() {

            self.rates += 1
        }

        func toggleShuffle() {}

        func cycleRepeatMode() {}
    }
}
