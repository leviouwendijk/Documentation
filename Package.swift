// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Documentation",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Documentation",
            targets: [
                "Documentation",
            ]
        ),
        .executable(
            name: "doctest",
            targets: [
                "DocumentationTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Interfaces.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Executable.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/DSL.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Parsers.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-docc-symbolkit.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "Documentation",
            dependencies: [
                .product(
                    name: "Interfaces",
                    package: "Interfaces"
                ),
                .product(
                    name: "Executable",
                    package: "Executable"
                ),
                .product(
                    name: "DSL",
                    package: "DSL"
                ),
                .product(
                    name: "ParsersStructuredContent",
                    package: "Parsers"
                ),
                .product(
                    name: "SymbolKit",
                    package: "swift-docc-symbolkit"
                ),
            ]
        ),
        .executableTarget(
            name: "DocumentationTestFlows",
            dependencies: [
                "Documentation",
                .product(
                    name: "Interfaces",
                    package: "Interfaces"
                ),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
