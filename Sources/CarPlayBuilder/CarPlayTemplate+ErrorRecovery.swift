// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

public extension CarPlayTemplate {

    /// Handles unhandled screen selection, lifecycle, and rendering errors.
    ///
    /// Handlers run from inner to outer modifier order. Returning `.handled`
    /// stops propagation; `.unhandled` continues to enclosing tab-container
    /// handlers and then the host. Tasks use the latest accepted handlers when
    /// they fail. Removing this modifier restores normal propagation.
    ///
    /// Observed rendering failures use the mounted screen root's last accepted
    /// handlers. Explicit navigation and initial mounting errors still throw to
    /// their caller. Normal cancellation, scene-owned modal actions, and the
    /// separate Now Playing coordinator are outside this modifier's scope.
    ///
    /// - Parameter action: Synchronous recovery work and a propagation decision.
    /// - Returns: A template with the additional recovery handler.
    func onError(
        _ action: @escaping CarPlayErrorRecovery
    ) -> CarPlayModifiedTemplate<Self> {

        CarPlayModifiedTemplate(content: self) {

            $0.errorHandlers.append { error, _, context in

                action(error, context)
            }
        }
    }

    /// Recovers from a screen error using its original control or task metadata.
    ///
    /// Shares ordering and propagation with `onError`. Running work uses the
    /// latest accepted handlers but retains its originating operation metadata.
    /// Explicit navigation and initial mounting errors still throw to callers.
    /// - Parameter action: Recovery with the error, origin, and scene context.
    /// - Returns: A template with an additional contextual recovery handler.
    func onErrorWithContext(
        _ action: @escaping CarPlayContextualErrorRecovery
    ) -> CarPlayModifiedTemplate<Self> {

        CarPlayModifiedTemplate(content: self) {

            $0.errorHandlers.append(action)
        }
    }
}
