// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

public extension CarPlayLoadableTemplate where LoadingItem == CarPlayButton {

    /// Presents app-defined status buttons while retaining the native grid screen.
    ///
    /// Builders are evaluated only for the visible status. Omitted builders use
    /// default presentation; returning `nil` also uses defaults. Custom buttons own
    /// their actions; `retry` is not
    /// appended to custom content. Retained failure buttons follow existing content,
    /// and all content must still respect native CarPlay item limits.
    ///
    /// - Parameters:
    ///   - state: The original resource state, including its underlying error.
    ///   - isEmpty: Whether the app has usable content for retention.
    ///   - retainsContentDuringRefresh: Keeps nonempty content while loading and
    ///     appends failure buttons after a failed refresh. Idle is never retained.
    ///   - configuration: Default labels, symbols, and error-message mapping.
    ///   - loading: Buttons for idle or loading, unless content is retained.
    ///   - empty: Buttons for a successful empty result.
    ///   - failure: Buttons built from the original failure for app-specific
    /// recovery.
    ///   - retry: Recovery work used only by default empty or failure content.
    /// - Returns: A modified grid preserving title, toolbars, and lifecycle work.
    func loadingState(
        _ state: CarPlayLoadState,
        isEmpty: Bool = false,
        retainsContentDuringRefresh: Bool = false,
        configuration: CarPlayLoadingConfiguration = .init(),
        @CarPlayButtonBuilder
        loading: @escaping CarPlayLoadingContent<CarPlayButton> = { nil },
        @CarPlayButtonBuilder
        empty: @escaping CarPlayLoadingContent<CarPlayButton> = { nil },
        @CarPlayButtonBuilder
        failure: @escaping CarPlayFailureContent<CarPlayButton> = { _ in nil },
        retry: CarPlayTaskAction? = nil
    ) -> CarPlayModifiedTemplate<Self> {

        self.loadingPresentation(
            state,
            isEmpty: isEmpty,
            retainsContentDuringRefresh: retainsContentDuringRefresh,
            configuration: configuration,
            buttons: { status in

                switch status {

                case .loading:
                    loading()

                case .empty:
                    empty()

                case let .failure(error):
                    failure(error)
                }
            },
            retry: retry
        )
    }
}
