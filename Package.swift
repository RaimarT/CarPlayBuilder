// swift-tools-version: 6.2
// SPDX-FileCopyrightText: 2026 Raimar Tasche
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "CarPlayBuilder",
    platforms: [.iOS(.v17)],
    products: [.library(name: "CarPlayBuilder", targets: ["CarPlayBuilder"])],
    targets: [
        .target(name: "CarPlayBuilder"),
        .testTarget(name: "CarPlayBuilderTests", dependencies: ["CarPlayBuilder"])
    ]
)
