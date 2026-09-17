import Foundation

/// Identity of the Swift toolchain used to produce documentation semantics.
///
/// Documentation deliberately accepts this value from the acquisition/build
/// boundary rather than discovering a toolchain by launching processes itself.
public struct DocumentationToolchainIdentity:
    RawRepresentable,
    Sendable,
    Hashable
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

/// Semantic generation of the Documentation importer.
///
/// Changing normalization behavior should advance this value so an existing
/// derived snapshot can be treated as stale without coupling cache identity to
/// package versions or Git history.
public struct DocumentationImporterVersion:
    RawRepresentable,
    Sendable,
    Hashable
{
    public static let current = Self(
        rawValue: 3
    )

    public let rawValue: Int

    public init(
        rawValue: Int
    ) {
        self.rawValue = rawValue
    }
}

/// Deterministic semantic identity of one derived Documentation artifact.
///
/// Requested branch, tag, or reference names are intentionally excluded.
/// Multiple requests that resolve to the same repository origin, immutable
/// commit, toolchain, and importer version therefore identify the same
/// semantic artifact.
public struct DocumentationSnapshotIdentity:
    Sendable,
    Hashable
{
    public let repositoryOrigin: String
    public let commit: String
    public let toolchain: DocumentationToolchainIdentity
    public let importerVersion: DocumentationImporterVersion

    public init(
        repositoryOrigin: String,
        commit: String,
        toolchain: DocumentationToolchainIdentity,
        importerVersion: DocumentationImporterVersion = .current
    ) {
        self.repositoryOrigin = repositoryOrigin
        self.commit = commit
        self.toolchain = toolchain
        self.importerVersion = importerVersion
    }

    public init(
        repository: DocumentationRepository,
        revision: DocumentationResolvedRevision,
        toolchain: DocumentationToolchainIdentity,
        importerVersion: DocumentationImporterVersion = .current
    ) {
        self.init(
            repositoryOrigin: repository.origin.absoluteString,
            commit: revision.commit,
            toolchain: toolchain,
            importerVersion: importerVersion
        )
    }
}

/// Renderer-neutral Documentation artifact for one immutable repository state.
///
/// Repository and revision retain acquisition provenance, including the
/// originally requested branch, tag, commit, or reference. Filesystem checkout
/// and cache paths are deliberately absent from the snapshot.
public struct DocumentationSnapshot:
    Sendable,
    Hashable
{
    public let identity: DocumentationSnapshotIdentity
    public let repository: DocumentationRepository
    public let revision: DocumentationResolvedRevision
    public let package: DocumentationPackage
    public let collection: DocumentationCollection

    public init(
        identity: DocumentationSnapshotIdentity,
        repository: DocumentationRepository,
        revision: DocumentationResolvedRevision,
        package: DocumentationPackage,
        collection: DocumentationCollection
    ) {
        self.identity = identity
        self.repository = repository
        self.revision = revision
        self.package = package
        self.collection = collection
    }
}
