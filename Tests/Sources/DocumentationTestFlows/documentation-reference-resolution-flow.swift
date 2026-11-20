import Documentation
import Foundation
import TestFlows

extension DocumentationFlowSuite {
    static var documentationReferenceResolutionFlow: TestFlow {
        TestFlow(
            "documentation-reference-resolution",
            tags: [
                "documentation",
                "catalog",
                "reference",
                "resolution",
                "semantic",
            ]
        ) {
            Step("cross-snapshot references resolve without guessing revisions") {
                let sourceIdentity = DocumentationSymbolIdentity(
                    rawValue: "s:Source"
                )

                let localIdentity = DocumentationSymbolIdentity(
                    rawValue: "s:Local"
                )

                let uniqueExternalIdentity = DocumentationSymbolIdentity(
                    rawValue: "s:UniqueExternal"
                )

                let ambiguousExternalIdentity = DocumentationSymbolIdentity(
                    rawValue: "s:AmbiguousExternal"
                )

                let missingIdentity = DocumentationSymbolIdentity(
                    rawValue: "s:Missing"
                )

                let sourceSnapshot = try makeReferenceResolutionSnapshot(
                    origin: "https://example.com/Source.git",
                    commit: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    packageName: "Source",
                    symbols: [
                        DocumentationSymbol(
                            identity: sourceIdentity,
                            name: "Source",
                            path: [
                                "Source",
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
                                        spelling: "Source"
                                    ),
                                    .init(
                                        kind: .init(
                                            rawValue: "typeIdentifier"
                                        ),
                                        spelling: "Local",
                                        referencedSymbol: localIdentity
                                    ),
                                    .init(
                                        kind: .init(
                                            rawValue: "typeIdentifier"
                                        ),
                                        spelling: "UniqueExternal",
                                        referencedSymbol: uniqueExternalIdentity
                                    ),
                                    .init(
                                        kind: .init(
                                            rawValue: "typeIdentifier"
                                        ),
                                        spelling: "AmbiguousExternal",
                                        referencedSymbol: ambiguousExternalIdentity
                                    ),
                                    .init(
                                        kind: .init(
                                            rawValue: "typeIdentifier"
                                        ),
                                        spelling: "Missing",
                                        referencedSymbol: missingIdentity
                                    ),
                                ]
                            ),
                            provenance: .source
                        ),
                        DocumentationSymbol(
                            identity: localIdentity,
                            name: "Local",
                            path: [
                                "Local",
                            ],
                            kind: .init(
                                rawValue: "swift.struct"
                            ),
                            provenance: .source
                        ),
                    ],
                    relationships: [
                        .init(
                            source: sourceIdentity,
                            target: uniqueExternalIdentity,
                            kind: .init(
                                rawValue: "conformsTo"
                            )
                        ),
                        .init(
                            source: sourceIdentity,
                            target: missingIdentity,
                            kind: .init(
                                rawValue: "memberOf"
                            )
                        ),
                    ]
                )

                let localHistoricalSnapshot = try makeReferenceResolutionSnapshot(
                    origin: "https://example.com/LocalHistory.git",
                    commit: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    packageName: "LocalHistory",
                    symbols: [
                        DocumentationSymbol(
                            identity: localIdentity,
                            name: "Local",
                            path: [
                                "Historical",
                                "Local",
                            ],
                            kind: .init(
                                rawValue: "swift.struct"
                            ),
                            provenance: .source
                        ),
                    ]
                )

                let uniqueExternalSnapshot = try makeReferenceResolutionSnapshot(
                    origin: "https://example.com/Unique.git",
                    commit: "cccccccccccccccccccccccccccccccccccccccc",
                    packageName: "Unique",
                    symbols: [
                        DocumentationSymbol(
                            identity: uniqueExternalIdentity,
                            name: "UniqueExternal",
                            path: [
                                "UniqueExternal",
                            ],
                            kind: .init(
                                rawValue: "swift.protocol"
                            ),
                            provenance: .source
                        ),
                    ]
                )

                let ambiguousOrigin = "https://example.com/Ambiguous.git"

                let ambiguousA = try makeReferenceResolutionSnapshot(
                    origin: ambiguousOrigin,
                    commit: "dddddddddddddddddddddddddddddddddddddddd",
                    packageName: "Ambiguous",
                    symbols: [
                        DocumentationSymbol(
                            identity: ambiguousExternalIdentity,
                            name: "AmbiguousExternal",
                            path: [
                                "AmbiguousExternal",
                            ],
                            kind: .init(
                                rawValue: "swift.struct"
                            ),
                            provenance: .source
                        ),
                    ]
                )

                let ambiguousB = try makeReferenceResolutionSnapshot(
                    origin: ambiguousOrigin,
                    commit: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
                    packageName: "Ambiguous",
                    symbols: [
                        DocumentationSymbol(
                            identity: ambiguousExternalIdentity,
                            name: "AmbiguousExternal",
                            path: [
                                "AmbiguousExternal",
                            ],
                            kind: .init(
                                rawValue: "swift.struct"
                            ),
                            provenance: .source
                        ),
                    ]
                )

                let catalog = DocumentationCatalog(
                    snapshots: [
                        ambiguousB,
                        uniqueExternalSnapshot,
                        sourceSnapshot,
                        ambiguousA,
                        localHistoricalSnapshot,
                    ]
                )

                let localResolution = catalog.resolveSymbol(
                    localIdentity,
                    from: sourceSnapshot.identity
                )

                try Expect.equal(
                    localResolution.resolvedSymbol?.snapshotIdentity,
                    Optional(
                        sourceSnapshot.identity
                    ),
                    "same-snapshot target wins over matching identities in other snapshots"
                )

                let uniqueResolution = catalog.resolveSymbol(
                    uniqueExternalIdentity,
                    from: sourceSnapshot.identity
                )

                try Expect.equal(
                    uniqueResolution.resolvedSymbol?.snapshotIdentity,
                    Optional(
                        uniqueExternalSnapshot.identity
                    ),
                    "sole external occurrence resolves across repository snapshots"
                )

                let ambiguousResolution = catalog.resolveSymbol(
                    ambiguousExternalIdentity,
                    from: sourceSnapshot.identity
                )

                switch ambiguousResolution {
                case .ambiguous(let candidates):
                    try Expect.equal(
                        candidates.count,
                        2,
                        "multiple external immutable revisions remain explicitly ambiguous"
                    )

                    try Expect.true(
                        candidates.contains {
                            $0.snapshotIdentity == ambiguousA.identity
                        },
                        "ambiguity retains first immutable candidate"
                    )

                    try Expect.true(
                        candidates.contains {
                            $0.snapshotIdentity == ambiguousB.identity
                        },
                        "ambiguity retains second immutable candidate"
                    )

                default:
                    throw DocumentationReferenceResolutionFlowError
                        .expectedAmbiguousResolution
                }

                let missingResolution = catalog.resolveSymbol(
                    missingIdentity,
                    from: sourceSnapshot.identity
                )

                try Expect.equal(
                    missingResolution,
                    .unresolved(
                        missingIdentity
                    ),
                    "absent precise identity remains explicitly unresolved"
                )

                let references = catalog.references(
                    from: sourceIdentity,
                    in: sourceSnapshot.identity
                )

                try Expect.equal(
                    references.count,
                    6,
                    "declaration fragments and semantic relationships project as separate outbound references"
                )

                let declarationReferences = references.filter { reference in
                    if case .declarationFragment = reference.kind {
                        return true
                    }

                    return false
                }

                try Expect.equal(
                    declarationReferences.count,
                    4,
                    "all precise declaration fragment references are retained"
                )

                try Expect.true(
                    declarationReferences.contains { reference in
                        reference.kind
                            == .declarationFragment(
                                index: 1
                            )
                            && reference.targetIdentity == localIdentity
                            && reference.resolution.resolvedSymbol?
                                .snapshotIdentity == sourceSnapshot.identity
                    },
                    "declaration reference keeps exact fragment occurrence and local resolution"
                )

                try Expect.true(
                    references.contains { reference in
                        reference.kind
                            == .relationship(
                                kind: .init(
                                    rawValue: "conformsTo"
                                )
                            )
                            && reference.targetIdentity == uniqueExternalIdentity
                            && reference.resolution.resolvedSymbol?
                                .snapshotIdentity == uniqueExternalSnapshot.identity
                    },
                    "relationship references participate in cross-snapshot resolution"
                )

                try Expect.true(
                    references.contains { reference in
                        reference.kind
                            == .relationship(
                                kind: .init(
                                    rawValue: "memberOf"
                                )
                            )
                            && reference.resolution
                                == .unresolved(
                                    missingIdentity
                                )
                    },
                    "unresolved relationship identities remain present rather than being discarded"
                )

                try Expect.true(
                    references.allSatisfy {
                        $0.source.snapshotIdentity == sourceSnapshot.identity
                            && $0.source.symbol.identity == sourceIdentity
                    },
                    "every projected reference retains its exact source occurrence"
                )
            }
        }
    }
}

private func makeReferenceResolutionSnapshot(
    origin: String,
    commit: String,
    packageName: String,
    symbols: [DocumentationSymbol],
    relationships: [DocumentationRelationship] = []
) throws -> DocumentationSnapshot {
    guard let origin = URL(
        string: origin
    ) else {
        throw DocumentationReferenceResolutionFlowError.invalidOrigin
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
            rawValue: "swift-reference-resolution-test"
        )
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
                rawValue: origin.absoluteString + "#" + commit
            ),
            title: packageName,
            symbols: symbols,
            relationships: relationships
        )
    )
}

private enum DocumentationReferenceResolutionFlowError:
    Error
{
    case invalidOrigin
    case expectedAmbiguousResolution
}
