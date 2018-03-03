// swift-tools-version:4.1

import PackageDescription

let package = Package(
    name: "zorkdev",
    products: [
        .library(name: "App", targets: ["App"]),
        .executable(name: "Run", targets: ["Run"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "2.2.0"),
        .package(url: "https://github.com/vapor/fluent-provider.git", from: "1.2.0"),
        .package(url: "https://github.com/vapor-community/postgresql-provider.git", from: "2.1.0"),
        .package(url: "https://github.com/Zewo/zlib.git", from: "0.4.0"),
        .package(url: "https://github.com/vapor/auth-provider.git", from: "1.0.0"),
        .package(url: "https://github.com/matthijs2704/vapor-apns.git", from: "2.0.0")
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
