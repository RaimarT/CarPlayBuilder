// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

/// User-facing error text and artwork, independent of recovery behavior.
///
/// Reuse this value for loading failures and app-owned error UI. It does not
/// retain the underlying error, present an alert, or initiate recovery.
public struct CarPlayErrorPresentation: Sendable, Equatable {

    /// The error title and SF Symbol; default lists display only the title.
    public var label: CarPlayStatusLabel

    /// Optional explanatory text, displayed as detail in default list failures.
    ///
    /// Default grid buttons display only the label. Use a custom failure builder
    /// when a grid needs additional content or recovery actions.
    public var message: String?

    /// Creates an error presentation using app-localized text when supplied.
    ///
    /// - Parameters:
    ///   - label: Error title and symbol, defaulting to the standard failure label.
    ///   - message: Optional explanation or recovery guidance.
    public init(label: CarPlayStatusLabel = .failure, message: String? = nil) {

        self.label = label
        self.message = message
    }
}
