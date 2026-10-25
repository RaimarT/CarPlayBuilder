// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A completed navigation change, delivered synchronously on the main actor.
///
/// Events describe accepted state changes, not requests or lifecycle visibility.
/// Rejected operations, stale completions, and repeated no-ops produce no event.
/// The host creates events; apps consume these immutable snapshots rather than
/// constructing navigation commands from them.
public struct CarPlayNavigationEvent: Sendable, Equatable {

    /// The completed operation or inferred native change.
    public let kind: CarPlayNavigationKind
    /// Whether the host requested the change or observed native navigation.
    public let origin: CarPlayNavigationOrigin
    /// Requested animation, or the animation reported by the native delegate.
    /// Disconnection always uses `false`.
    public let animated: Bool
    /// The last settled state before this change.
    public let previous: CarPlayNavigationState
    /// The settled state after this change.
    public let current: CarPlayNavigationState
}
