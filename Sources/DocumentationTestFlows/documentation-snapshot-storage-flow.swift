import Documentation
import Foundation
import TestFlows

extension DocumentationFlowSuite {
    static var documentationSnapshotStorageFlow: TestFlow {
        TestFlow(
            "documentation-snapshot-storage",
            tags: [
                "documentation",
                "snapshot",
                "storage",
                "persistence",
            ]
        ) {
            Step("snapshot codec and store preserve semantic graph") {
                let root = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "documentation-snapshot-storage-\(UUID().uuidString)",
                        isDirectory: true
                    )

                defer {
                    try? FileManager.default.removeItem(
                        at: root
                    )
                }

                let store = DocumentationSnapshotStore(
                    root: root
                )

                let snapshot = try makeDocumentationStorageSnapshot()

                let encoded = try DocumentationSnapshotCodec.encode(
                    snapshot
                )

                let decoded = try DocumentationSnapshotCodec.decode(
                    encoded
                )

                try Expect.equal(
                    decoded,
                    snapshot,
                    "codec round-trip preserves the complete semantic snapshot"
                )

                try Expect.equal(
                    decoded.package,
                    snapshot.package,
                    "codec preserves package, product, target, and module topology"
                )

                try Expect.equal(
                    decoded.package.targets.first?.module,
                    Optional(
                        DocumentationModuleIdentity(
                            rawValue: "Demo"
                        )
                    ),
                    "codec preserves typed target-to-module binding"
                )

                try Expect.equal(
                    decoded.collection.symbols.first?
                        .content
                        .authoredMarkup,
                    Optional(
                        "Summary line.\n\n- authored item"
                    ),
                    "codec preserves authored markup exactly"
                )

                try Expect.equal(
                    decoded.collection.symbols.first?
                        .declaration?
                        .fragments
                        .last?
                        .referencedSymbol,
                    Optional(
                        DocumentationSymbolIdentity(
                            rawValue: "s:4Demo9ContainerV"
                        )
                    ),
                    "codec preserves declaration symbol references"
                )

                try Expect.equal(
                    decoded.collection.relationships.first?
                        .targetFallback,
                    Optional(
                        "Demo.Container"
                    ),
                    "codec preserves relationship target fallback"
                )

                try Expect.equal(
                    decoded.collection.relationships.first?
                        .sourceOrigin?
                        .displayName,
                    Optional(
                        "Container"
                    ),
                    "codec preserves relationship source origin"
                )

                try store.save(
                    snapshot
                )

                try Expect.true(
                    store.contains(
                        snapshot.identity
                    ),
                    "saved snapshot is discoverable by semantic identity"
                )

                try Expect.equal(
                    try store.load(
                        snapshot.identity
                    ),
                    Optional(
                        snapshot
                    ),
                    "filesystem store round-trips semantic snapshot"
                )

                try store.save(
                    snapshot
                )

                try Expect.equal(
                    try store.load(
                        snapshot.identity
                    ),
                    Optional(
                        snapshot
                    ),
                    "repeated atomic save remains valid"
                )

                let secondSnapshot = try makeDocumentationStorageSnapshot(
                    commit: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                )

                try store.save(
                    secondSnapshot
                )

                try Expect.true(
                    store.fileURL(
                        for: snapshot.identity
                    )
                        != store.fileURL(
                            for: secondSnapshot.identity
                        ),
                    "different semantic identities use distinct deterministic cache files"
                )

                try Expect.equal(
                    try store.load(
                        snapshot.identity
                    ),
                    Optional(
                        snapshot
                    ),
                    "first immutable snapshot remains available after storing another identity"
                )

                try Expect.equal(
                    try store.load(
                        secondSnapshot.identity
                    ),
                    Optional(
                        secondSnapshot
                    ),
                    "second immutable snapshot remains independently addressable"
                )

                try Data(
                    "not-json".utf8
                )
                    .write(
                        to: store.fileURL(
                            for: snapshot.identity
                        ),
                        options: .atomic
                    )

                var corruptSnapshotFailed = false

                do {
                    _ = try store.load(
                        snapshot.identity
                    )
                } catch {
                    corruptSnapshotFailed = true
                }

                try Expect.true(
                    corruptSnapshotFailed,
                    "corrupt snapshot data fails instead of producing semantic content"
                )

                let unsupportedData = Data(
                    "{\"storageFormatVersion\":999}".utf8
                )

                try unsupportedData.write(
                    to: store.fileURL(
                        for: snapshot.identity
                    ),
                    options: .atomic
                )

                var unsupportedVersion: Int?

                do {
                    _ = try store.load(
                        snapshot.identity
                    )
                } catch let error as DocumentationSnapshotStorageError {
                    if case .unsupportedStorageFormat(let version) = error {
                        unsupportedVersion = version
                    }
                }

                try Expect.equal(
                    unsupportedVersion,
                    Optional(999),
                    "unsupported storage generation is rejected explicitly"
                )
            }
        }
    }
}

private func makeDocumentationStorageSnapshot(
    commit: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    toolchain: String = "swift-6.3-test"
) throws -> DocumentationSnapshot {
    guard let origin = URL(
        string: "https://example.com/Demo.git"
    ) else {
        throw DocumentationSnapshotStorageFlowError.invalidOrigin
    }

    let requested = DocumentationRepositoryRevision.branch(
        "main"
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
            rawValue: toolchain
        )
    )

    let symbolIdentity = DocumentationSymbolIdentity(
        rawValue: "s:4Demo4TypeV"
    )

    let referencedIdentity = DocumentationSymbolIdentity(
        rawValue: "s:4Demo9ContainerV"
    )

    let package = DocumentationPackage(
        name: "Demo",
        toolsVersion: "6.3",
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
                path: "Sources/Demo",
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
    )

    let collection = DocumentationCollection(
        identity: .init(
            rawValue: "https://example.com/Demo.git#\(commit)"
        ),
        title: "Demo",
        content: .init(
            authoredMarkup: "# Demo",
            structuredContent: .group(
                role: .init(
                    rawValue: "documentation.overview"
                ),
                title: [
                    .strong(
                        [
                            .text("Overview"),
                        ]
                    ),
                ],
                content: .paragraph(
                    [
                        .text("Package overview."),
                    ]
                )
            )
        ),
        symbols: [
            .init(
                identity: symbolIdentity,
                name: "Type",
                path: [
                    "Type",
                ],
                kind: .init(
                    rawValue: "swift.struct"
                ),
                declaration: .init(
                    fragments: [
                        .init(
                            kind: .init(
                                rawValue: "keyword"
                            ),
                            spelling: "struct"
                        ),
                        .init(
                            kind: .init(
                                rawValue: "text"
                            ),
                            spelling: " "
                        ),
                        .init(
                            kind: .init(
                                rawValue: "identifier"
                            ),
                            spelling: "Type"
                        ),
                        .init(
                            kind: .init(
                                rawValue: "typeIdentifier"
                            ),
                            spelling: "Container",
                            referencedSymbol: referencedIdentity
                        ),
                    ]
                ),
                content: .init(
                    authoredMarkup: "Summary line.\n\n- authored item",
                    structuredContent: .collection(
                        [
                            .paragraph(
                                [
                                    .text("Use "),
                                    .strong(
                                        [
                                            .text("strong"),
                                        ]
                                    ),
                                    .text(" and "),
                                    .emphasis(
                                        [
                                            .text("emphasis"),
                                        ]
                                    ),
                                    .text(" with "),
                                    .code("inlineCode"),
                                    .text("."),
                                ]
                            ),
                            .code(
                                language: "swift",
                                source: "let value = 1\nprint(value)"
                            ),
                            .quote(
                                .paragraph(
                                    [
                                        .text("Quoted documentation."),
                                    ]
                                )
                            ),
                            .list(
                                style: .unordered,
                                items: [
                                    .paragraph(
                                        [
                                            .text("First"),
                                        ]
                                    ),
                                    .paragraph(
                                        [
                                            .text("Second"),
                                        ]
                                    ),
                                ]
                            ),
                            .list(
                                style: .ordered,
                                items: [
                                    .list(
                                        style: .unordered,
                                        items: [
                                            .paragraph(
                                                [
                                                    .text("Nested"),
                                                ]
                                            ),
                                        ]
                                    ),
                                ]
                            ),
                            .group(
                                role: .init(
                                    rawValue: "documentation.test"
                                ),
                                title: [
                                    .text("Details"),
                                ],
                                content: .paragraph(
                                    [
                                        .text("Grouped content."),
                                    ]
                                )
                            ),
                        ]
                    )
                ),
                source: .init(
                    uri: "Sources/Demo/Type.swift",
                    line: 12,
                    character: 5
                ),
                provenance: .source
            ),
        ],
        relationships: [
            .init(
                source: symbolIdentity,
                target: referencedIdentity,
                kind: .init(
                    rawValue: "memberOf"
                ),
                targetFallback: "Demo.Container",
                sourceOrigin: .init(
                    symbol: referencedIdentity,
                    displayName: "Container"
                )
            ),
        ]
    )

    return .init(
        identity: identity,
        repository: repository,
        revision: revision,
        package: package,
        collection: collection
    )
}

private enum DocumentationSnapshotStorageFlowError:
    Error
{
    case invalidOrigin
}
