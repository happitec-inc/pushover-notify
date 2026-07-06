// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pushover-notify",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Library product so other packages (e.g. Linux AWS Lambdas) can depend on
        // the core notification logic instead of re-implementing a Pushover client.
        .library(name: "notifyCore", targets: ["notifyCore"]),
        // The CLI, exposed as a product for completeness / `swift run`.
        .executable(name: "notify", targets: ["notify"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
    ],
    targets: [
        // Library target containing the core logic; testable without a subprocess
        .target(
            name: "notifyCore",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            path: "Sources/notifyCore",
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        // CLI executable; thin wrapper around notifyCore
        .executableTarget(
            name: "notify",
            dependencies: [
                "notifyCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/notify",
            exclude: [
                "openapi.yaml",
                "openapi-generator-config.yaml",
            ]
        ),
        // Test target
        .testTarget(
            name: "notifyTests",
            dependencies: [
                "notifyCore",
            ],
            path: "Tests/notifyTests"
        ),
    ]
)
