// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay
@testable import CarPlayBuilder

/// A controllable native navigation transport for deterministic host tests.
@MainActor
final class CarPlayTestInterface: CarPlayInterface {

    weak var delegate: (any CPInterfaceControllerDelegate)?
    var templates: [CPTemplate] = []
    var presentedTemplate: CPTemplate?
    var beforePopRoot: (@MainActor () async -> Void)?
    var selected: CPTemplate?
    var notifiesTabSelection = false
    var reject: String?
    var failure: (any Error)?
    var duringOperation: (@MainActor (String) -> Void)?
    var operations: [String] = []
    var completed: (@MainActor (String) -> Void)?

    func setRootTemplate(
        _ template: CPTemplate,
        animated: Bool
    ) async throws -> Bool {

        guard try self.accept("root") else {

            return false
        }

        if let old = self.templates.last {

            self.delegate?.templateWillDisappear?(old, animated: animated)
        }
        self.templates = [template]
        self.delegate?.templateWillAppear?(template, animated: animated)
        self.delegate?.templateDidAppear?(template, animated: animated)

        return true
    }

    func pushTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool {

        guard try self.accept("push") else {

            return false
        }

        self.templates.append(template)
        self.completed?("push")
        self.delegate?.templateWillAppear?(template, animated: animated)
        self.delegate?.templateDidAppear?(template, animated: animated)

        return true
    }

    func popTemplate(animated: Bool) async throws -> Bool {

        guard try self.accept("pop"), self.templates.count > 1 else {

            return false
        }

        let removed = self.templates.removeLast()
        self.delegate?.templateWillDisappear?(removed, animated: animated)
        self.delegate?.templateDidDisappear?(removed, animated: animated)

        return true
    }

    func popToRootTemplate(animated: Bool) async throws -> Bool {

        await self.beforePopRoot?()

        guard try self.accept("popRoot"), !self.templates.isEmpty else {

            return false
        }

        self.removeTemplates(after: 0, animated: animated)
        return true
    }

    func popToTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool {

        guard !(template is CPTabBarTemplate) else {

            throw CarPlayError.invalidContent("Tab bars cannot be pop targets.")
        }

        guard try self.accept("popTo"),
              let index = self.templates.firstIndex(where: { $0 === template })
        else {

            return false
        }

        self.removeTemplates(after: index, animated: animated)
        return true
    }

    func presentTemplate(
        _ template: CPTemplate,
        animated: Bool
    ) async throws -> Bool {

        guard try self.accept("present") else {

            return false
        }

        self.presentedTemplate = template
        self.completed?("present")

        return true
    }

    func dismissTemplate(animated: Bool) async throws -> Bool {

        guard try self.accept("dismiss") else {

            return false
        }

        self.presentedTemplate = nil
        self.completed?("dismiss")

        return true
    }

    func selectTemplate(_ template: CPTemplate, in tabs: CPTabBarTemplate) {

        self.operations.append("select")
        self.selected = template
        if self.notifiesTabSelection {

            tabs.delegate?.tabBarTemplate(tabs, didSelect: template)
        }
    }
}

private extension CarPlayTestInterface {

    func removeTemplates(after index: Int, animated: Bool) {

        let removed = self.templates.suffix(from: index + 1)
        self.templates = Array(self.templates.prefix(through: index))
        for item in removed {

            self.delegate?.templateWillDisappear?(item, animated: animated)
            self.delegate?.templateDidDisappear?(item, animated: animated)
        }
    }

    func accept(_ operation: String) throws -> Bool {

        self.operations.append(operation)
        self.duringOperation?(operation)
        if let failure {

            throw failure
        }
        if self.reject == operation {

            self.reject = nil
            return false
        }

        return true
    }
}
