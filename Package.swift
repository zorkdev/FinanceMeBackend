// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "FinanceMeBackend",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.3.2"),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/auth.git", from: "2.0.4"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.39.1")
    ],
    targets: [
        .target(name: "App", dependencies: ["Authentication", "FluentPostgreSQL", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
