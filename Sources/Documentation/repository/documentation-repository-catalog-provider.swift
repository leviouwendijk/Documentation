import Foundation

/// Refreshes a configured set of repositories into immutable Documentation
/// snapshots and exposes them as one current repository catalog.
///
/// Historical artifacts remain independently available through
/// DocumentationSnapshotStore. This type instead represents the snapshots
/// selected by the repository requests supplied to one refresh operation.
public struct DocumentationRepositoryCatalogProvider:
    Sendable
{
    public let storageRoot: URL

    public init(
        storageRoot: URL
    ) {
        self.storageRoot = storageRoot.standardizedFileURL
    }

    public func refresh(
        _ repositories: [DocumentationRepository],
        toolchain: DocumentationToolchainIdentity,
        importerVersion: DocumentationImporterVersion = .current
    ) async throws -> DocumentationRepositoryCatalog {
        let provider = DocumentationRepositorySnapshotProvider(
            storageRoot: storageRoot
        )

        return try await refresh(
            repositories,
            toolchain: toolchain,
            importerVersion: importerVersion
        ) { repository in
            try await provider.snapshot(
                for: repository,
                toolchain: toolchain,
                importerVersion: importerVersion
            )
        }
    }

    package func refresh(
        _ repositories: [DocumentationRepository],
        toolchain: DocumentationToolchainIdentity,
        importerVersion: DocumentationImporterVersion = .current,
        snapshot: @escaping @Sendable (
            DocumentationRepository
        ) async throws -> DocumentationSnapshot
    ) async throws -> DocumentationRepositoryCatalog {
        var entries: [DocumentationRepositoryCatalogEntry] = []
        entries.reserveCapacity(
            repositories.count
        )

        for repository in repositories {
            let resolved = try await snapshot(
                repository
            )

            entries.append(
                .init(
                    repository: repository,
                    snapshot: resolved
                )
            )
        }

        return .init(
            entries: entries
        )
    }
}
