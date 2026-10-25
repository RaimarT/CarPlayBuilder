// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A native list screen composed of sections and selectable rows.
///
/// The content closure is evaluated again when observed state changes. The
/// mounted list keeps its original title; push or replace the screen to change it.
public struct CarPlayList: CarPlayTemplate {

    /// Primitive templates have no compositional body.
    ///
    /// The renderer uses `_resolve()` instead; accessing `body` traps.
    public typealias Body = Never
    private let title: String?
    private var header: CarPlayListHeader?
    private var emptyViewTitleVariants: [String]?
    private var emptyViewSubtitleVariants: [String]?
    private var emptyViewSpinner: Bool?
    private let sections: () -> [CarPlaySection]

    /// Creates a list with a title fixed for its mounted lifetime.
    ///
    /// - Parameters:
    ///   - title: The navigation title, or `nil` for no title.
    ///   - content: Sections evaluated during each render. Use stable IDs for
    ///     dynamic sections and rows.
    public init(
        _ title: String? = nil,
        @CarPlaySectionBuilder content: @escaping @MainActor () -> [CarPlaySection]
    ) {

        self.title = title
        self.sections = content
    }

    /// Sets artwork, text, and actions above the list's sections.
    ///
    /// Pass `nil` or omit the modifier on a later render to remove the header.
    /// Apply before template-wide modifiers such as `loadingState`. The header
    /// remains visible through loading presentation and is separate from the
    /// navigation title and section headers.
    ///
    /// - Parameter header: The rich header, or `nil` to remove it.
    /// - Returns: A list with the requested header presentation.
    @available(iOS 26.4, *)
    public func listHeader(_ header: CarPlayListHeader?) -> Self {

        var copy = self
        copy.header = header

        return copy
    }

    /// Configures native fallback text shown when the list has zero items.
    ///
    /// Supply localized strings in preference order, typically longest to shortest.
    /// CarPlay selects the first variant that fits. Empty arrays clear the text.
    /// Omitting this modifier on a later render restores the native defaults.
    /// Loading-state rows suppress the empty view while they contain any items.
    /// Apply this modifier before template-wide modifiers such as `loadingState`.
    ///
    /// - Parameters:
    ///   - titleVariants: Alternative primary labels for the native empty view.
    ///   - subtitleVariants: Alternative supporting labels; defaults to no text.
    /// - Returns: A list with the requested native empty-view presentation.
    public func emptyView(
        titleVariants: [String],
        subtitleVariants: [String] = []
    ) -> Self {

        var copy = self
        copy.emptyViewTitleVariants = titleVariants
        copy.emptyViewSubtitleVariants = subtitleVariants

        return copy
    }

    /// Shows a native activity indicator while the list contains zero items.
    ///
    /// The spinner appears alongside native empty-view text. It is hidden while
    /// any rows exist, including default loading-state rows. Use an empty custom
    /// loading builder to leave the native empty view available. This modifier
    /// changes presentation only and does not start or track loading work.
    /// Omitting it on a later render restores the native default.
    ///
    /// - Parameter visible: Whether to show the spinner when empty; defaults to
    ///   `true`. Pass app-owned loading state to stop it when loading finishes.
    /// - Returns: A list with the requested empty-view spinner setting.
    @available(iOS 18.4, *)
    public func showsSpinnerWhileEmpty(_ visible: Bool = true) -> Self {

        var copy = self
        copy.emptyViewSpinner = visible

        return copy
    }

    /// Resolves this value for the package’s native renderer.
    ///
    /// Applications use the declarative value rather than calling this directly.
    /// - Returns: The opaque rendering description.
    public func _resolve() -> CarPlayTemplateContent {

        var content = CarPlayTemplateContent(
            kind: .list(self.title, self.sections())
        )
        content.listHeader = self.header
        content.emptyViewTitleVariants = self.emptyViewTitleVariants
        content.emptyViewSubtitleVariants = self.emptyViewSubtitleVariants
        content.emptyViewSpinner = self.emptyViewSpinner

        return content
    }
}

extension CarPlayList: CarPlayLoadableTemplate {

    /// The native item accepted by custom loading-state builders.
    public typealias LoadingItem = CarPlayRow
}

/// Creates a disclosure row that constructs its destination on selection.
///
/// - Parameters:
///   - title: The row’s primary text.
///   - detail: Optional secondary text.
///   - image: Optional leading artwork.
///   - destination: A lazy destination description. Errors from pushing it
///     reach the host’s error handler.
/// - Returns: A row that can be given an ID or further row modifiers.
@MainActor
public func CarPlayNavigationLink(
    _ title: String,
    detail: String? = nil,
    image: UIImage? = nil,
    destination: @escaping @MainActor () -> some CarPlayTemplate
) -> CarPlayRow {

    CarPlayRow(title, detail: detail, image: image) { context in

        try await context.push(content: destination)
    }
    .accessory(.disclosureIndicator)
}
