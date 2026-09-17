import Documentation
import Foundation
import TestFlows

extension DocumentationFlowSuite {
    static var documentationRepositoryCatalogFlow: TestFlow {
        TestFlow(
            "documentation-repository-catalog",
            tags: [
                "documentation",
                "catalog",
                "repository",
                "refresh",
                "semantic",
            ]
        ) {
            Step("configured repositories retain provenance while semantic snapshots deduplicate") {
                let originA = try documentationRepositoryCatalogURL(
                    "https://example.com/A.git"
                )

                let originB = try documentationRepositoryCatalogURL(
                    "https://example.com/B.git"
                )

                let commitA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                let commitB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

                let branchA = DocumentationRepository(
                    origin: originA,
                    revision: .branch(
                        "main"
                    )
                )

                let exactA = DocumentationRepository(
                    origin: originA,
                    revision: .commit(
                        commitA
                    )
                )

                let branchB = DocumentationRepository(
                    origin: originB,
                    revision: .branch(
                        "main"
                    )
                )

                let toolchain = DocumentationToolchainIdentity(
                    rawValue: "swift-repository-catalog-test"
                )

                let counter = DocumentationRepositoryCatalogRefreshCounter()

                let provider = DocumentationRepositoryCatalogProvider(
                    storageRoot: FileManager.default.temporaryDirectory
                )

                let configured = try await provider.refresh(
                    [
                        branchA,
                        exactA,
                        branchB,
                    ],
                    toolchain: toolchain
                ) { repository in
                    await counter.record(
                        repository
                    )

                    if repository.origin == originA {
                        return documentationRepositoryCatalogSnapshot(
                            repository: repository,
                            commit: commitA,
                            packageName: "A",
                            toolchain: toolchain
                        )
                    }

                    return documentationRepositoryCatalogSnapshot(
                        repository: repository,
                        commit: commitB,
                        packageName: "B",
                        toolchain: toolchain
                    )
                }

                try Expect.equal(
                    configured.entries.count,
                    3,
                    "configured catalog retains one entry per repository request"
                )

                try Expect.equal(
                    await counter.repositories(),
                    [
                        branchA,
                        exactA,
                        branchB,
                    ],
                    "repository refresh executes deterministically in configuration order"
                )

                try Expect.equal(
                    configured.entries[0].repository,
                    branchA,
                    "first configured entry retains branch request"
                )

                try Expect.equal(
                    configured.entries[0].snapshot.repository.revision,
                    DocumentationRepositoryRevision.branch(
                        "main"
                    ),
                    "first snapshot retains rebound branch provenance"
                )

                try Expect.equal(
                    configured.entries[1].repository,
                    exactA,
                    "second configured entry retains exact commit request"
                )

                try Expect.equal(
                    configured.entries[1].snapshot.repository.revision,
                    DocumentationRepositoryRevision.commit(
                        commitA
                    ),
                    "second snapshot retains rebound exact-commit provenance"
                )

                try Expect.equal(
                    configured.entries[0].snapshot.identity,
                    configured.entries[1].snapshot.identity,
                    "branch and exact commit can share one immutable semantic identity"
                )

                try Expect.equal(
                    configured.catalog.snapshots.count,
                    2,
                    "semantic catalog collapses duplicate immutable identities across configured requests"
                )

                try Expect.equal(
                    configured.catalog.packages(
                        named: "A"
                    ).count,
                    1,
                    "deduplication prevents duplicate semantic package query results"
                )

                try Expect.equal(
                    configured.catalog.packages(
                        named: "B"
                    ).count,
                    1,
                    "independent repository snapshot remains present in semantic catalog"
                )

                let identityA = configured.entries[0].snapshot.identity

                try Expect.equal(
                    configured.catalog.snapshot(
                        identityA
                    )?.identity,
                    Optional(
                        identityA
                    ),
                    "deduplicated semantic snapshot remains directly addressable"
                )
            }

            Step("configured refresh fails without publishing a partial catalog") {
                let origin = try documentationRepositoryCatalogURL(
                    "https://example.com/Failure.git"
                )

                let first = DocumentationRepository(
                    origin: origin,
                    revision: .branch(
                        "first"
                    )
                )

                let second = DocumentationRepository(
                    origin: origin,
                    revision: .branch(
                        "second"
                    )
                )

                let third = DocumentationRepository(
                    origin: origin,
                    revision: .branch(
                        "third"
                    )
                )

                let counter = DocumentationRepositoryCatalogRefreshCounter()

                let provider = DocumentationRepositoryCatalogProvider(
                    storageRoot: FileManager.default.temporaryDirectory
                )

                var failed = false

                do {
                    _ = try await provider.refresh(
                        [
                            first,
                            second,
                            third,
                        ],
                        toolchain: .init(
                            rawValue: "swift-repository-catalog-failure-test"
                        )
                    ) { repository in
                        await counter.record(
                            repository
                        )

                        if repository == second {
                            throw DocumentationRepositoryCatalogFlowError
                                .forcedRefreshFailure
                        }

                        return documentationRepositoryCatalogSnapshot(
                            repository: repository,
                            commit: "cccccccccccccccccccccccccccccccccccccccc",
                            packageName: "Failure",
                            toolchain: .init(
                                rawValue: "swift-repository-catalog-failure-test"
                            )
                        )
                    }
                } catch DocumentationRepositoryCatalogFlowError
                    .forcedRefreshFailure
                {
                    failed = true
                }

                try Expect.true(
                    failed,
                    "repository refresh failure propagates instead of returning a partial configured catalog"
                )

                try Expect.equal(
                    await counter.repositories(),
                    [
                        first,
                        second,
                    ],
                    "deterministic refresh stops at the failed configured repository"
                )
            }
        }
    }
}

private actor DocumentationRepositoryCatalogRefreshCounter {
    private var values: [DocumentationRepository] = []

    func record(
        _ repository: DocumentationRepository
    ) {
        values.append(
            repository
        )
    }

    func repositories() -> [DocumentationRepository] {
        values
    }
}

private func documentationRepositoryCatalogSnapshot(
    repository: DocumentationRepository,
    commit: String,
    packageName: String,
    toolchain: DocumentationToolchainIdentity
) -> DocumentationSnapshot {
    let revision = DocumentationResolvedRevision(
        requested: repository.revision,
        commit: commit
    )

    let identity = DocumentationSnapshotIdentity(
        repository: repository,
        revision: revision,
        toolchain: toolchain
    )

    return .init(
        identity: identity,
        repository: repository,
        revision: revision,
        package: .init(
            name: packageName
        ),
        collection: .init(
            identity: .init(
                rawValue: repository.origin.absoluteString + "#" + commit
            ),
            title: packageName
        )
    )
}

private func documentationRepositoryCatalogURL(
    _ value: String
) throws -> URL {
    guard let url = URL(
        string: value
    ) else {
        throw DocumentationRepositoryCatalogFlowError.invalidOrigin
    }

    return url
}

private enum DocumentationRepositoryCatalogFlowError:
    Error
{
    case invalidOrigin
    case forcedRefreshFailure
}
