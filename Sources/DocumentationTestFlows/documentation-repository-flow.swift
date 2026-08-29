import Documentation
import Foundation
import Interfaces
import TestFlows

extension DocumentationFlowSuite {
    static var documentationRepositoryFlow: TestFlow {
        TestFlow(
            "documentation-repository",
            tags: [
                "documentation",
                "repository",
                "integration",
                "network",
            ]
        ) {
            Step("materialize public Primitives revision without retaining checkout") {
                guard let origin = URL(
                    string: "https://github.com/leviouwendijk/Primitives.git"
                ) else {
                    throw DocumentationRepositoryFlowError.invalidOrigin
                }

                let repository = DocumentationRepository(
                    origin: origin,
                    revision: .branch(
                        "master"
                    )
                )

                let storageRoot = try await DocumentationRepositoryMaterializer
                    .withTemporaryMaterialization(
                        repository
                    ) { materialization in
                        let packageManifest = materialization.checkoutRoot
                            .appendingPathComponent(
                                "Package.swift",
                                isDirectory: false
                            )

                        try Expect.true(
                            FileManager.default.fileExists(
                                atPath: packageManifest.path
                            ),
                            "Primitives checkout contains Package.swift"
                        )

                        let head = try await GitRepo.resolveCommit(
                            "HEAD",
                            at: materialization.checkoutRoot
                        )

                        try Expect.equal(
                            head,
                            materialization.revision.commit,
                            "materialized checkout matches recorded immutable revision"
                        )

                        try Expect.equal(
                            materialization.revision.requested,
                            .branch(
                                "master"
                            ),
                            "materialization preserves requested revision"
                        )

                        let inspection = try await DocumentationRepositoryInspector.inspect(
                            materialization
                        )

                        try Expect.equal(
                            inspection.manifest.name,
                            "Primitives",
                            "repository inspection preserves Swift package identity"
                        )

                        try Expect.true(
                            !inspection.manifest.products.isEmpty,
                            "repository inspection preserves package products"
                        )

                        try Expect.true(
                            !inspection.manifest.targets.isEmpty,
                            "repository inspection preserves package targets"
                        )

                        try Expect.true(
                            !inspection.symbolGraphs.files.isEmpty,
                            "repository inspection discovers public compiler symbol graphs"
                        )

                        try Expect.true(
                            inspection.symbolGraphs.files.allSatisfy {
                                $0.lastPathComponent.hasSuffix(
                                    ".symbols.json"
                                )
                            },
                            "repository inspection exposes only symbol graph JSON artifacts"
                        )

                        try Expect.true(
                            inspection.symbolGraphs.files.contains {
                                $0.lastPathComponent == "Primitives.symbols.json"
                            },
                            "Primitives module symbol graph is present"
                        )

                        return materialization.storageRoot
                    }

                try Expect.equal(
                    FileManager.default.fileExists(
                        atPath: storageRoot.path
                    ),
                    false,
                    "temporary repository materialization is removed after use"
                )
            }
        }
    }
}

private enum DocumentationRepositoryFlowError:
    Error
{
    case invalidOrigin
}
