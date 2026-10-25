// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// Own one host per connected CarPlay scene and call `disconnect()` when that scene
/// disconnects.
@MainActor
public final class CarPlayHost: NSObject {

    private weak var interfaceController: (any CarPlayInterface)?
    private var content: CarPlayContentProvider
    private let onError: CarPlayContextualErrorHandler
    private let navigationObserver: CarPlayNavigationObserver
    private var screens: [CarPlayScreen] = []
    private var connected = false
    private var navigationID: UUID?
    private var navigating: Bool {
        self.navigationID != nil
    }

    private var generation = 0
    private var modalID: UUID?
    private var modalSelectionID: UUID?
    private lazy var actionScope = CarPlayTaskScope(onErrorWithContext: self.onError)

    /// Creates a scene-owned host without presenting its root yet.
    ///
    /// Retain the host for the scene’s connection lifetime. The interface
    /// controller is held weakly, so the scene must keep it alive. The host
    /// installs itself as the controller’s delegate when connected.
    ///
    /// - Parameters:
    ///   - interfaceController: The controller supplied by the CarPlay scene.
    ///   - onError: Receives rendering, action, and lifecycle task errors.
    ///     Handle cancellation and explicit `connect` errors at the call site.
    ///   - onErrorWithContext: Optional origin-aware callback replacing
    ///     `onError` when supplied. Receives the original error. If neither error
    ///     callback is supplied, unhandled errors are ignored.
    ///   - onNavigation: Completed navigation changes with before/after snapshots.
    ///     Runs after the navigation gate is released; no-ops are suppressed.
    ///   - content: A repeatable root description. Reads of observable state
    ///     are tracked and cause subsequent native content updates.
    public init(
        interfaceController: CPInterfaceController,
        onError: @escaping CarPlayErrorHandler = { _ in },
        onErrorWithContext: CarPlayContextualErrorHandler? = nil,
        onNavigation: @escaping CarPlayNavigationHandler = { _ in },
        content: @escaping @MainActor () -> some CarPlayTemplate
    ) {

        self.navigationObserver = CarPlayNavigationObserver(handler: onNavigation)
        self.interfaceController = interfaceController
        self.onError = onErrorWithContext ?? { error, _ in onError(error) }
        self.content = {

            content()._resolve()
        }
    }

    /// Injectable transport keeps navigation and disconnect behavior testable
    /// without a car.
    init(
        interface: any CarPlayInterface,
        onError: @escaping CarPlayErrorHandler = { _ in },
        onErrorWithContext: CarPlayContextualErrorHandler? = nil,
        onNavigation: @escaping CarPlayNavigationHandler = { _ in },
        content: @escaping CarPlayContentProvider
    ) {

        self.navigationObserver = CarPlayNavigationObserver(handler: onNavigation)
        self.interfaceController = interface
        self.onError = onErrorWithContext ?? { error, _ in onError(error) }
        self.content = content
    }

    isolated deinit {

        self.disconnect()
    }

    /// The navigation context for native controls and scene delegates.
    ///
    /// The context holds a weak reference to this host. Navigation requires a
    /// connected host and throws after the scene disconnects.
    public var context: CarPlayContext {

        CarPlayContext(host: self)
    }

    /// Validates the root and presents it on the scene’s interface controller.
    ///
    /// Calling this on an already connected, idle host does nothing. A failed
    /// native root presentation tears down that connection.
    ///
    /// - Parameter animated: Whether CarPlay animates the root presentation.
    /// - Throws: Cancellation, invalid content, a missing controller, a navigation
    ///   conflict, native presentation errors, or a rejected presentation.
    public func connect(animated: Bool = false) async throws {

        try Task.checkCancellation()

        guard let interfaceController else {

            throw CarPlayError.disconnected
        }

        guard !self.navigating else {

            throw CarPlayError.operationInProgress
        }

        guard !self.connected else {

            return
        }

        self.navigationID = UUID()
        let generation = self.generation
        let operationID = self.navigationID

        defer {

            self.finishNavigation(generation: generation, operationID: operationID)
        }

        let screen = try self.makeScreen(content: self.content)
        self.screens = [screen]
        self.connected = true
        interfaceController.delegate = self

        try await self.presentRoot(
            screen,
            on: interfaceController,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    /// Stops observation and cancels scene-owned tasks and selection actions.
    ///
    /// Call this from the scene’s disconnect callback. Repeated calls are safe.
    /// It clears the host’s delegate registration and retained screens; it does
    /// not stop your audio player or cancel app-owned shared resources.
    public func disconnect() {

        let wasConnected = self.connected
        self.connected = false
        self.navigationID = nil
        self.generation += 1
        self.modalID = nil
        self.modalSelectionID = nil
        self.actionScope.cancel()

        for screen in self.screens {

            screen.cancel()
        }
        self.screens.removeAll()

        if self.interfaceController?.delegate === self {

            self.interfaceController?.delegate = nil
        }

        if wasConnected {

            self.navigationObserver.update(
                .init(stack: [], modal: nil),
                kind: .disconnected,
                origin: .programmatic,
                animated: false
            )
        }
    }

    func push(
        animated: Bool,
        content: @escaping @MainActor () -> some CarPlayTemplate
    ) async throws {

        let interface = try self.beginNavigation()
        let generation = self.generation
        let operationID = self.navigationID

        defer {

            self.finishNavigation(
                generation: generation,
                operationID: operationID
            )
        }

        let screen = try self.makeScreen {

            content()._resolve()
        }
        try CarPlayTemplateValidation.validate(
            screen.node.content,
            allowsTabs: false
        )

        if try await self.popExistingDestination(
            screen,
            on: interface,
            animated: animated,
            generation: generation,
            operationID: operationID
        ) {

            return
        }

        self.screens.append(screen)
        try await self.presentDestination(
            screen,
            on: interface,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    func pop(animated: Bool) async throws {

        let interface = try self.beginNavigation()
        let generation = self.generation
        let operationID = self.navigationID

        defer {

            self.finishNavigation(
                generation: generation,
                operationID: operationID
            )
        }

        let accepted = try await interface.popTemplate(animated: animated)
        try self.validatePresentation(accepted, generation: generation)
        self.recordNavigation(
            .popped,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    func popToRoot(animated: Bool) async throws {

        let interface = try self.beginNavigation()
        let generation = self.generation
        let operationID = self.navigationID

        defer {

            self.finishNavigation(
                generation: generation,
                operationID: operationID
            )
        }

        try await self.popRoot(
            on: interface,
            animated: animated,
            generation: generation
        )
        self.recordNavigation(
            .poppedToRoot,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    func selectTab(id: AnyHashable, animated: Bool) async throws {

        let interface = try self.beginNavigation()
        let generation = self.generation
        let operationID = self.navigationID
        defer {

            self.recordNavigation(
                .poppedToRoot,
                animated: animated,
                generation: generation,
                operationID: operationID
            )
            self.finishNavigation(
                generation: generation,
                operationID: operationID
            )
        }

        guard let root = self.screens.first,
              let native = root.node.template as? CPTabBarTemplate
        else {

            throw CarPlayError.invalidContent("The requested tab does not exist.")
        }

        _ = try self.tabTemplate(id: id, in: root.node)
        try await self.popRoot(
            on: interface,
            animated: animated,
            generation: generation
        )
        try self.validatePresentation(true, generation: generation)
        let selected = try self.tabTemplate(id: id, in: root.node)
        interface.selectTemplate(selected, in: native)
        root.node.didSelectTab(selected)
    }

    func replaceRoot(
        animated: Bool,
        content: @escaping CarPlayContentProvider
    ) async throws {

        let interface = try self.beginNavigation()
        let generation = self.generation
        let operationID = self.navigationID

        defer {

            self.finishNavigation(
                generation: generation,
                operationID: operationID
            )
        }

        let screen = try self.makeScreen(content: content)
        try await self.replaceRoot(
            screen,
            content: content,
            on: interface,
            animated: animated,
            generation: generation
        )
        self.recordNavigation(
            .rootReplaced,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    func present(_ content: CarPlayModalContent, animated: Bool) async throws {

        let interface = try self.beginNavigation()
        let generation = self.generation
        let operationID = self.navigationID

        defer {

            self.finishNavigation(
                generation: generation,
                operationID: operationID
            )
        }

        let id = UUID()
        let template = try content.makeTemplate { [weak self] index in

            self?.selectModalAction(index, content: content, id: id)
        }
        self.modalID = id

        do {

            let accepted = try await interface.presentTemplate(
                template,
                animated: animated
            )
            try self.validatePresentation(accepted, generation: generation)
        } catch {

            if self.modalID == id {

                self.modalID = nil
            }
            throw error
        }
        self.recordNavigation(
            .modalPresented,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    func dismiss(animated: Bool) async throws {

        let interface = try self.beginNavigation(allowsModal: true)
        let generation = self.generation
        let operationID = self.navigationID

        defer {

            self.finishNavigation(
                generation: generation,
                operationID: operationID
            )
        }

        if interface.presentedTemplate != nil {

            let accepted = try await interface.dismissTemplate(animated: animated)
            try self.validatePresentation(accepted, generation: generation)
        }
        self.modalID = nil
        self.modalSelectionID = nil
        self.recordNavigation(
            .modalDismissed,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }
}

extension CarPlayHost: CPInterfaceControllerDelegate {

    /// Forwards native appearance to matching screens and starts lifecycle work.
    ///
    /// This is a CarPlay delegate entry point; applications do not call it.
    public func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {

        for screen in self.screens {

            screen.node.setVisible(true, for: aTemplate)
        }
    }

    /// Forwards native disappearance and cancels visibility-bound tasks.
    ///
    /// This is a CarPlay delegate entry point; applications do not call it.
    public func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {

        for screen in self.screens {

            screen.node.setVisible(false, for: aTemplate)
        }
    }

    /// Releases screens removed from the native stack after appearance.
    ///
    /// This is a CarPlay delegate entry point; applications do not call it.
    public func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {

        self.observeNativeNavigation(animated: animated)
    }

    /// Releases screens removed by native navigation, including the Back button.
    ///
    /// This is a CarPlay delegate entry point; applications do not call it.
    public func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {

        self.observeNativeNavigation(animated: animated)
    }
}

private extension CarPlayHost {

    /// Claims one modal selection and dismisses it before running the callback.
    func selectModalAction(_ index: Int, content: CarPlayModalContent, id: UUID) {

        guard self.modalID == id, self.modalSelectionID != id,
              content.actions.indices.contains(index)
        else {

            return
        }

        self.modalSelectionID = id
        let action = content.actions[index].action
        let context = self.context
        self.actionScope.perform(
            { [weak self] in

                guard try await self?.dismissSelection(id: id) == true else {

                    return
                }

                try Task.checkCancellation()
                try await action(context)
            },
            control: .modalAction,
            controlID: index
        )
    }

    func dismissSelection(id: UUID) async throws -> Bool {

        guard self.modalID == id else {

            return false
        }

        defer {

            if self.modalID == id {

                self.modalSelectionID = nil
            }
        }
        try await self.dismiss(animated: true)
        return true
    }

    /// Resolves against current observed tabs, including after native awaits.
    func tabTemplate(
        id: AnyHashable,
        in node: CarPlayMountedTemplate
    ) throws -> CPTemplate {

        guard case let .tabs(tabs) = node.content.kind,
              let index = tabs.firstIndex(where: { $0.id == id }),
              let native = node.template as? CPTabBarTemplate,
              native.templates.indices.contains(index)
        else {

            throw CarPlayError.invalidContent("The requested tab does not exist.")
        }

        return native.templates[index]
    }

    func popRoot(
        on interface: any CarPlayInterface,
        animated: Bool,
        generation: Int
    ) async throws {

        guard interface.templates.count > 1 else {

            return
        }

        let accepted = try await interface.popToRootTemplate(animated: animated)
        try self.validatePresentation(accepted, generation: generation)
    }

    func replaceRoot(
        _ screen: CarPlayScreen,
        content: @escaping CarPlayContentProvider,
        on interface: any CarPlayInterface,
        animated: Bool,
        generation: Int
    ) async throws {

        let previous = self.screens
        self.screens.append(screen)

        do {

            let accepted = try await interface.setRootTemplate(
                screen.node.template,
                animated: animated
            )
            try self.validatePresentation(accepted, generation: generation)
            self.screens = [screen]
            self.content = content
            for old in previous {

                old.cancel()
            }
        } catch {

            screen.cancel()
            if self.generation == generation {

                self.screens = previous
            }
            throw error
        }
    }

    func makeScreen(
        content: @escaping CarPlayContentProvider
    ) throws -> CarPlayScreen {

        try CarPlayScreen(
            content: content,
            context: self.context,
            onErrorWithContext: self.onError
        )
    }

    /// Serializes navigation and rejects disconnected or modal-blocked operations.
    func beginNavigation(allowsModal: Bool = false) throws -> any CarPlayInterface {

        try Task.checkCancellation()

        guard self.connected, let interfaceController else {

            throw CarPlayError.disconnected
        }

        guard !self.navigating,
              allowsModal || (self.modalID == nil
                  && interfaceController.presentedTemplate == nil)
        else {

            throw CarPlayError.operationInProgress
        }

        self.navigationID = UUID()

        return interfaceController
    }

    /// Releases only the operation that acquired the navigation gate.
    @discardableResult
    func finishNavigation(generation: Int, operationID: UUID?) -> Bool {

        guard self.generation == generation, let operationID,
              self.navigationID == operationID
        else {

            return false
        }

        self.navigationID = nil
        self.pruneScreens()
        return true
    }

    /// Rejects stale results from a previous connection generation.
    ///
    /// An awaited native operation can finish after disconnect or reconnection;
    /// its result must never change the new connection’s state.
    func validatePresentation(_ accepted: Bool, generation: Int) throws {

        guard accepted else {

            throw CarPlayError.presentationRejected
        }

        guard self.connected, self.generation == generation else {

            throw CarPlayError.disconnected
        }
    }

    func presentRoot(
        _ screen: CarPlayScreen,
        on interface: any CarPlayInterface,
        animated: Bool,
        generation: Int,
        operationID: UUID?
    ) async throws {

        do {

            let accepted = try await interface.setRootTemplate(
                screen.node.template,
                animated: animated
            )
            try self.validatePresentation(accepted, generation: generation)
        } catch {

            if self.generation == generation {

                self.disconnect()
            }
            throw error
        }
        self.recordNavigation(
            .connected,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    func popExistingDestination(
        _ screen: CarPlayScreen,
        on interface: any CarPlayInterface,
        animated: Bool,
        generation: Int,
        operationID: UUID?
    ) async throws -> Bool {

        guard interface.templates.contains(where: {

            $0 === screen.node.template
        })
        else {

            return false
        }

        screen.cancel()
        let accepted = try await interface.popToTemplate(
            screen.node.template,
            animated: animated
        )
        try self.validatePresentation(accepted, generation: generation)
        self.recordNavigation(
            .popped,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
        return true
    }

    func presentDestination(
        _ screen: CarPlayScreen,
        on interface: any CarPlayInterface,
        animated: Bool,
        generation: Int,
        operationID: UUID?
    ) async throws {

        do {

            let accepted = try await interface.pushTemplate(
                screen.node.template,
                animated: animated
            )
            try self.validatePresentation(accepted, generation: generation)
        } catch {

            screen.cancel()
            self.screens.removeAll {

                $0 === screen
            }
            throw error
        }
        self.recordNavigation(
            .pushed,
            animated: animated,
            generation: generation,
            operationID: operationID
        )
    }

    /// Cancels popped screens after native navigation settles, preserving root.
    func pruneScreens() {

        guard !self.navigating, let interfaceController else {

            return
        }

        let stack = interfaceController.templates
        for screen in self.screens.dropFirst()
            where !stack.contains(where: {

                $0 === screen.node.template
            }) {

            screen.cancel()
        }
        self.screens = self.screens.enumerated().compactMap { index, screen in

            index == 0 || stack
                .contains(where: {

                    $0 === screen.node.template
                }) ? screen : nil
        }
    }
}

private extension CarPlayHost {

    func recordNavigation(
        _ kind: CarPlayNavigationKind,
        animated: Bool,
        generation: Int,
        operationID: UUID?
    ) {

        guard self.connected, self.generation == generation else {

            return
        }

        guard self.finishNavigation(
            generation: generation,
            operationID: operationID
        ), self.connected, self.generation == generation
        else {

            return
        }

        self.navigationObserver.update(
            self.navigationState(),
            kind: kind,
            origin: .programmatic,
            animated: animated
        )
    }

    func observeNativeNavigation(animated: Bool) {

        guard self.connected, !self.navigating else {

            return
        }

        self.pruneScreens()
        if self.interfaceController?.presentedTemplate == nil {

            self.modalID = nil
            self.modalSelectionID = nil
        }
        self.navigationObserver.update(
            self.navigationState(),
            origin: .native,
            animated: animated
        )
    }

    func navigationState() -> CarPlayNavigationState {

        let stack = self.interfaceController?.templates.compactMap { template in

            self.screens.first { $0.node.template === template }?.node
                .navigationScreen
        } ?? []
        return .init(stack: stack, modal: self.navigationModal())
    }

    func navigationModal() -> CarPlayNavigationScreen? {

        guard let id = self.modalID,
              let template = self.interfaceController?.presentedTemplate
        else {

            return nil
        }

        if let alert = template as? CPAlertTemplate {

            return .init(id: id, kind: .alert, title: alert.titleVariants.first)
        }
        if let sheet = template as? CPActionSheetTemplate {

            return .init(id: id, kind: .actionSheet, title: sheet.title)
        }
        return nil
    }
}
