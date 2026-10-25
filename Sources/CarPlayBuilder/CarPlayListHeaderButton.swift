// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A titled or image action displayed in a rich list header.
@MainActor
public struct CarPlayListHeaderButton {

    var identity: AnyHashable?
    let title: String?
    let image: UIImage?
    let action: CarPlayAction
    var repeatPolicy: CarPlayRepeatedActionPolicy = .allowConcurrent
    var isEnabled = true

    /// Creates a titled action with optional artwork.
    ///
    /// - Parameters:
    ///   - title: A nonempty label when no image is supplied.
    ///   - image: Optional ready-to-display artwork. CarPlay controls its layout.
    ///   - action: Screen-owned work using the scene navigation context.
    ///     Unhandled errors reach the host's error handler.
    public init(
        _ title: String,
        image: UIImage? = nil,
        action: @escaping CarPlayAction
    ) {

        self.title = title
        self.image = image
        self.action = action
    }

    /// Creates an image-only action. Size artwork for the native header's
    /// `maximumActionButtonSize` on iOS 26.4 or later.
    public init(image: UIImage, action: @escaping CarPlayAction) {

        self.title = nil
        self.image = image
        self.action = action
    }

    /// Assigns an identity unique among this header's buttons.
    public func id(_ id: some Hashable) -> Self {

        var copy = self
        copy.identity = AnyHashable(id)

        return copy
    }

    /// Chooses how repeated selections behave while this control's work runs.
    ///
    /// `.ignoreWhileRunning` temporarily disables the native control, preserving
    /// app-owned disabled state. Use stable IDs to retain busy state on updates.
    public func repeatedActionPolicy(_ policy: CarPlayRepeatedActionPolicy) -> Self {

        var copy = self
        copy.repeatPolicy = policy

        return copy
    }

    /// Controls whether this action can be selected.
    public func disabled(_ disabled: Bool = true) -> Self {

        var copy = self
        copy.isEnabled = !disabled

        return copy
    }
}
