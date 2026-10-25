// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// Combines app availability with identity-owned running work.
@MainActor
final class CarPlayActionState {

    private var active = true
    private var appEnabled = true
    private var running = 0
    private var policy: CarPlayRepeatedActionPolicy = .allowConcurrent
    private var availability: (@MainActor (Bool) -> Void)?

    var isEnabled: Bool {

        self.active && self.appEnabled
            && (self.policy == .allowConcurrent || self.running == 0)
    }

    func update(
        enabled: Bool,
        policy: CarPlayRepeatedActionPolicy,
        availability: @escaping @MainActor (Bool) -> Void
    ) {

        self.appEnabled = enabled
        self.policy = policy
        self.availability = availability
        self.publish()
    }

    func perform(
        in scope: CarPlayTaskScope,
        control: CarPlayErrorControl? = nil,
        controlID: AnyHashable? = nil,
        action: @escaping CarPlayTaskAction,
        completion: @escaping CarPlayCallback = {}
    ) {

        guard self.isEnabled else {

            completion()
            return
        }

        self.running += 1
        self.publish()
        scope.perform(action, control: control, controlID: controlID) { [self] in

            self.running -= 1
            self.publish()
            completion()
        }
    }

    func cancel() {

        self.active = false
        self.publish()
        self.availability = nil
    }

    private func publish() {

        self.availability?(self.isEnabled)
    }
}
