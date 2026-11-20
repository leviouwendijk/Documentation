import Documentation
import Executable
import Foundation
import TestFlows

extension DocumentationFlowSuite {
    static var documentationWorkspaceSnapshotFlow: TestFlow {
        TestFlow(
            "documentation-workspace-snapshot",
            tags: [
                "documentation",
                "workspace",
                "symbol-graph",
                "semantics",
            ]
        ) {
            Step("live workspace captures internal and dirty-tree symbols") {
                let root = FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "documentation-workspace-\(UUID().uuidString)",
                        isDirectory: true
                    )
                defer {
                    try? FileManager.default.removeItem(
                        at: root
                    )
                }

                let sources = root.appendingPathComponent(
                    "Sources/Core",
                    isDirectory: true
                )
                try FileManager.default.createDirectory(
                    at: sources,
                    withIntermediateDirectories: true
                )
                try """
                // swift-tools-version: 6.2
                import PackageDescription

                let package = Package(
                    name: "WorkspaceFixture",
                    products: [
                        .library(
                            name: "Core",
                            targets: ["Core"]
                        ),
                    ],
                    targets: [
                        .target(
                            name: "Core"
                        ),
                    ]
                )
                """.write(
                    to: root.appendingPathComponent("Package.swift"),
                    atomically: true,
                    encoding: .utf8
                )

                let source = sources.appendingPathComponent(
                    "Core.swift"
                )
                try """
                public struct PublicValue {
                    public init() {}
                }

                struct InternalValue {}
                """.write(
                    to: source,
                    atomically: true,
                    encoding: .utf8
                )

                let initial = try await DocumentationWorkspace.snapshot(
                    at: root,
                    minimumAccessLevel: .internal
                )
                try Expect.true(
                    initial.collection.symbols.contains {
                        $0.name == "InternalValue"
                            && $0.module?.rawValue == "Core"
                    },
                    "internal symbol and compiler module membership are retained"
                )

                try """
                public struct PublicValue {
                    public init() {}
                }

                struct InternalValue {}
                struct DirtyWorkingTreeValue {}
                """.write(
                    to: source,
                    atomically: true,
                    encoding: .utf8
                )

                let dirty = try await DocumentationWorkspace.snapshot(
                    at: root,
                    minimumAccessLevel: .internal
                )
                try Expect.true(
                    dirty.collection.symbols.contains {
                        $0.name == "DirtyWorkingTreeValue"
                    },
                    "workspace semantic derivation reads current uncommitted source"
                )
            }
        }
    }
}
