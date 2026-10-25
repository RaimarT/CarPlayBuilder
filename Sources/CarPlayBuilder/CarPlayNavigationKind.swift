// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A completed change to the host's connection, stack, or modal presentation.
public enum CarPlayNavigationKind: Sendable, Equatable {

    /// The initial root was accepted by CarPlay.
    case connected
    /// A destination was added to the stack.
    case pushed
    /// One or more destinations were removed, including native Back navigation.
    case popped
    /// A programmatic root-pop removed destinations, including tab navigation.
    case poppedToRoot
    /// A new root replaced the previous stack.
    case rootReplaced
    /// An alert or action sheet was presented.
    case modalPresented
    /// A modal was dismissed, including before its action callback runs.
    case modalDismissed
    /// The host released its connection and owned screens.
    case disconnected
}
