// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAutomation",
    platforms: [.macOS(.v10_12)],
    products: [
        .library(name: "SwiftAutomation", targets: ["SwiftAutomation"]),
        .library(name: "MacOSGlues", targets: ["MacOSGlues"]),
        .executable(name: "aeglue", targets: ["aeglue"]),
        .executable(name: "test", targets: ["test"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/emorydunn/AppleEvents.git", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftAutomation",
            dependencies: ["AppleEvents"]
        ),
        .target(
            name: "MacOSGlues",
            dependencies: ["SwiftAutomation"]),
        .target(
            name: "aeglue",
            dependencies: [
                "SwiftAutomation"
            ]),
        .target(
            name: "test",
            dependencies: [
                "SwiftAutomation",
                "MacOSGlues"
            ]),
//        .testTarget(
//            name: "music-apiTests",
//            dependencies: ["music-api"]),
    ]
)
