// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A titled action displayed in a list section header.
///
/// Supply it to `CarPlaySection` together with a header title. Selection work
/// belongs to the screen and cancels when it is removed or the scene disconnects.
@MainActor
public struct CarPlaySectionHeaderButton {

    let title: String
    let action: CarPlayAction
    var repeatPolicy: CarPlayRepeatedActionPolicy = .allowConcurrent
    var isEnabled = true

    /// Creates a section header action.
    ///
    /// - Parameters:
    ///   - title: A nonempty button label.
    ///   - action: Main-actor selection work using the scene navigation context.
    ///     Unhandled errors reach the host's error handler.
    public init(_ title: String, action: @escaping CarPlayAction) {

        self.title = title
        self.action = action
    }

    /// Chooses how repeated selections behave while this control's work runs.
    ///
    /// `.ignoreWhileRunning` temporarily disables the native control, preserving
    /// app-owned disabled state. Use stable IDs to retain busy state on updates.
    public func repeatedActionPolicy(_ policy: CarPlayRepeatedActionPolicy) -> Self {

        var copy = self
        copy.repeatPolicy = policy

        return copy
    }

    /// Controls whether the header action can be selected.
    ///
    /// - Parameter disabled: Whether selection is disabled; defaults to `true`.
    /// - Returns: A copy with the requested availability.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }
}
