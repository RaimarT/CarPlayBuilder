// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A titled modal action with a native style and asynchronous callback.
///
/// The host dismisses the modal before invoking the callback, allowing the
/// action to navigate or present another modal. Repeated selection is ignored.
@MainActor
public struct CarPlayAlertAction {

    let title: String
    let style: CPAlertAction.Style
    let action: CarPlayAction

    /// Creates a modal action whose callback runs after dismissal.
    ///
    /// - Parameters:
    ///   - title: A nonempty action label.
    ///   - style: The native default, cancel, or destructive appearance.
    ///   - action: Main-actor selection work. The default callback does nothing.
    ///     Errors reach the host; disconnect cancels running callbacks.
    public init(
        _ title: String,
        style: CPAlertAction.Style = .default,
        action: @escaping CarPlayAction = { _ in }
    ) {

        self.title = title
        self.style = style
        self.action = action
    }
}
