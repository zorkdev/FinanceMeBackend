// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "zorkdev",
    products: [
        .library(name: "App", targets: ["App"]),
        .executable(name: "Run", targets: ["Run"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .exact("2.4.5")),
        .package(url: "https://github.com/vapor/fluent-provider.git", .exact("1.3.0")),
        .package(url: "https://github.com/vapor/auth-provider.git", .exact("1.2.0")),
        .package(url: "https://github.com/vapor-community/postgresql-provider.git", .exact("2.1.0")),
        .package(url: "https://github.com/matthijs2704/vapor-apns.git", .exact("2.1.0")),
        .package(url: "https://github.com/Zewo/zlib.git", .exact("0.4.0"))
    ],
    targets: [
        .target(name: "App",
                dependencies: ["Vapor",
                               "FluentProvider",
                               "PostgreSQLProvider",
                               "AuthProvider" ,
                               "zlib",
                               "VaporAPNS"],
                exclude: [
                    "Config",
                    "Database",
                    "Localization",
                    "Public",
                    "Resources"
            ]),
        .target(name: "Run",
                dependencies: ["App"])
    ]
)
