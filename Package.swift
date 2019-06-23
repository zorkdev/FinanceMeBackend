// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "Zorkdev",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "3.3.0")),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/vapor/auth.git", .upToNextMajor(from: "2.0.4"))
    ],
    targets: [
        .target(name: "App", dependencies: ["Authentication", "FluentPostgreSQL", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

