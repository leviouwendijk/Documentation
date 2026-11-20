// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "DocumentationTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
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
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "DocumentationTestFlows",
            dependencies: [
                .product(name: "Documentation", package: "Documentation"),
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
