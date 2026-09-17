import Documentation
import Foundation
import TestFlows

extension DocumentationFlowSuite {
    static var documentationCatalogFlow: TestFlow {
        TestFlow(
            "documentation-catalog",
            tags: [
                "documentation",
                "catalog",
                "query",
                "semantic",
            ]
        ) {
            Step("catalog queries immutable snapshots without renderer semantics") {
                let root = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "documentation-catalog-\(UUID().uuidString)",
                        isDirectory: true
                    )

                defer {
                    try? FileManager.default.removeItem(
                        at: root
                    )
                }

                let sharedIdentity = DocumentationSymbolIdentity(
                    rawValue: "s:SharedType"
                )

                let targetIdentity = DocumentationSymbolIdentity(
                    rawValue: "s:TargetType"
                )

                let first = try makeDocumentationCatalogSnapshot(
                    origin: "https://example.com/First.git",
                    commit: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    packageName: "First",
                    moduleName: "FirstCore",
                    sharedIdentity: sharedIdentity,
                    targetIdentity: targetIdentity,
                    includeRelationship: true
                )

                let second = try makeDocumentationCatalogSnapshot(
                    origin: "https://example.com/Second.git",
                    commit: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    packageName: "Second",
                    moduleName: "SecondCore",
                    sharedIdentity: sharedIdentity,
                    targetIdentity: targetIdentity,
                    includeRelationship: false
                )

                let store = DocumentationSnapshotStore(
                    root: root
                )

                try store.save(
                    second
                )
                try store.save(
                    first
                )

                let catalog = try store.catalog()

                try Expect.equal(
                    catalog.snapshots.count,
                    2,
                    "snapshot store materializes a multi-repository catalog"
                )

                try Expect.equal(
                    catalog.snapshot(
                        first.identity
                    ),
                    Optional(
                        first
                    ),
                    "catalog retrieves an immutable snapshot by semantic identity"
                )

                try Expect.equal(
                    catalog.snapshots(
                        repositoryOrigin: first.identity.repositoryOrigin
                    ),
                    [
                        first,
                    ],
                    "catalog filters immutable revisions by repository origin"
                )

                try Expect.equal(
                    catalog.packages(
                        named: "First"
                    ).map {
                        $0.package.name
                    },
                    [
                        "First",
                    ],
                    "catalog locates package semantics independently of presentation"
                )

                try Expect.equal(
                    catalog.modules(
                        named: "SecondCore"
                    ).map {
                        $0.module.identity
                    },
                    [
                        DocumentationModuleIdentity(
                            rawValue: "SecondCore"
                        ),
                    ],
                    "catalog locates compiler modules across repositories"
                )

                let repeatedIdentity = catalog.symbols(
                    identity: sharedIdentity
                )

                try Expect.equal(
                    repeatedIdentity.count,
                    2,
                    "symbol identity lookup retains occurrences from separate immutable snapshots"
                )

                try Expect.true(
                    repeatedIdentity.contains {
                        $0.snapshotIdentity == first.identity
                    },
                    "symbol occurrence identifies its first containing snapshot"
                )

                try Expect.true(
                    repeatedIdentity.contains {
                        $0.snapshotIdentity == second.identity
                    },
                    "symbol occurrence identifies its second containing snapshot"
                )

                try Expect.equal(
                    catalog.symbols(
                        named: "sharedtype",
                        caseSensitive: false
                    ).count,
                    2,
                    "case-insensitive exact-name lookup is explicit"
                )

                try Expect.equal(
                    catalog.symbols(
                        matching: "SharedType",
                        maximumResults: 1
                    ).count,
                    1,
                    "deterministic semantic search honors result bounds"
                )

                let pathMatches = catalog.symbols(
                    matching: "InterestingPath"
                )

                try Expect.equal(
                    pathMatches.count,
                    2,
                    "semantic search discovers symbols through declaration path components"
                )

                try Expect.true(
                    pathMatches.allSatisfy {
                        $0.symbol.name == "Child"
                    },
                    "path search returns the matching semantic symbols"
                )

                let outgoing = catalog.relationships(
                    from: sharedIdentity,
                    in: first.identity
                )

                try Expect.equal(
                    outgoing.count,
                    1,
                    "catalog traverses outgoing API relationships within a snapshot"
                )

                try Expect.equal(
                    outgoing.first?.target,
                    Optional(
                        targetIdentity
                    ),
                    "relationship traversal preserves target symbol identity"
                )

                try Expect.equal(
                    catalog.relationships(
                        to: targetIdentity,
                        in: first.identity
                    ).count,
                    1,
                    "catalog traverses incoming API relationships within a snapshot"
                )

                try Expect.equal(
                    catalog.referencedSymbolIdentities(
                        from: sharedIdentity,
                        in: first.identity
                    ),
                    [
                        targetIdentity,
                    ],
                    "declaration queries retain referenced symbol identity without requiring resolution"
                )

                try Expect.equal(
                    catalog.symbols(
                        identity: targetIdentity
                    ).count,
                    2,
                    "declaration reference identities can be resolved across the wider catalog when desired"
                )
            }
        }
    }
}

private func makeDocumentationCatalogSnapshot(
    origin: String,
    commit: String,
    packageName: String,
    moduleName: String,
    sharedIdentity: DocumentationSymbolIdentity,
    targetIdentity: DocumentationSymbolIdentity,
    includeRelationship: Bool
) throws -> DocumentationSnapshot {
    guard let origin = URL(
        string: origin
    ) else {
        throw DocumentationCatalogFlowError.invalidOrigin
    }

    let requested = DocumentationRepositoryRevision.commit(
        commit
    )

    let repository = DocumentationRepository(
        origin: origin,
        revision: requested
    )

    let revision = DocumentationResolvedRevision(
        requested: requested,
        commit: commit
    )

    let identity = DocumentationSnapshotIdentity(
        repository: repository,
        revision: revision,
        toolchain: .init(
            rawValue: "swift-catalog-test"
        )
    )

    let package = DocumentationPackage(
        name: packageName,
        products: [
            .init(
                name: packageName,
                kind: .init(
                    rawValue: "library"
                ),
                targets: [
                    .init(
                        rawValue: moduleName
                    ),
                ]
            ),
        ],
        targets: [
            .init(
                identity: .init(
                    rawValue: moduleName
                ),
                name: moduleName,
                type: "regular",
                module: .init(
                    rawValue: moduleName
                )
            ),
        ],
        modules: [
            .init(
                identity: .init(
                    rawValue: moduleName
                ),
                name: moduleName
            ),
        ]
    )

    let shared = DocumentationSymbol(
        identity: sharedIdentity,
        name: "SharedType",
        path: [
            "SharedType",
        ],
        kind: .init(
            rawValue: "swift.struct"
        ),
        declaration: .init(
            fragments: [
                .init(
                    kind: .init(
                        rawValue: "identifier"
                    ),
                    spelling: "SharedType"
                ),
                .init(
                    kind: .init(
                        rawValue: "typeIdentifier"
                    ),
                    spelling: "TargetType",
                    referencedSymbol: targetIdentity
                ),
            ]
        ),
        provenance: .source
    )

    let target = DocumentationSymbol(
        identity: targetIdentity,
        name: "TargetType",
        path: [
            "Container",
            "TargetType",
        ],
        kind: .init(
            rawValue: "swift.struct"
        ),
        provenance: .source
    )

    let child = DocumentationSymbol(
        identity: .init(
            rawValue: "s:\(packageName).Child"
        ),
        name: "Child",
        path: [
            "Outer",
            "InterestingPath",
            "Child",
        ],
        kind: .init(
            rawValue: "swift.method"
        ),
        provenance: .source
    )

    let relationships: [DocumentationRelationship]

    if includeRelationship {
        relationships = [
            .init(
                source: sharedIdentity,
                target: targetIdentity,
                kind: .init(
                    rawValue: "memberOf"
                )
            ),
        ]
    } else {
        relationships = []
    }

    return .init(
        identity: identity,
        repository: repository,
        revision: revision,
        package: package,
        collection: .init(
            identity: .init(
                rawValue: origin.absoluteString + "#" + commit
            ),
            title: packageName,
            symbols: [
                shared,
                target,
                child,
            ],
            relationships: relationships
        )
    )
}

private enum DocumentationCatalogFlowError:
    Error
{
    case invalidOrigin
}
