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

                let result = try await DocumentationRepositoryMaterializer
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

                        let snapshot = try DocumentationRepositoryDeriver.derive(
                            inspection,
                            from: materialization,
                            toolchain: .init(
                                rawValue: "swift-test-toolchain"
                            )
                        )

                        try Expect.equal(
                            snapshot.collection.title,
                            "Primitives",
                            "semantic collection preserves package title"
                        )

                        try Expect.equal(
                            snapshot.package.name,
                            "Primitives",
                            "snapshot promotes Swift package identity into semantic topology"
                        )

                        try Expect.true(
                            snapshot.package.modules.contains {
                                $0.name == "Primitives"
                            },
                            "compiler module topology includes Primitives"
                        )

                        try Expect.true(
                            snapshot.package.targets.contains { target in
                                target.name == "Primitives"
                                    && target.module
                                        == DocumentationModuleIdentity(
                                            rawValue: "Primitives"
                                        )
                            },
                            "SwiftPM target is linked to the compiler-proven Primitives module"
                        )

                        try Expect.true(
                            snapshot.package.products.contains { product in
                                product.name == "Primitives"
                                    && product.kind.rawValue == "library"
                                    && product.targets.contains(
                                        .init(
                                            rawValue: "Primitives"
                                        )
                                    )
                            },
                            "library product retains typed target topology"
                        )

                        try Expect.true(
                            !snapshot.collection.symbols.isEmpty,
                            "semantic collection contains compiler symbols"
                        )

                        try Expect.true(
                            !snapshot.collection.relationships.isEmpty,
                            "semantic collection contains compiler relationships"
                        )

                        try Expect.true(
                            snapshot.collection.symbols.contains {
                                $0.kind.rawValue.hasPrefix(
                                    "swift."
                                )
                            },
                            "semantic symbol kinds retain language namespace"
                        )

                        try Expect.true(
                            snapshot.collection.symbols.contains {
                                $0.content.authoredMarkup?
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                    .isEmpty == false
                            },
                            "semantic symbols preserve authored documentation markup"
                        )

                        try Expect.true(
                            snapshot.collection.symbols.contains { symbol in
                                guard
                                    symbol.content.authoredMarkup?
                                        .trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        )
                                        .isEmpty == false
                                else {
                                    return false
                                }

                                return symbol.content.structuredContent
                                    != .collection([])
                            },
                            "authored documentation is projected into shared structured content"
                        )

                        try Expect.true(
                            snapshot.collection.symbols.contains {
                                $0.declaration?
                                    .fragments
                                    .contains {
                                        $0.referencedSymbol != nil
                                    }
                                    == true
                            },
                            "declaration fragments preserve typed symbol references"
                        )

                        let sourceReferences = snapshot
                            .collection
                            .symbols
                            .compactMap(
                                \.source
                            )

                        try Expect.true(
                            sourceReferences.contains {
                                $0.uri.hasPrefix(
                                    "Sources/Primitives/"
                                )
                            },
                            "repository source references become checkout-relative"
                        )

                        try Expect.true(
                            sourceReferences.allSatisfy {
                                !$0.uri.contains(
                                    materialization.storageRoot.path
                                )
                            },
                            "semantic source references do not retain temporary checkout paths"
                        )

                        try Expect.true(
                            snapshot.collection.relationships.contains {
                                $0.sourceOrigin != nil
                            },
                            "relationship source origins remain semantic references"
                        )

                        try Expect.true(
                            snapshot.collection.symbols.contains {
                                $0.provenance == .synthesized
                            },
                            "compiler-derived synthesized symbols remain classified"
                        )

                        return (
                            storageRoot: materialization.storageRoot,
                            snapshot: snapshot
                        )
                    }

                try Expect.equal(
                    FileManager.default.fileExists(
                        atPath: result.storageRoot.path
                    ),
                    false,
                    "temporary repository materialization is removed after use"
                )

                try Expect.true(
                    !result.snapshot.collection.symbols.isEmpty,
                    "snapshot semantic content survives temporary checkout deletion"
                )

                try Expect.equal(
                    result.snapshot.identity.commit,
                    result.snapshot.revision.commit,
                    "snapshot identity retains the immutable resolved commit after checkout deletion"
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
