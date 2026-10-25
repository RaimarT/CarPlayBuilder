// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import Foundation

/// Describes where an error originated without replacing the original error.
///
/// IDs are app-provided values where available. Context stays on the main actor
/// because arbitrary `Hashable` IDs need not be sendable. Copy the fields needed
/// by background diagnostics into your own sendable representation.
@MainActor
public struct CarPlayErrorContext {

    /// The operation that surfaced the error.
    public let source: CarPlayErrorSource

    /// Stable identity for the originating mounted template, when available.
    public let screenID: UUID?

    /// Title of the originating template when its work started, if available.
    public let screenTitle: String?

    /// The control kind, when a selection or coordinator destination failed.
    public let control: CarPlayErrorControl?

    /// Explicit control ID; modal actions use their zero-based action index.
    public let controlID: AnyHashable?

    /// The ID supplied to the task modifier, for lifecycle failures.
    public let taskID: AnyHashable?

    /// Creates metadata for an operation, independently of any underlying error.
    ///
    /// - Parameters:
    ///   - source: The operation surfacing the failure.
    ///   - screenID: Mounted identity, stable until the template is unmounted.
    ///   - screenTitle: Accepted title when the operation started.
    ///   - control: Kind of selected control or coordinator destination.
    ///   - controlID: Explicit control ID, or the modal action's array index.
    ///   - taskID: ID supplied to a lifecycle task modifier.
    public init(
        source: CarPlayErrorSource,
        screenID: UUID? = nil,
        screenTitle: String? = nil,
        control: CarPlayErrorControl? = nil,
        controlID: AnyHashable? = nil,
        taskID: AnyHashable? = nil
    ) {

        self.source = source
        self.screenID = screenID
        self.screenTitle = screenTitle
        self.control = control
        self.controlID = controlID
        self.taskID = taskID
    }
}
