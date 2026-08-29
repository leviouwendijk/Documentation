import Foundation

public enum DocumentationRepositoryRevision:
    Sendable,
    Hashable
{
    case branch(String)
    case tag(String)
    case commit(String)
    case reference(String)
}

public struct DocumentationRepository:
    Sendable,
    Hashable
{
    public let origin: URL
    public let revision: DocumentationRepositoryRevision

    public init(
        origin: URL,
        revision: DocumentationRepositoryRevision
    ) {
        self.origin = origin
        self.revision = revision
    }
}

public struct DocumentationResolvedRevision:
    Sendable,
    Hashable
{
    public let requested: DocumentationRepositoryRevision
    public let commit: String

    public init(
        requested: DocumentationRepositoryRevision,
        commit: String
    ) {
        self.requested = requested
        self.commit = commit
    }
}

public struct DocumentationMaterialization:
    Sendable,
    Hashable
{
    public let repository: DocumentationRepository
    public let revision: DocumentationResolvedRevision
    public let storageRoot: URL
    public let repositoryRoot: URL
    public let checkoutRoot: URL

    public init(
        repository: DocumentationRepository,
        revision: DocumentationResolvedRevision,
        storageRoot: URL,
        repositoryRoot: URL,
        checkoutRoot: URL
    ) {
        self.repository = repository
        self.revision = revision
        self.storageRoot = storageRoot.standardizedFileURL
        self.repositoryRoot = repositoryRoot.standardizedFileURL
        self.checkoutRoot = checkoutRoot.standardizedFileURL
    }
}

extension DocumentationRepositoryRevision {
    var gitReference: String {
        switch self {
        case .branch(let name):
            "refs/remotes/origin/\(name)"

        case .tag(let name):
            "refs/tags/\(name)"

        case .commit(let commit):
            commit

        case .reference(let reference):
            reference
        }
    }
}
