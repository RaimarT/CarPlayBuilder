// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
import CarPlayBuilder

@MainActor
final class SampleCarPlaySceneDelegate: NSObject,
    CPTemplateApplicationSceneDelegate {

    private var host: CarPlayHost?
    private var connectionTask: Task<Void, Never>?

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {

        self.disconnect()
        let model = SampleModel.shared
        let host = CarPlayHost(
            interfaceController: interfaceController,
            onError: { model.errorMessage = $0.localizedDescription }
        ) {

            SampleRootScreen(model: model)
        }
        self.host = host
        self.connectionTask = Task { @MainActor in

            do {

                try await host.connect()
            } catch {

                guard !Task.isCancelled else {

                    return
                }

                model.errorMessage = error.localizedDescription
            }
        }
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {

        self.disconnect()
    }

    private func disconnect() {

        self.connectionTask?.cancel()
        self.connectionTask = nil
        self.host?.disconnect()
        self.host = nil
    }
}
