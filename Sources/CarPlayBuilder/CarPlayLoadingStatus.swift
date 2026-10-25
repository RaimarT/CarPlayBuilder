// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Resolves resource state while preserving the original error for custom content.
@MainActor
enum CarPlayLoadingStatus {

    case loading(initial: Bool)
    case failure(any Error)
    case empty

    init?(state: CarPlayLoadState, isEmpty: Bool) {

        switch state {

        case .idle:
            self = .loading(initial: true)

        case .loading:
            self = .loading(initial: false)

        case let .failed(error):
            self = .failure(error)

        case .loaded:

            guard isEmpty else {

                return nil
            }

            self = .empty
        }
    }

    /// Whether usable content can remain visible instead of being replaced.
    var allowsRetention: Bool {

        switch self {

        case .loading(initial: false), .failure:
            true

        case .loading(initial: true), .empty:
            false
        }
    }

    var isLoading: Bool {

        if case .loading = self {

            return true
        }

        return false
    }

    func rows(
        configuration: CarPlayLoadingConfiguration,
        retry: CarPlayTaskAction?
    ) -> [CarPlayRow] {

        let presentation = self.presentation(configuration)
        var rows = [
            CarPlayRow(
                presentation.label.title,
                detail: presentation.message
            ).disabled()
        ]

        if !self.isLoading, let retry {

            rows.append(CarPlayRow(configuration.retry.title) { _ in

                try await retry()
            })
        }

        return rows
    }

    func buttons(
        configuration: CarPlayLoadingConfiguration,
        retry: CarPlayTaskAction?
    ) -> [CarPlayButton] {

        let label = self.presentation(configuration).label
        let image = UIImage(systemName: label.systemImage) ?? UIImage()
        let status = CarPlayButton(label.title, image: image) { _ in }
        var buttons = [status.disabled()]

        if !self.isLoading, let retry {

            let image = UIImage(systemName: configuration.retry.systemImage)
                ?? UIImage()
            buttons.append(CarPlayButton(configuration.retry.title, image: image) {
                _ in

                try await retry()
            })
        }

        return buttons
    }
}

private extension CarPlayLoadingStatus {

    /// Resolves all error-dependent values together with one provider invocation.
    func presentation(
        _ configuration: CarPlayLoadingConfiguration
    ) -> CarPlayErrorPresentation {

        switch self {

        case .loading:
            .init(label: configuration.loading)

        case let .failure(error):
            configuration.failure(error)

        case .empty:
            .init(label: configuration.empty)
        }
    }
}
