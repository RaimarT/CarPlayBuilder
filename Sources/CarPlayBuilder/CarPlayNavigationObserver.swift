// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Deduplicates delegate notifications against accepted navigation snapshots.
@MainActor
final class CarPlayNavigationObserver {

    private var state = CarPlayNavigationState(stack: [], modal: nil)
    private let handler: CarPlayNavigationHandler

    init(handler: @escaping CarPlayNavigationHandler) {

        self.handler = handler
    }

    func update(
        _ next: CarPlayNavigationState,
        kind: CarPlayNavigationKind? = nil,
        origin: CarPlayNavigationOrigin,
        animated: Bool
    ) {

        let previous = self.state
        self.state = next

        guard previous.stack.map(\.id) != next.stack.map(\.id)
            || previous.modal?.id != next.modal?.id
        else {

            return
        }

        self.handler(.init(
            kind: kind ?? self.nativeKind(previous: previous, next: next),
            origin: origin,
            animated: animated,
            previous: previous,
            current: next
        ))
    }

    private func nativeKind(
        previous: CarPlayNavigationState,
        next: CarPlayNavigationState
    ) -> CarPlayNavigationKind {

        if previous.modal?.id != next.modal?.id {

            return next.modal == nil ? .modalDismissed : .modalPresented
        }

        if next.stack.count < previous.stack.count {

            return .popped
        }

        return next.stack.count > previous.stack.count ? .pushed : .rootReplaced
    }
}
