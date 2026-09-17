import CryptoKit
import DSL
import Foundation

/// Encoding generation of the disposable Documentation snapshot cache.
///
/// This is intentionally distinct from DocumentationImporterVersion. The
/// importer version describes semantic normalization, while this value
/// describes only the persisted transport representation.
public struct DocumentationSnapshotStorageVersion:
    RawRepresentable,
    Sendable,
    Hashable
{
    public static let current = Self(
        rawValue: 2
    )

    public let rawValue: Int

    public init(
        rawValue: Int
    ) {
        self.rawValue = rawValue
    }
}

public enum DocumentationSnapshotStorageError:
    Error,
    Equatable
{
    case unsupportedStorageFormat(Int)
    case invalidRepositoryOrigin(String)
    case invalidRepositoryRevisionKind(String)
    case invalidStructuredContentKind(String)
    case invalidStructuredContentInlineKind(String)
    case invalidStructuredContentListStyle(String)
    case invalidStructuredContentShape(String)
    case invalidSymbolProvenance(String)
    case importerVersionMismatch(
        expected: Int,
        actual: Int
    )
    case snapshotIdentityMismatch
}

/// Explicit codec for the disposable Documentation snapshot cache.
///
/// Semantic model types deliberately remain independent of Codable. The codec
/// translates through Documentation-owned storage records so the cache format
/// can evolve or be discarded without making synthesized enum encoding part of
/// the public semantic contract.
public enum DocumentationSnapshotCodec {
    public static func encode(
        _ snapshot: DocumentationSnapshot
    ) throws -> Data {
        let envelope = DocumentationSnapshotEnvelope(
            snapshot
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return try encoder.encode(
            envelope
        )
    }

    public static func decode(
        _ data: Data
    ) throws -> DocumentationSnapshot {
        let decoder = JSONDecoder()

        let header = try decoder.decode(
            DocumentationSnapshotEnvelopeHeader.self,
            from: data
        )

        guard
            header.storageFormatVersion
                == DocumentationSnapshotStorageVersion.current.rawValue
        else {
            throw DocumentationSnapshotStorageError
                .unsupportedStorageFormat(
                    header.storageFormatVersion
                )
        }

        let envelope = try decoder.decode(
            DocumentationSnapshotEnvelope.self,
            from: data
        )

        guard
            envelope.importerVersion
                == envelope.snapshot.identity.importerVersion
        else {
            throw DocumentationSnapshotStorageError
                .importerVersionMismatch(
                    expected: envelope.snapshot.identity.importerVersion,
                    actual: envelope.importerVersion
                )
        }

        let snapshot = try envelope.snapshot.semantic()

        guard
            envelope.importerVersion
                == snapshot.identity.importerVersion.rawValue
        else {
            throw DocumentationSnapshotStorageError
                .importerVersionMismatch(
                    expected: snapshot.identity.importerVersion.rawValue,
                    actual: envelope.importerVersion
                )
        }

        return snapshot
    }
}

/// Filesystem-backed cache of immutable Documentation snapshots.
///
/// Storage paths are derived from a stable SHA-256 digest of semantic snapshot
/// identity. Repository origins are never used directly as filesystem path
/// components and Swift's process-randomized Hasher is deliberately avoided.
public struct DocumentationSnapshotStore:
    Sendable
{
    public let root: URL

    public init(
        root: URL
    ) {
        self.root = root
    }

    public func contains(
        _ identity: DocumentationSnapshotIdentity
    ) -> Bool {
        FileManager.default.fileExists(
            atPath: fileURL(
                for: identity
            ).path
        )
    }

    public func load(
        _ identity: DocumentationSnapshotIdentity
    ) throws -> DocumentationSnapshot? {
        let url = fileURL(
            for: identity
        )

        guard
            FileManager.default.fileExists(
                atPath: url.path
            )
        else {
            return nil
        }

        let data = try Data(
            contentsOf: url
        )

        let snapshot = try DocumentationSnapshotCodec.decode(
            data
        )

        guard snapshot.identity == identity else {
            throw DocumentationSnapshotStorageError.snapshotIdentityMismatch
        }

        return snapshot
    }

    /// Loads every persisted immutable snapshot in deterministic file order.
    ///
    /// Corrupt or unsupported cache entries are surfaced to the caller rather
    /// than silently omitted. Repository refresh may still regenerate an
    /// individual disposable entry when that specific identity is requested.
    public func snapshots() throws -> [DocumentationSnapshot] {
        guard FileManager.default.fileExists(
            atPath: snapshotDirectory.path
        ) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: snapshotDirectory,
            includingPropertiesForKeys: nil,
            options: [
                .skipsHiddenFiles,
            ]
        )
            .filter {
                $0.pathExtension == "json"
            }
            .sorted {
                $0.lastPathComponent < $1.lastPathComponent
            }

        return try urls.map { url in
            try DocumentationSnapshotCodec.decode(
                Data(
                    contentsOf: url
                )
            )
        }
    }

    public func catalog() throws -> DocumentationCatalog {
        .init(
            snapshots: try snapshots()
        )
    }

    public func save(
        _ snapshot: DocumentationSnapshot
    ) throws {
        try FileManager.default.createDirectory(
            at: snapshotDirectory,
            withIntermediateDirectories: true
        )

        let data = try DocumentationSnapshotCodec.encode(
            snapshot
        )

        try data.write(
            to: fileURL(
                for: snapshot.identity
            ),
            options: .atomic
        )
    }

    package func fileURL(
        for identity: DocumentationSnapshotIdentity
    ) -> URL {
        snapshotDirectory
            .appendingPathComponent(
                digest(
                    for: identity
                ) + ".json",
                isDirectory: false
            )
    }

    private var snapshotDirectory: URL {
        root.appendingPathComponent(
            "snapshots",
            isDirectory: true
        )
    }

    private func digest(
        for identity: DocumentationSnapshotIdentity
    ) -> String {
        let source = [
            identity.repositoryOrigin,
            identity.commit,
            identity.toolchain.rawValue,
            String(
                identity.importerVersion.rawValue
            ),
        ]
            .joined(
                separator: "\u{1F}"
            )

        return SHA256
            .hash(
                data: Data(
                    source.utf8
                )
            )
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()
    }
}

private struct DocumentationSnapshotEnvelopeHeader:
    Codable
{
    let storageFormatVersion: Int
}

private struct DocumentationSnapshotEnvelope:
    Codable
{
    let storageFormatVersion: Int
    let importerVersion: Int
    let snapshot: DocumentationSnapshotRecord

    init(
        _ snapshot: DocumentationSnapshot
    ) {
        self.storageFormatVersion =
            DocumentationSnapshotStorageVersion.current.rawValue
        self.importerVersion = snapshot.identity.importerVersion.rawValue
        self.snapshot = .init(
            snapshot
        )
    }
}

private struct DocumentationSnapshotRecord:
    Codable
{
    let identity: DocumentationSnapshotIdentityRecord
    let repository: DocumentationRepositoryRecord
    let revision: DocumentationResolvedRevisionRecord
    let package: DocumentationPackageRecord
    let collection: DocumentationCollectionRecord

    init(
        _ snapshot: DocumentationSnapshot
    ) {
        self.identity = .init(
            snapshot.identity
        )
        self.repository = .init(
            snapshot.repository
        )
        self.revision = .init(
            snapshot.revision
        )
        self.package = .init(
            snapshot.package
        )
        self.collection = .init(
            snapshot.collection
        )
    }

    func semantic() throws -> DocumentationSnapshot {
        let identity = identity.semantic()
        let repository = try repository.semantic()
        let revision = try revision.semantic()

        guard
            identity.repositoryOrigin
                == repository.origin.absoluteString,
            identity.commit == revision.commit
        else {
            throw DocumentationSnapshotStorageError.snapshotIdentityMismatch
        }

        return .init(
            identity: identity,
            repository: repository,
            revision: revision,
            package: package.semantic(),
            collection: try collection.semantic()
        )
    }
}

private struct DocumentationSnapshotIdentityRecord:
    Codable
{
    let repositoryOrigin: String
    let commit: String
    let toolchain: String
    let importerVersion: Int

    init(
        _ identity: DocumentationSnapshotIdentity
    ) {
        self.repositoryOrigin = identity.repositoryOrigin
        self.commit = identity.commit
        self.toolchain = identity.toolchain.rawValue
        self.importerVersion = identity.importerVersion.rawValue
    }

    func semantic() -> DocumentationSnapshotIdentity {
        .init(
            repositoryOrigin: repositoryOrigin,
            commit: commit,
            toolchain: .init(
                rawValue: toolchain
            ),
            importerVersion: .init(
                rawValue: importerVersion
            )
        )
    }
}

private struct DocumentationRepositoryRecord:
    Codable
{
    let origin: String
    let revision: DocumentationRepositoryRevisionRecord

    init(
        _ repository: DocumentationRepository
    ) {
        self.origin = repository.origin.absoluteString
        self.revision = .init(
            repository.revision
        )
    }

    func semantic() throws -> DocumentationRepository {
        guard let origin = URL(
            string: origin
        ) else {
            throw DocumentationSnapshotStorageError
                .invalidRepositoryOrigin(
                    origin
                )
        }

        return .init(
            origin: origin,
            revision: try revision.semantic()
        )
    }
}

private struct DocumentationRepositoryRevisionRecord:
    Codable
{
    let kind: String
    let value: String

    init(
        _ revision: DocumentationRepositoryRevision
    ) {
        switch revision {
        case .branch(let value):
            self.kind = "branch"
            self.value = value

        case .tag(let value):
            self.kind = "tag"
            self.value = value

        case .commit(let value):
            self.kind = "commit"
            self.value = value

        case .reference(let value):
            self.kind = "reference"
            self.value = value
        }
    }

    func semantic() throws -> DocumentationRepositoryRevision {
        switch kind {
        case "branch":
            return .branch(
                value
            )

        case "tag":
            return .tag(
                value
            )

        case "commit":
            return .commit(
                value
            )

        case "reference":
            return .reference(
                value
            )

        default:
            throw DocumentationSnapshotStorageError
                .invalidRepositoryRevisionKind(
                    kind
                )
        }
    }
}

private struct DocumentationResolvedRevisionRecord:
    Codable
{
    let requested: DocumentationRepositoryRevisionRecord
    let commit: String

    init(
        _ revision: DocumentationResolvedRevision
    ) {
        self.requested = .init(
            revision.requested
        )
        self.commit = revision.commit
    }

    func semantic() throws -> DocumentationResolvedRevision {
        .init(
            requested: try requested.semantic(),
            commit: commit
        )
    }
}

private struct DocumentationPackageRecord:
    Codable
{
    let name: String
    let toolsVersion: String?
    let products: [DocumentationProductRecord]
    let targets: [DocumentationTargetRecord]
    let modules: [DocumentationModuleRecord]

    init(
        _ package: DocumentationPackage
    ) {
        self.name = package.name
        self.toolsVersion = package.toolsVersion
        self.products = package.products.map {
            .init(
                $0
            )
        }
        self.targets = package.targets.map {
            .init(
                $0
            )
        }
        self.modules = package.modules.map {
            .init(
                $0
            )
        }
    }

    func semantic() -> DocumentationPackage {
        .init(
            name: name,
            toolsVersion: toolsVersion,
            products: products.map {
                $0.semantic()
            },
            targets: targets.map {
                $0.semantic()
            },
            modules: modules.map {
                $0.semantic()
            }
        )
    }
}

private struct DocumentationProductRecord:
    Codable
{
    let name: String
    let kind: String
    let targets: [String]

    init(
        _ product: DocumentationProduct
    ) {
        self.name = product.name
        self.kind = product.kind.rawValue
        self.targets = product.targets.map(
            \.rawValue
        )
    }

    func semantic() -> DocumentationProduct {
        .init(
            name: name,
            kind: .init(
                rawValue: kind
            ),
            targets: targets.map {
                .init(
                    rawValue: $0
                )
            }
        )
    }
}

private struct DocumentationTargetRecord:
    Codable
{
    let identity: String
    let name: String
    let type: String
    let path: String?
    let module: String?

    init(
        _ target: DocumentationTarget
    ) {
        self.identity = target.identity.rawValue
        self.name = target.name
        self.type = target.type
        self.path = target.path
        self.module = target.module?.rawValue
    }

    func semantic() -> DocumentationTarget {
        .init(
            identity: .init(
                rawValue: identity
            ),
            name: name,
            type: type,
            path: path,
            module: module.map {
                .init(
                    rawValue: $0
                )
            }
        )
    }
}

private struct DocumentationModuleRecord:
    Codable
{
    let identity: String
    let name: String

    init(
        _ module: DocumentationModule
    ) {
        self.identity = module.identity.rawValue
        self.name = module.name
    }

    func semantic() -> DocumentationModule {
        .init(
            identity: .init(
                rawValue: identity
            ),
            name: name
        )
    }
}

private struct DocumentationCollectionRecord:
    Codable
{
    let identity: String
    let title: String
    let content: DocumentationContentRecord
    let symbols: [DocumentationSymbolRecord]
    let relationships: [DocumentationRelationshipRecord]

    init(
        _ collection: DocumentationCollection
    ) {
        self.identity = collection.identity.rawValue
        self.title = collection.title
        self.content = .init(
            collection.content
        )
        self.symbols = collection.symbols.map {
            .init(
                $0
            )
        }
        self.relationships = collection.relationships.map {
            .init(
                $0
            )
        }
    }

    func semantic() throws -> DocumentationCollection {
        .init(
            identity: .init(
                rawValue: identity
            ),
            title: title,
            content: try content.semantic(),
            symbols: try symbols.map {
                try $0.semantic()
            },
            relationships: try relationships.map {
                try $0.semantic()
            }
        )
    }
}

private struct DocumentationContentRecord:
    Codable
{
    let authoredMarkup: String?
    let structuredContent: DocumentationStructuredContentRecord

    init(
        _ content: DocumentationContent
    ) {
        self.authoredMarkup = content.authoredMarkup
        self.structuredContent = .init(
            content.structuredContent
        )
    }

    func semantic() throws -> DocumentationContent {
        .init(
            authoredMarkup: authoredMarkup,
            structuredContent: try structuredContent.semantic()
        )
    }
}

private struct DocumentationSymbolRecord:
    Codable
{
    let identity: String
    let name: String
    let path: [String]
    let kind: String
    let declaration: DocumentationDeclarationRecord?
    let content: DocumentationContentRecord
    let source: DocumentationSourceReferenceRecord?
    let provenance: String

    init(
        _ symbol: DocumentationSymbol
    ) {
        self.identity = symbol.identity.rawValue
        self.name = symbol.name
        self.path = symbol.path
        self.kind = symbol.kind.rawValue
        self.declaration = symbol.declaration.map {
            .init(
                $0
            )
        }
        self.content = .init(
            symbol.content
        )
        self.source = symbol.source.map {
            .init(
                $0
            )
        }
        self.provenance = symbol.provenance.rawValue
    }

    func semantic() throws -> DocumentationSymbol {
        guard let provenance = DocumentationSymbolProvenance(
            rawValue: provenance
        ) else {
            throw DocumentationSnapshotStorageError
                .invalidSymbolProvenance(
                    provenance
                )
        }

        return .init(
            identity: .init(
                rawValue: identity
            ),
            name: name,
            path: path,
            kind: .init(
                rawValue: kind
            ),
            declaration: try declaration?.semantic(),
            content: try content.semantic(),
            source: source?.semantic(),
            provenance: provenance
        )
    }
}

private struct DocumentationDeclarationRecord:
    Codable
{
    let fragments: [DocumentationDeclarationFragmentRecord]

    init(
        _ declaration: DocumentationDeclaration
    ) {
        self.fragments = declaration.fragments.map {
            .init(
                $0
            )
        }
    }

    func semantic() throws -> DocumentationDeclaration {
        .init(
            fragments: try fragments.map {
                try $0.semantic()
            }
        )
    }
}

private struct DocumentationDeclarationFragmentRecord:
    Codable
{
    let kind: String
    let spelling: String
    let referencedSymbol: String?

    init(
        _ fragment: DocumentationDeclaration.Fragment
    ) {
        self.kind = fragment.kind.rawValue
        self.spelling = fragment.spelling
        self.referencedSymbol = fragment.referencedSymbol?.rawValue
    }

    func semantic() throws -> DocumentationDeclaration.Fragment {
        .init(
            kind: .init(
                rawValue: kind
            ),
            spelling: spelling,
            referencedSymbol: referencedSymbol.map {
                .init(
                    rawValue: $0
                )
            }
        )
    }
}

private struct DocumentationSourceReferenceRecord:
    Codable
{
    let uri: String
    let line: Int?
    let character: Int?

    init(
        _ source: DocumentationSourceReference
    ) {
        self.uri = source.uri
        self.line = source.line
        self.character = source.character
    }

    func semantic() -> DocumentationSourceReference {
        .init(
            uri: uri,
            line: line,
            character: character
        )
    }
}

private struct DocumentationRelationshipRecord:
    Codable
{
    struct SourceOrigin:
        Codable
    {
        let symbol: String
        let displayName: String

        init(
            _ origin: DocumentationRelationship.SourceOrigin
        ) {
            self.symbol = origin.symbol.rawValue
            self.displayName = origin.displayName
        }

        func semantic() -> DocumentationRelationship.SourceOrigin {
            .init(
                symbol: .init(
                    rawValue: symbol
                ),
                displayName: displayName
            )
        }
    }

    let source: String
    let target: String
    let kind: String
    let targetFallback: String?
    let sourceOrigin: SourceOrigin?

    init(
        _ relationship: DocumentationRelationship
    ) {
        self.source = relationship.source.rawValue
        self.target = relationship.target.rawValue
        self.kind = relationship.kind.rawValue
        self.targetFallback = relationship.targetFallback
        self.sourceOrigin = relationship.sourceOrigin.map {
            .init(
                $0
            )
        }
    }

    func semantic() throws -> DocumentationRelationship {
        .init(
            source: .init(
                rawValue: source
            ),
            target: .init(
                rawValue: target
            ),
            kind: .init(
                rawValue: kind
            ),
            targetFallback: targetFallback,
            sourceOrigin: sourceOrigin?.semantic()
        )
    }
}

private struct DocumentationStructuredContentRecord:
    Codable
{
    let kind: String
    let children: [DocumentationStructuredContentRecord]?
    let inline: [DocumentationStructuredContentInlineRecord]?
    let language: String?
    let source: String?
    let listStyle: String?
    let role: String?
    let title: [DocumentationStructuredContentInlineRecord]?

    init(
        kind: String,
        children: [DocumentationStructuredContentRecord]? = nil,
        inline: [DocumentationStructuredContentInlineRecord]? = nil,
        language: String? = nil,
        source: String? = nil,
        listStyle: String? = nil,
        role: String? = nil,
        title: [DocumentationStructuredContentInlineRecord]? = nil
    ) {
        self.kind = kind
        self.children = children
        self.inline = inline
        self.language = language
        self.source = source
        self.listStyle = listStyle
        self.role = role
        self.title = title
    }

    init(
        _ content: StructuredContent
    ) {
        switch content {
        case .collection(let children):
            self.init(
                kind: "collection",
                children: children.map {
                    .init(
                        $0
                    )
                }
            )

        case .paragraph(let inline):
            self.init(
                kind: "paragraph",
                inline: inline.map {
                    .init(
                        $0
                    )
                }
            )

        case .code(let language, let source):
            self.init(
                kind: "code",
                language: language,
                source: source
            )

        case .quote(let content):
            self.init(
                kind: "quote",
                children: [
                    .init(
                        content
                    ),
                ]
            )

        case .list(let style, let items):
            let listStyle: String

            switch style {
            case .unordered:
                listStyle = "unordered"

            case .ordered:
                listStyle = "ordered"
            }

            self.init(
                kind: "list",
                children: items.map {
                    .init(
                        $0
                    )
                },
                listStyle: listStyle
            )

        case .group(let role, let title, let content):
            self.init(
                kind: "group",
                children: [
                    .init(
                        content
                    ),
                ],
                role: role?.rawValue,
                title: title?.map {
                    .init(
                        $0
                    )
                }
            )
        }
    }

    func semantic() throws -> StructuredContent {
        switch kind {
        case "collection":
            return .collection(
                try (children ?? []).map {
                    try $0.semantic()
                }
            )

        case "paragraph":
            return .paragraph(
                try (inline ?? []).map {
                    try $0.semantic()
                }
            )

        case "code":
            guard let source else {
                throw DocumentationSnapshotStorageError
                    .invalidStructuredContentShape(
                        "code requires source"
                    )
            }

            return .code(
                language: language,
                source: source
            )

        case "quote":
            guard
                let children,
                children.count == 1,
                let content = children.first
            else {
                throw DocumentationSnapshotStorageError
                    .invalidStructuredContentShape(
                        "quote requires exactly one child"
                    )
            }

            return .quote(
                try content.semantic()
            )

        case "list":
            guard let listStyle else {
                throw DocumentationSnapshotStorageError
                    .invalidStructuredContentShape(
                        "list requires style"
                    )
            }

            let style: StructuredContent.ListStyle

            switch listStyle {
            case "unordered":
                style = .unordered

            case "ordered":
                style = .ordered

            default:
                throw DocumentationSnapshotStorageError
                    .invalidStructuredContentListStyle(
                        listStyle
                    )
            }

            return .list(
                style: style,
                items: try (children ?? []).map {
                    try $0.semantic()
                }
            )

        case "group":
            guard
                let children,
                children.count == 1,
                let content = children.first
            else {
                throw DocumentationSnapshotStorageError
                    .invalidStructuredContentShape(
                        "group requires exactly one child"
                    )
            }

            return .group(
                role: role.map {
                    StructuredContent.Role(
                        rawValue: $0
                    )
                },
                title: try title?.map {
                    try $0.semantic()
                },
                content: try content.semantic()
            )

        default:
            throw DocumentationSnapshotStorageError
                .invalidStructuredContentKind(
                    kind
                )
        }
    }
}

private struct DocumentationStructuredContentInlineRecord:
    Codable
{
    let kind: String
    let text: String?
    let children: [DocumentationStructuredContentInlineRecord]?

    init(
        kind: String,
        text: String? = nil,
        children: [DocumentationStructuredContentInlineRecord]? = nil
    ) {
        self.kind = kind
        self.text = text
        self.children = children
    }

    init(
        _ inline: StructuredContent.Inline
    ) {
        switch inline {
        case .text(let text):
            self.init(
                kind: "text",
                text: text
            )

        case .code(let text):
            self.init(
                kind: "code",
                text: text
            )

        case .emphasis(let children):
            self.init(
                kind: "emphasis",
                children: children.map {
                    .init(
                        $0
                    )
                }
            )

        case .strong(let children):
            self.init(
                kind: "strong",
                children: children.map {
                    .init(
                        $0
                    )
                }
            )
        }
    }

    func semantic() throws -> StructuredContent.Inline {
        switch kind {
        case "text":
            guard let text else {
                throw DocumentationSnapshotStorageError
                    .invalidStructuredContentShape(
                        "text inline requires text"
                    )
            }

            return .text(
                text
            )

        case "code":
            guard let text else {
                throw DocumentationSnapshotStorageError
                    .invalidStructuredContentShape(
                        "code inline requires text"
                    )
            }

            return .code(
                text
            )

        case "emphasis":
            return .emphasis(
                try (children ?? []).map {
                    try $0.semantic()
                }
            )

        case "strong":
            return .strong(
                try (children ?? []).map {
                    try $0.semantic()
                }
            )

        default:
            throw DocumentationSnapshotStorageError
                .invalidStructuredContentInlineKind(
                    kind
                )
        }
    }
}
