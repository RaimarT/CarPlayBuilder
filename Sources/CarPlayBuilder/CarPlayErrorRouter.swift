// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Routes errors through the latest accepted screen handlers and their parent.
@MainActor
final class CarPlayErrorRouter {

    private var handlers: [CarPlayContextualErrorRecovery] = []
    private let context: CarPlayContext
    private let fallback: CarPlayContextualErrorHandler
    private var active = true

    init(
        context: CarPlayContext,
        onError: @escaping CarPlayContextualErrorHandler
    ) {

        self.context = context
        self.fallback = onError
    }

    func update(_ handlers: [CarPlayContextualErrorRecovery]) {

        self.handlers = handlers
    }

    func report(_ error: Error, context: CarPlayErrorContext) {

        guard self.active, !(error is CancellationError) else {

            return
        }

        for handler in self.handlers {

            if handler(error, context, self.context) == .handled {

                return
            }

            guard self.active else {

                return
            }
        }

        self.fallback(error, context)
    }

    func cancel() {

        self.active = false
        self.handlers = []
    }
}
