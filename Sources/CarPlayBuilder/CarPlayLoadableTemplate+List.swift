// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

public extension CarPlayLoadableTemplate where LoadingItem == CarPlayRow {

    /// Presents app-defined status rows while retaining the native list screen.
    ///
    /// Builders are evaluated only for the visible status. Omitted builders use
    /// default presentation; returning `nil` also uses defaults. Custom rows own
    /// their actions; `retry` is not
    /// appended to custom content. Retained failure rows occupy a new section,
    /// and all content must still respect native CarPlay item limits.
    ///
    /// - Parameters:
    ///   - state: The original resource state, including its underlying error.
    ///   - isEmpty: Whether the app has usable content for retention.
    ///   - retainsContentDuringRefresh: Keeps nonempty content while loading and
    ///     appends failure rows after a failed refresh. Idle is never retained.
    ///   - configuration: Default labels, symbols, and error-message mapping.
    ///   - loading: Rows for idle or loading, unless content is retained.
    ///   - empty: Rows for a successful empty result.
    ///   - failure: Rows built from the original failure for app-specific recovery.
    ///   - retry: Recovery work used only by default empty or failure content.
    /// - Returns: A modified list preserving title, toolbars, and lifecycle work.
    func loadingState(
        _ state: CarPlayLoadState,
        isEmpty: Bool = false,
        retainsContentDuringRefresh: Bool = false,
        configuration: CarPlayLoadingConfiguration = .init(),
        @CarPlayRowBuilder
        loading: @escaping CarPlayLoadingContent<CarPlayRow> = { nil },
        @CarPlayRowBuilder
        empty: @escaping CarPlayLoadingContent<CarPlayRow> = { nil },
        @CarPlayRowBuilder
        failure: @escaping CarPlayFailureContent<CarPlayRow> = { _ in nil },
        retry: CarPlayTaskAction? = nil
    ) -> CarPlayModifiedTemplate<Self> {

        self.loadingPresentation(
            state,
            isEmpty: isEmpty,
            retainsContentDuringRefresh: retainsContentDuringRefresh,
            configuration: configuration,
            rows: { status in

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
