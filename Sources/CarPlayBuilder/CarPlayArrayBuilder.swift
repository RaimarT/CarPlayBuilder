// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A collection builder supporting `if`, `if/else`, `switch`, `for`, arrays, and
/// empty content.
@resultBuilder
public enum CarPlayArrayBuilder<Element> {

    /// Lifts one element into the builder’s collection.
    ///
    /// - Parameter expression: The element to include.
    /// - Returns: The combined element collection.
    public static func buildExpression(_ expression: Element) -> [Element] {

        [expression]
    }

    /// Includes an existing array without changing its order.
    ///
    /// - Parameter expression: The elements to include.
    /// - Returns: The combined element collection.
    public static func buildExpression(_ expression: [Element]) -> [Element] {

        expression
    }

    /// Flattens sibling statements into one ordered collection.
    ///
    /// - Parameter components: Collections produced by each statement.
    /// - Returns: The combined element collection.
    public static func buildBlock(_ components: [Element]...) -> [Element] {

        components.flatMap {

            $0
        }
    }

    /// Includes an `if` branch, or an empty collection when absent.
    ///
    /// - Parameter component: The optional branch result.
    /// - Returns: The combined element collection.
    public static func buildOptional(_ component: [Element]?) -> [Element] {

        component ?? []
    }

    /// Includes the selected first branch of conditional content.
    ///
    /// - Parameter component: The selected branch result.
    /// - Returns: The combined element collection.
    public static func buildEither(first component: [Element]) -> [Element] {

        component
    }

    /// Includes the selected alternative branch of conditional content.
    ///
    /// - Parameter component: The selected branch result.
    /// - Returns: The combined element collection.
    public static func buildEither(second component: [Element]) -> [Element] {

        component
    }

    /// Flattens the ordered results of a `for` loop.
    ///
    /// - Parameter components: The collection produced by each iteration.
    /// - Returns: The combined element collection.
    public static func buildArray(_ components: [[Element]]) -> [Element] {

        components.flatMap {

            $0
        }
    }

    /// Preserves content selected by an availability check.
    ///
    /// - Parameter component: Content from the available branch.
    /// - Returns: The combined element collection.
    public static func buildLimitedAvailability(_ component: [Element])
        -> [Element] {

        component
    }
}
