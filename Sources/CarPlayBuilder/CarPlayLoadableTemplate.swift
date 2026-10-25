// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A list or grid supporting loading, failure, and empty-state presentation.
public protocol CarPlayLoadableTemplate: CarPlayTemplate {

    /// The item type accepted by custom status builders.
    ///
    /// Use `CarPlayRow` for lists and `CarPlayButton` for grids. `Never` keeps
    /// automatic presentation available to existing custom conformers.
    associatedtype LoadingItem = Never
}

public extension CarPlayLoadableTemplate {

    /// Presents default loading, failure, or empty content on a list or grid.
    ///
    /// Idle and loading show a disabled status item. Failure and loaded empty
    /// states can include retry. Loaded nonempty content remains unchanged.
    /// Template kind, title, toolbars, and lifecycle modifiers are preserved.
    ///
    /// - Parameters:
    ///   - state: The resource state controlling presentation.
    ///   - isEmpty: Whether the app has usable content. Retention additionally
    ///     requires the template to contain rows or buttons.
    ///   - retainsContentDuringRefresh: Keeps nonempty content during loading
    ///     and appends failure status after a failed refresh. Idle still shows
    ///     initial loading. Defaults to replacing content for every status.
    ///   - configuration: Localizable labels, grid symbols, and error messages.
    ///   - retry: Optional recovery work for default failure and empty content.
    /// - Returns: A modified template with status presentation.
    func loadingState(
        _ state: CarPlayLoadState,
        isEmpty: Bool = false,
        retainsContentDuringRefresh: Bool = false,
        configuration: CarPlayLoadingConfiguration = .init(),
        retry: CarPlayTaskAction? = nil
    ) -> CarPlayModifiedTemplate<Self> {

        self.loadingPresentation(
            state,
            isEmpty: isEmpty,
            retainsContentDuringRefresh: retainsContentDuringRefresh,
            configuration: configuration,
            retry: retry
        )
    }
}

extension CarPlayLoadableTemplate {

    /// Shares presentation rules between automatic, list, and grid overloads.
    func loadingPresentation(
        _ state: CarPlayLoadState,
        isEmpty: Bool,
        retainsContentDuringRefresh: Bool,
        configuration: CarPlayLoadingConfiguration,
        rows: CarPlayStatusContent<CarPlayRow>? = nil,
        buttons: CarPlayStatusContent<CarPlayButton>? = nil,
        retry: CarPlayTaskAction?
    ) -> CarPlayModifiedTemplate<Self> {

        let presentation = CarPlayLoadingPresentation(
            status: CarPlayLoadingStatus(state: state, isEmpty: isEmpty),
            retainsContent: retainsContentDuringRefresh && !isEmpty,
            configuration: configuration,
            rows: rows,
            buttons: buttons,
            retry: retry
        )

        return CarPlayModifiedTemplate(content: self) { content in

            presentation.apply(to: &content)
        }
    }
}
