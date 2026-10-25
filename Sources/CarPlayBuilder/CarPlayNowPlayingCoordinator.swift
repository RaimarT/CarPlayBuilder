// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import Observation

/// Owns scene-specific Now Playing controls and navigation.
@MainActor
public final class CarPlayNowPlayingCoordinator: NSObject {

    private static weak var owner: CarPlayNowPlayingCoordinator?
    private static var ownershipID = UUID()
    private let playback: any CarPlayNowPlayingPlayback
    private let upNext: @MainActor () -> AnyCarPlayTemplate
    private let onError: CarPlayContextualErrorHandler
    private let configuration: CarPlayNowPlayingConfiguration
    private var context: CarPlayContext?
    private var destinationTask: Task<Void, Never>?
    private let albumArtist: (@MainActor () -> any CarPlayTemplate)?
    private var buttonContent: (@MainActor () -> [CarPlayNowPlayingButton])?
    private var buttons: [ButtonIdentity: CarPlayMountedNowPlayingButton] = [:]
    private let libraryImage = UIImage(systemName: "bookmark") ?? UIImage()
    private static let defaultUpNextTitle = CPNowPlayingTemplate.shared.upNextTitle
    private var revision = 0
    private let addToLibrary: CarPlayAction?
    private let more: CarPlayAction?
    private let isAddedToLibrary: (@MainActor () -> Bool)?
    private let actionScope: CarPlayTaskScope

    /// Creates scene-owned controls for the shared Now Playing template.
    ///
    /// Retain this coordinator alongside the host. The application remains
    /// responsible for its player, queue, system media commands, and metadata.
    ///
    /// - Parameters:
    ///   - playback: App-owned operations and observable Up Next availability.
    ///   - configuration: Which buttons to show; only playback rate is on by
    /// default.
    ///   - onError: Receives navigation and asynchronous control-action errors.
    ///   - onErrorWithContext: Optional origin-aware callback replacing
    ///     `onError` when supplied. Receives the original error. If neither error
    ///     callback is supplied, unhandled errors are ignored.
    ///   - addToLibrary: Optional save action; its visibility flag must also be set.
    ///   - more: Optional action for More; its visibility flag must also be set.
    ///   - isAddedToLibrary: Optional observed saved state. Supplying it replaces
    ///     the standard Add to Library control with a selectable bookmark image.
    ///   - albumArtist: An optional lazy album, playlist, or show destination.
    ///     Supplying it enables the native album/artist button.
    ///   - upNext: A lazy destination shown when the native Up Next button is
    /// tapped.
    public init(
        playback: any CarPlayNowPlayingPlayback,
        configuration: CarPlayNowPlayingConfiguration = .init(),
        onError: @escaping CarPlayErrorHandler = { _ in },
        onErrorWithContext: CarPlayContextualErrorHandler? = nil,
        addToLibrary: CarPlayAction? = nil,
        more: CarPlayAction? = nil,
        isAddedToLibrary: (@MainActor () -> Bool)? = nil,
        albumArtist: (@MainActor () -> any CarPlayTemplate)? = nil,
        @CarPlayTemplateBuilder upNext: @escaping @MainActor ()
            -> some CarPlayTemplate
    ) {

        self.albumArtist = albumArtist
        self.isAddedToLibrary = isAddedToLibrary
        self.addToLibrary = addToLibrary
        self.more = more
        self.actionScope = CarPlayTaskScope(
            onError: onError,
            onErrorWithContext: onErrorWithContext
        )
        self.playback = playback
        self.upNext = {

            AnyCarPlayTemplate(upNext())
        }
        self.onError = onErrorWithContext ?? { error, _ in onError(error) }
        self.configuration = configuration
        super.init()
    }

    /// Creates controls from an observed builder in leading-to-trailing order.
    ///
    /// The builder replaces configuration visibility flags and legacy callbacks.
    /// The configuration's `upNextTitle` still applies. Supply at most five
    /// buttons with unique explicit IDs. Invalid updates reach `onError` and keep
    /// the last valid buttons. Standard controls use the app's playback adapter.
    ///
    /// - Parameters:
    ///   - playback: App-owned playback operations and Up Next availability.
    ///   - configuration: Label configuration; visibility flags are ignored.
    ///   - onError: Receives validation, navigation, and control-action errors.
    ///   - onErrorWithContext: Optional origin-aware callback replacing
    ///     `onError` when supplied. Receives the original error. If neither error
    ///     callback is supplied, unhandled errors are ignored.
    ///   - albumArtist: Optional lazy album, playlist, or show destination.
    ///   - buttons: Observed controls, evaluated while connected.
    ///   - upNext: Lazy destination for the native Up Next button.
    public convenience init(
        playback: any CarPlayNowPlayingPlayback,
        configuration: CarPlayNowPlayingConfiguration = .init(),
        onError: @escaping CarPlayErrorHandler = { _ in },
        onErrorWithContext: CarPlayContextualErrorHandler? = nil,
        albumArtist: (@MainActor () -> any CarPlayTemplate)? = nil,
        @CarPlayNowPlayingButtonBuilder buttons: @escaping @MainActor ()
            -> [CarPlayNowPlayingButton],
        @CarPlayTemplateBuilder upNext: @escaping @MainActor ()
            -> some CarPlayTemplate
    ) {

        self.init(
            playback: playback,
            configuration: configuration,
            onError: onError,
            onErrorWithContext: onErrorWithContext,
            albumArtist: albumArtist,
            upNext: upNext
        )
        self.buttonContent = buttons
    }

    isolated deinit {

        self.destinationTask?.cancel()
        self.actionScope.cancel()
        CPNowPlayingTemplate.shared.remove(self)
    }

    /// Installs controls and begins observing playback availability.
    ///
    /// Reconnecting cancels previous control actions and pending Up Next work.
    /// Connect this after the scene host successfully connects. Acquiring the
    /// shared template supersedes the previous coordinator and cancels its work.
    ///
    /// - Parameter context: The connected host’s scene navigation context.
    public func connect(context: CarPlayContext) {

        let previous = Self.owner
        let ownershipID = UUID()
        Self.ownershipID = ownershipID
        Self.owner = self
        previous?.stop()

        guard Self.owner === self, Self.ownershipID == ownershipID else {

            return
        }

        self.context = context

        let template = CPNowPlayingTemplate.shared
        template.remove(self)
        template.add(self)

        self.installControls()
    }

    /// Removes controls and observation and cancels pending control actions.
    ///
    /// Call this when the scene disconnects. Audio playback is owned by the app
    /// and continues according to its own policy.
    public func disconnect() {

        let ownershipID = Self.ownershipID
        self.stop()

        guard Self.owner === self, Self.ownershipID == ownershipID else {

            return
        }

        Self.owner = nil
        self.resetSharedControls(ownershipID: ownershipID)
    }

    func perform(_ action: CarPlayNowPlayingAction) {

        self.buttons.values.first { $0.content.kind == action }?.activate()
    }
}

extension CarPlayNowPlayingCoordinator: @MainActor CPNowPlayingTemplateObserver {

    /// Handles the native Up Next button by pushing the app-provided destination.
    ///
    /// This observer callback is invoked by CarPlay, not application code.
    public func nowPlayingTemplateUpNextButtonTapped(
        _ nowPlayingTemplate: CPNowPlayingTemplate
    ) {

        self.showDestination(self.upNext)
    }

    /// Pushes the lazily supplied album, playlist, or show destination.
    public func nowPlayingTemplateAlbumArtistButtonTapped(
        _ nowPlayingTemplate: CPNowPlayingTemplate
    ) {

        guard let albumArtist else {

            return
        }

        self.showDestination { AnyCarPlayTemplate(albumArtist()) }
    }
}

private extension CarPlayNowPlayingCoordinator {

    /// Native setters can synchronously hand ownership to another connection.
    func resetSharedControls(ownershipID: UUID) {

        let template = CPNowPlayingTemplate.shared
        template.remove(self)
        template.isUpNextButtonEnabled = false

        guard Self.owner == nil, Self.ownershipID == ownershipID else {

            return
        }

        template.isAlbumArtistButtonEnabled = false

        guard Self.owner == nil, Self.ownershipID == ownershipID else {

            return
        }

        template.upNextTitle = Self.defaultUpNextTitle

        guard Self.owner == nil, Self.ownershipID == ownershipID else {

            return
        }

        template.updateNowPlayingButtons([])
    }

    func installControls() {

        guard Self.owner === self else {

            return
        }

        let template = CPNowPlayingTemplate.shared
        template.updateNowPlayingButtons([])

        guard Self.owner === self else {

            return
        }

        let defaultTitle = Self.defaultUpNextTitle
        template.upNextTitle = self.configuration.upNextTitle ?? defaultTitle

        guard Self.owner === self else {

            return
        }

        template.isAlbumArtistButtonEnabled = self.albumArtist != nil
        self.updateControls()
    }

    /// Ends this connection without changing another owner's shared controls.
    func stop() {

        self.revision += 1
        self.actionScope.cancel()
        self.destinationTask?.cancel()
        self.destinationTask = nil
        self.context = nil
        CPNowPlayingTemplate.shared.remove(self)
        self.cancelButtons()
    }

    func updateControls() {

        guard Self.owner === self, self.context != nil else {

            return
        }

        self.revision += 1
        let revision = self.revision
        let (hasUpNext, buttons) = withObservationTracking {

            (self.playback.hasUpNext, self.buttonContent?() ?? self.legacyButtons())
        } onChange: { [weak self] in

            Task { @MainActor [weak self] in

                guard let self, self.revision == revision else {

                    return
                }

                self.updateControls()
            }
        }

        do {

            try self.updateButtons(buttons)
        } catch {

            self.onError(error, .init(source: .rendering))
            return
        }

        self.updateUpNext(hasUpNext)
    }

    func updateUpNext(_ hasUpNext: Bool) {

        guard Self.owner === self else {

            return
        }

        let template = CPNowPlayingTemplate.shared
        if template.isUpNextButtonEnabled != hasUpNext {

            template.isUpNextButtonEnabled = hasUpNext
        }
    }

    func legacyButtons() -> [CarPlayNowPlayingButton] {

        var buttons: [CarPlayNowPlayingButton] = []

        if self.configuration.showsPlaybackRateButton {

            buttons.append(.playbackRate)
        }

        if self.configuration.showsShuffleButton {

            buttons.append(.shuffle)
        }

        if self.configuration.showsRepeatButton {

            buttons.append(.repeatMode)
        }

        if self.configuration.showsAddToLibraryButton, let addToLibrary {

            buttons.append(CarPlayNowPlayingButton(
                kind: .addToLibrary,
                image: self.isAddedToLibrary == nil ? nil : self.libraryImage,
                action: addToLibrary
            ).selected(self.isAddedToLibrary?() ?? false))
        }

        if self.configuration.showsMoreButton, let more {

            buttons.append(.more(action: more))
        }

        return buttons
    }

    func updateButtons(_ content: [CarPlayNowPlayingButton]) throws {

        let ids = content.compactMap(\.identity)

        guard content.count <= 5, Set(ids).count == ids.count else {

            throw CarPlayError.invalidContent(
                "Now Playing allows up to five buttons with unique IDs."
            )
        }

        guard Self.owner === self, let context else {

            return
        }

        var updated: [ButtonIdentity: CarPlayMountedNowPlayingButton] = [:]
        let native = content.enumerated().map { index, button in

            let id = button.identity
                .map(ButtonIdentity.explicit) ?? .position(index)
            let mounted = self.mountButton(button, id: id, context: context)
            updated[id] = mounted

            return mounted.item
        }
        for (id, button) in self.buttons where updated[id] == nil {

            button.cancel()
        }
        self.buttons = updated

        let template = CPNowPlayingTemplate.shared
        if template.nowPlayingButtons != native {

            template.updateNowPlayingButtons(native)
        }
    }

    func mountButton(
        _ content: CarPlayNowPlayingButton,
        id: ButtonIdentity,
        context: CarPlayContext
    ) -> CarPlayMountedNowPlayingButton {

        let mounted: CarPlayMountedNowPlayingButton
        if let existing = self.buttons[id], existing.matches(content) {

            mounted = existing
        } else {

            self.buttons[id]?.retire()
            mounted = CarPlayMountedNowPlayingButton(
                content: content,
                playback: self.playback,
                context: context,
                scope: self.actionScope,
                actionState: self.buttons[id]?.actionState
            )
        }
        mounted.update(content)

        return mounted
    }

    func cancelButtons() {

        // Detach old controls before native availability callbacks can reconnect.
        let previous = self.buttons
        self.buttons = [:]
        for button in previous.values {

            button.cancel()
        }
    }

    func showDestination(
        _ destination: @escaping @MainActor () -> AnyCarPlayTemplate
    ) {

        guard Self.owner === self, let context else {

            return
        }

        self.destinationTask?.cancel()
        self.destinationTask = Task { [weak self] in

            do {

                try await context.push(content: destination)
            } catch {

                if !Task.isCancelled, !(error is CancellationError) {

                    self?.onError(error, .init(
                        source: .navigation,
                        control: .nowPlayingDestination
                    ))
                }
            }
        }
    }
}

private extension CarPlayNowPlayingCoordinator {

    enum ButtonIdentity: Hashable {

        case explicit(AnyHashable)
        case position(Int)
    }
}
