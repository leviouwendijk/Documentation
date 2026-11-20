import Documentation
import Foundation
import TestFlows

extension DocumentationFlowSuite {
    static var documentationSnapshotFlow: TestFlow {
        TestFlow(
            "documentation-snapshot",
            tags: [
                "documentation",
                "snapshot",
                "identity",
                "semantic",
            ]
        ) {
            Step("snapshot identity uses immutable semantic generation inputs") {
                guard let origin = URL(
                    string: "https://example.com/Demo.git"
                ) else {
                    throw DocumentationSnapshotFlowError.invalidOrigin
                }

                let toolchain = DocumentationToolchainIdentity(
                    rawValue: "swift-6.3-test"
                )

                let branchRepository = DocumentationRepository(
                    origin: origin,
                    revision: .branch(
                        "main"
                    )
                )

                let branchRevision = DocumentationResolvedRevision(
                    requested: .branch(
                        "main"
                    ),
                    commit: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                )

                let identity = DocumentationSnapshotIdentity(
                    repository: branchRepository,
                    revision: branchRevision,
                    toolchain: toolchain
                )

                let repeatedIdentity = DocumentationSnapshotIdentity(
                    repository: branchRepository,
                    revision: branchRevision,
                    toolchain: toolchain
                )

                try Expect.equal(
                    identity,
                    repeatedIdentity,
                    "identical semantic inputs produce identical snapshot identity"
                )

                let tagRepository = DocumentationRepository(
                    origin: origin,
                    revision: .tag(
                        "1.0.0"
                    )
                )

                let tagRevision = DocumentationResolvedRevision(
                    requested: .tag(
                        "1.0.0"
                    ),
                    commit: branchRevision.commit
                )

                let tagIdentity = DocumentationSnapshotIdentity(
                    repository: tagRepository,
                    revision: tagRevision,
                    toolchain: toolchain
                )

                try Expect.equal(
                    identity,
                    tagIdentity,
                    "different requested revisions resolving the same commit reuse semantic identity"
                )

                let differentCommit = DocumentationSnapshotIdentity(
                    repository: branchRepository,
                    revision: .init(
                        requested: branchRevision.requested,
                        commit: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                    ),
                    toolchain: toolchain
                )

                try Expect.true(
                    identity != differentCommit,
                    "resolved commit participates in snapshot identity"
                )

                let differentToolchain = DocumentationSnapshotIdentity(
                    repository: branchRepository,
                    revision: branchRevision,
                    toolchain: .init(
                        rawValue: "swift-6.4-test"
                    )
                )

                try Expect.true(
                    identity != differentToolchain,
                    "toolchain participates in snapshot identity"
                )

                let differentImporter = DocumentationSnapshotIdentity(
                    repository: branchRepository,
                    revision: branchRevision,
                    toolchain: toolchain,
                    importerVersion: .init(
                        rawValue:
                            DocumentationImporterVersion.current.rawValue
                            + 1
                    )
                )

                try Expect.true(
                    identity != differentImporter,
                    "importer version participates in snapshot identity"
                )

                let snapshot = DocumentationSnapshot(
                    identity: identity,
                    repository: branchRepository,
                    revision: branchRevision,
                    package: .init(
                        name: "Demo",
                        products: [
                            .init(
                                name: "Demo",
                                kind: .init(
                                    rawValue: "library"
                                ),
                                targets: [
                                    .init(
                                        rawValue: "Demo"
                                    ),
                                ]
                            ),
                        ],
                        targets: [
                            .init(
                                identity: .init(
                                    rawValue: "Demo"
                                ),
                                name: "Demo",
                                type: "regular",
                                module: .init(
                                    rawValue: "Demo"
                                )
                            ),
                        ],
                        modules: [
                            .init(
                                identity: .init(
                                    rawValue: "Demo"
                                ),
                                name: "Demo"
                            ),
                        ]
                    ),
                    collection: .init(
                        identity: .init(
                            rawValue: "demo"
                        ),
                        title: "Demo"
                    )
                )

                try Expect.equal(
                    snapshot.repository.revision,
                    DocumentationRepositoryRevision.branch(
                        "main"
                    ),
                    "snapshot preserves requested repository provenance"
                )

                try Expect.equal(
                    snapshot.revision.requested,
                    DocumentationRepositoryRevision.branch(
                        "main"
                    ),
                    "snapshot preserves requested resolved-revision provenance"
                )

                try Expect.equal(
                    snapshot.identity,
                    identity,
                    "snapshot carries deterministic semantic identity"
                )

                try Expect.equal(
                    snapshot.package.modules.first?.identity,
                    Optional(
                        DocumentationModuleIdentity(
                            rawValue: "Demo"
                        )
                    ),
                    "snapshot carries typed package module topology"
                )

                try Expect.equal(
                    snapshot.package.targets.first?.module,
                    Optional(
                        DocumentationModuleIdentity(
                            rawValue: "Demo"
                        )
                    ),
                    "snapshot target can bind to a compiler-proven module"
                )
            }
        }
    }
}

private enum DocumentationSnapshotFlowError:
    Error
{
    case invalidOrigin
}
