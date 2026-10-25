// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// The host’s injectable boundary around native navigation operations.
///
/// Production uses `CPInterfaceController`; tests supply a transport that can
/// accept, reject, or suspend operations without a connected CarPlay scene.
@MainActor
protocol CarPlayInterface: AnyObject {

    var delegate: (any CPInterfaceControllerDelegate)? { get set }
    var templates: [CPTemplate] { get }
    var presentedTemplate: CPTemplate? { get }

    func presentTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool
    func dismissTemplate(animated: Bool) async throws -> Bool
    func selectTemplate(_ template: CPTemplate, in tabs: CPTabBarTemplate)
    func setRootTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool
    func pushTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool
    func popTemplate(animated: Bool) async throws -> Bool
    func popToRootTemplate(animated: Bool) async throws -> Bool
    func popToTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool
}

extension CPInterfaceController: CarPlayInterface {

    func selectTemplate(_ template: CPTemplate, in tabs: CPTabBarTemplate) {

        tabs.select(template)
    }

    func popToTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool {

        try await pop(to: template, animated: animated)
    }
}
