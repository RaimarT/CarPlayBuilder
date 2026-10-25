// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Testing
@testable import CarPlayBuilder

/// Uses the serialized suite because the native Now Playing template is shared.
extension CarPlayNowPlayingTests {

    @Test
    func `Now Playing controls preserve explicit IDs in contextual errors`(
    ) async throws {

        let reported = AsyncStream<CarPlayErrorContext>.makeStream()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: ContextPlayback(),
            onErrorWithContext: { _, origin in

                reported.continuation.yield(origin)
            },
            buttons: {

                CarPlayNowPlayingButton.more { _ in

                    throw CarPlayError.disconnected
                }.id("options")
            },
            upNext: { CarPlayList {} }
        )
        coordinator.connect(context: .init())
        coordinator.perform(.more)
        var iterator = reported.stream.makeAsyncIterator()
        let origin = try #require(await iterator.next())
        #expect(origin.source == .action)
        #expect(origin.control == .nowPlayingButton)
        #expect(origin.controlID == AnyHashable("options"))
        #expect(origin.screenID == nil)
        coordinator.disconnect()
    }

    @Test
    func `Now Playing destination navigation reports its origin`() async throws {

        let reported = AsyncStream<CarPlayErrorContext>.makeStream()
        let coordinator = CarPlayNowPlayingCoordinator(
            playback: ContextPlayback(),
            onErrorWithContext: { error, origin in

                #expect(error as? CarPlayError == .disconnected)
                reported.continuation.yield(origin)
            },
            upNext: { CarPlayList {} }
        )
        coordinator.connect(context: .init())
        coordinator.nowPlayingTemplateUpNextButtonTapped(.shared)
        var iterator = reported.stream.makeAsyncIterator()
        let origin = try #require(await iterator.next())
        #expect(origin.source == .navigation)
        #expect(origin.control == .nowPlayingDestination)
        coordinator.disconnect()
    }
}

private extension CarPlayNowPlayingTests {

    @MainActor
    final class ContextPlayback: CarPlayNowPlayingPlayback {

        var hasUpNext: Bool {
            true
        }

        func cyclePlaybackRate() {}
        func toggleShuffle() {}
        func cycleRepeatMode() {}
    }
}
