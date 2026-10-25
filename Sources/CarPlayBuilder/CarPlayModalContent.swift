// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// The opaque resolved representation of an alert or action sheet.
///
/// This type is an implementation boundary for modal resolution. Applications
/// construct modal values instead of building resolved content directly.
@MainActor
public struct CarPlayModalContent {

    let kind: CarPlayModalKind
    let actions: [CarPlayAlertAction]

    func makeTemplate(
        selection: @escaping @MainActor (Int) -> Void
    ) throws -> CPTemplate {

        try self.validate()
        let actions = self.actions.enumerated().map { index, action in

            CPAlertAction(title: action.title, style: action.style) { _ in

                Task { @MainActor in

                    selection(index)
                }
            }
        }

        switch self.kind {

        case let .alert(titles):
            return CPAlertTemplate(titleVariants: titles, actions: actions)

        case let .actionSheet(title, message):
            return CPActionSheetTemplate(
                title: title,
                message: message,
                actions: actions
            )
        }
    }
}

private extension CarPlayModalContent {

    func validate() throws {

        guard !self.actions.isEmpty,
              self.actions.allSatisfy({ !$0.title.isEmpty }),
              self.actions.filter({ $0.style == .cancel }).count <= 1
        else {

            throw CarPlayError
                .invalidContent("Actions need titles and at most one cancel action.")
        }

        if case let .alert(titles) = self.kind {

            guard !titles.isEmpty, titles.allSatisfy({ !$0.isEmpty }),
                  self.actions.count <= CPAlertTemplate.maximumActionCount
            else {

                throw CarPlayError.invalidContent("Invalid alert title or count.")
            }
        }
    }
}
