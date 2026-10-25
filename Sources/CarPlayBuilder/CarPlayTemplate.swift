// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT

import CarPlay

/// A value describing a CarPlay screen. Compose reusable screens by implementing
/// `body`.
@MainActor
public protocol CarPlayTemplate {

    /// The concrete template returned by the component’s `body`.
    ///
    /// Primitive templates use `Never` and implement the rendering entry point.
    associatedtype Body: CarPlayTemplate

    /// The single root template describing this reusable component.
    ///
    /// Read observable state here to participate in updates. Keep evaluation
    /// free of side effects; perform work in actions or lifecycle tasks.
    @CarPlayTemplateBuilder
    var body: Body { get }

    /// Resolves this component’s body for the package renderer.
    ///
    /// Applications implement `body` instead of calling this entry point.
    /// - Returns: Opaque content consumed by the native renderer.
    func _resolve() -> CarPlayTemplateContent
}

public extension CarPlayTemplate {

    func _resolve() -> CarPlayTemplateContent {

        body._resolve()
    }

    /// Runs asynchronous work while this template is visible.
    ///
    /// Work starts on appearance, restarts when its ID changes, and is cancelled
    /// on disappearance. Re-evaluation with the same ID does not repeat completed
    /// work. Multiple task modifiers have independent lifetimes.
    ///
    /// - Parameters:
    ///   - id: A stable value identifying the work, such as an account or query ID.
    ///   - priority: The priority of the retained task.
    ///   - action: Main-actor work that cooperates with cancellation. Unhandled
    ///     errors, excluding cancellation, try screen recovery before the host.
    /// - Returns: A template retaining this lifecycle task definition.
    func task(
        id: some Hashable = 0,
        priority: TaskPriority = .userInitiated,
        _ action: @escaping CarPlayTaskAction
    ) -> CarPlayModifiedTemplate<Self> {

        CarPlayModifiedTemplate(content: self) {

            $0.tasks.append(
                .init(
                    id: AnyHashable(id),
                    priority: priority,
                    action: action
                )
            )
        }
    }

    /// Registers a synchronous callback when the native template becomes visible.
    ///
    /// - Parameter action: Main-actor work performed on each visibility transition.
    /// - Returns: A template with the additional appearance callback.
    func onAppear(
        _ action: @escaping CarPlayCallback
    ) -> CarPlayModifiedTemplate<Self> {

        CarPlayModifiedTemplate(content: self) {

            $0.appear.append(action)
        }
    }

    /// Registers a callback when the template hides or is removed while visible.
    ///
    /// - Parameter action: Main-actor cleanup performed when visibility ends.
    /// - Returns: A template with the additional disappearance callback.
    func onDisappear(
        _ action: @escaping CarPlayCallback
    ) -> CarPlayModifiedTemplate<Self> {

        CarPlayModifiedTemplate(content: self) {

            $0.disappear.append(action)
        }
    }
}

extension Never: CarPlayTemplate {

    /// An uninhabited body required by primitive template conformance.
    ///
    /// Accessing this property traps; primitive templates render through `_resolve`.
    public var body: Never {

        return fatalError("Primitive CarPlay templates do not have a body.")
    }

    /// An unreachable rendering witness for `Never`.
    ///
    /// Calling this method traps because `Never` has no value.
    public func _resolve() -> CarPlayTemplateContent {

        fatalError("Never cannot be rendered.")
    }
}

public extension CarPlayTemplate where Body == Never {

    /// An uninhabited body for primitive templates. Accessing it traps.
    var body: Never {

        return fatalError("Primitive CarPlay templates do not have a body.")
    }
}
