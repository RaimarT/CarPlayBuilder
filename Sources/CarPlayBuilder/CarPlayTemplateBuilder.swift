// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// A screen has exactly one root template. Conditional branches may choose its
/// content.
@MainActor
@resultBuilder
public enum CarPlayTemplateBuilder {

    /// Erases a template’s concrete type for composition.
    ///
    /// - Parameter expression: The single root template.
    /// - Returns: The type-erased root template.
    public static func buildExpression(_ expression: some CarPlayTemplate)
        -> AnyCarPlayTemplate {

        AnyCarPlayTemplate(expression)
    }

    /// Preserves the single root produced by a template body.
    ///
    /// - Parameter component: The body’s resolved root value.
    /// - Returns: The type-erased root template.
    public static func buildBlock(_ component: AnyCarPlayTemplate)
        -> AnyCarPlayTemplate {

        component
    }

    /// Includes the selected first branch of conditional content.
    ///
    /// - Parameter component: The selected branch result.
    /// - Returns: The type-erased root template.
    public static func buildEither(first component: AnyCarPlayTemplate)
        -> AnyCarPlayTemplate {

        component
    }

    /// Includes the selected alternative branch of conditional content.
    ///
    /// - Parameter component: The selected branch result.
    /// - Returns: The type-erased root template.
    public static func buildEither(second component: AnyCarPlayTemplate)
        -> AnyCarPlayTemplate {

        component
    }

    /// Preserves content selected by an availability check.
    ///
    /// - Parameter component: Content from the available branch.
    /// - Returns: The type-erased root template.
    public static func buildLimitedAvailability(_ component: AnyCarPlayTemplate)
        -> AnyCarPlayTemplate {

        component
    }
}
