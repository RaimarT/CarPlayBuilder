// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation

/// Status labels and error mapping for default loading-state presentation.
public struct CarPlayLoadingConfiguration: Sendable {

    /// The title and grid symbol shown for idle or running requests.
    public var loading: CarPlayStatusLabel

    /// Maps the original error to a title, symbol, and optional explanation.
    ///
    /// Defaults to the standard failure label and `localizedDescription`.
    /// Invoked once when rendering default failure content. Custom failure
    /// builders bypass this provider unless they explicitly call it themselves.
    public var failure: CarPlayErrorPresentationProvider

    /// The title and grid symbol shown for a successful empty result.
    public var empty: CarPlayStatusLabel

    /// The title and grid symbol of the optional retry action.
    public var retry: CarPlayStatusLabel

    /// Creates status presentation using standard English labels by default.
    ///
    /// Supply app-localized labels and error mapping for other languages.
    /// Custom builders supply their own presentation and recovery actions.
    ///
    /// - Parameters:
    ///   - loading: Label for idle or loading status.
    ///   - failure: Inexpensive error-to-presentation mapping. Lists display its
    ///     title and message; grids display its title and symbol.
    ///   - empty: Label for successful empty results.
    ///   - retry: Label for the optional default recovery action.
    public init(
        loading: CarPlayStatusLabel = .loading,
        failure: @escaping CarPlayErrorPresentationProvider = {

            .init(message: $0.localizedDescription)
        },
        empty: CarPlayStatusLabel = .empty,
        retry: CarPlayStatusLabel = .retry
    ) {

        self.loading = loading
        self.failure = failure
        self.empty = empty
        self.retry = retry
    }
}
