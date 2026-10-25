// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// An immutable snapshot of the host-owned navigation stack and modal.
///
/// Titles are captured when navigation settles, not continuously observed.
/// Tab children are represented by their container; use tab selection callbacks
/// to observe the selected tab. Snapshots retain no native templates or actions.
public struct CarPlayNavigationState: Sendable, Equatable {

    /// Root-to-top ordering of mounted screens; empty after disconnection.
    public let stack: [CarPlayNavigationScreen]

    /// The host-owned alert or action sheet, if currently presented.
    public let modal: CarPlayNavigationScreen?
}
