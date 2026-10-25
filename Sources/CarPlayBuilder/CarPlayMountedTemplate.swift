// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Coordinates native template identity, reconciliation, and screen lifecycle.
@MainActor
final class CarPlayMountedTemplate {

    let screenID = UUID()
    let template: CPTemplate
    private(set) var content: CarPlayTemplateContent
    private let defaultTabSystemItem: UITabBarItem.SystemItem
    private let scope: CarPlayTaskScope
    private let errorRouter: CarPlayErrorRouter
    private let list: CarPlayMountedList?
    private let grid: CarPlayMountedGrid?
    private let tabs: CarPlayMountedTabs?
    private let toolbar: CarPlayMountedToolbar
    private var active = true
    private var visible = false

    init(
        content: CarPlayTemplateContent,
        context: CarPlayContext,
        onError: @escaping CarPlayErrorHandler = { _ in },
        onErrorWithContext: CarPlayContextualErrorHandler? = nil
    ) throws {

        try CarPlayTemplateValidation.validate(content)
        let template = Self.makeTemplate(content.kind)
        let errorRouter = CarPlayErrorRouter(
            context: context,
            onError: onErrorWithContext ?? { error, _ in onError(error) }
        )
        let scope = CarPlayTaskScope(onErrorWithContext: errorRouter.report)
        self.content = content
        self.template = template
        self.defaultTabSystemItem = template.tabSystemItem
        self.errorRouter = errorRouter
        self.scope = scope
        self.list = (template as? CPListTemplate).map {

            CarPlayMountedList(template: $0, context: context, scope: scope)
        }
        self.grid = (template as? CPGridTemplate).map {

            CarPlayMountedGrid(template: $0, context: context, scope: scope)
        }
        self.tabs = (template as? CPTabBarTemplate).map {

            CarPlayMountedTabs(
                template: $0,
                context: context,
                onError: errorRouter.report
            )
        }
        self.toolbar = CarPlayMountedToolbar(
            template: template,
            context: context,
            scope: scope
        )
        try self.update(content)
    }

    /// Validates content before reconciling controls and lifecycle work.
    func update(_ next: CarPlayTemplateContent) throws {

        guard self.active else {

            throw CarPlayError.disconnected
        }

        try self.validateUpdate(next)
        self.content = next
        self.errorRouter.update(next.errorHandlers)
        self.scope.screenID = self.screenID
        self.scope.screenTitle = self.screenTitle

        switch next.kind {

        case let .list(_, sections):
            self.list?.update(next, sections: sections)

        case let .grid(title, buttons):
            self.grid?.update(buttons, title: title)

        case let .tabs(tabs):
            try self.tabs?.update(tabs, handler: next.tabSelectionHandler)

        case .nowPlaying:
            break
        }

        self.toolbar.update(next)
        self.scope.update(next.tasks, visible: self.visible)
    }

    private var screenTitle: String? {

        switch self.content.kind {

        case let .grid(title, _),
             let .list(title, _):
            title

        case .nowPlaying,
             .tabs:
            nil
        }
    }

    /// Routes rejected updates through the last accepted error handlers.
    func reportError(_ error: Error) {

        self.errorRouter.report(error, context: .init(
            source: .rendering,
            screenID: self.screenID,
            screenTitle: self.screenTitle
        ))
    }

    /// Shares programmatic selection notifications with the native delegate.
    func didSelectTab(_ template: CPTemplate) {

        self.tabs?.didSelectTab(template)
    }

    /// Rejects kind and fixed list-title changes before any native mutation.
    func validateUpdate(_ next: CarPlayTemplateContent) throws {

        try CarPlayTemplateValidation.validate(next)

        switch (self.content.kind, next.kind) {

        case let (.list(title, _), .list(nextTitle, _)):

            guard title == nextTitle else {

                throw CarPlayError
                    .invalidContent(
                        "A mounted list title is fixed. "
                            + "Push a new screen to change it."
                    )
            }

        case (.grid, .grid),
             (.nowPlaying, .nowPlaying):
            break

        case let (.tabs, .tabs(tabs)):
            try self.tabs?.validateUpdate(tabs)

        default:
            throw CarPlayError
                .invalidContent(
                    "A mounted screen must keep its template kind. "
                        + "Change its content or push a new screen."
                )
        }
    }

    /// Propagates native visibility to the matching screen and its task scope.
    func setVisible(_ visible: Bool, for target: CPTemplate) {

        guard self.active else {

            return
        }

        if target === self.template, self.visible != visible {

            self.visible = visible
            let callbacks = visible ? self.content.appear : self.content.disappear

            for callback in callbacks {

                callback()

                guard self.active, self.visible == visible else {

                    return
                }
            }

            self.scope.update(self.content.tasks, visible: self.visible)
        }

        self.tabs?.setVisible(visible, for: target)
    }

    /// Ends visibility and cancels controls, tasks, and descendant screens.
    func cancel() {

        guard self.active else {

            return
        }

        self.active = false
        if self.visible {

            self.visible = false
            for item in self.content.disappear {

                item()
            }
        }

        self.toolbar.cancel()
        self.errorRouter.cancel()
        self.list?.cancel()
        self.grid?.cancel()
        self.scope.cancel()
        self.tabs?.cancel()
    }

    func updateTabLabel(_ label: CarPlayTabLabel) {

        self.template.tabTitle = nil
        self.template.tabImage = nil
        // Restore the native unset value without assuming its raw value.
        self.template.tabSystemItem = self.defaultTabSystemItem

        switch label {

        case let .title(title):
            self.template.tabTitle = title

        case let .image(image):
            self.template.tabImage = image

        case let .titleAndImage(title, image):
            self.template.tabTitle = title
            self.template.tabImage = image

        case let .system(item):
            self.template.tabSystemItem = item
        }
    }
}

private extension CarPlayMountedTemplate {

    static func makeTemplate(_ kind: CarPlayTemplateContent.Kind) -> CPTemplate {

        switch kind {

        case let .list(title, _):
            CPListTemplate(title: title, sections: [])

        case let .grid(title, _):
            CPGridTemplate(title: title, gridButtons: [])

        case .tabs:
            CPTabBarTemplate(templates: [])

        case .nowPlaying:
            CPNowPlayingTemplate.shared
        }
    }
}
