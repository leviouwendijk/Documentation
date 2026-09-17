import CryptoKit
import Foundation
import Interfaces

public enum DocumentationRepositorySnapshotError:
    Error,
    Equatable
{
    case repositoryRefreshFailed(String)
    case requestedRevisionFetchFailed(String)
    case derivedSnapshotIdentityMismatch
}

/// Resolves repositories into immutable semantic Documentation snapshots while
/// retaining reusable Git object state and persisted derived snapshots.
///
/// A refresh always resolves the requested revision to an immutable commit
/// before consulting snapshot storage. Cache hits therefore avoid checkout,
/// package inspection, compiler symbol-graph generation, and normalization.
public struct DocumentationRepositorySnapshotProvider:
    Sendable
{
    public let storageRoot: URL

    public init(
        storageRoot: URL
    ) {
        self.storageRoot = storageRoot.standardizedFileURL
    }

    public func snapshot(
        for repository: DocumentationRepository,
        toolchain: DocumentationToolchainIdentity,
        importerVersion: DocumentationImporterVersion = .current
    ) async throws -> DocumentationSnapshot {
        try await snapshot(
            for: repository,
            toolchain: toolchain,
            importerVersion: importerVersion
        ) { materialization in
            let inspection = try await DocumentationRepositoryInspector.inspect(
                materialization
            )

            return try DocumentationRepositoryDeriver.derive(
                inspection,
                from: materialization,
                toolchain: toolchain,
                importerVersion: importerVersion
            )
        }
    }

    package func snapshot(
        for repository: DocumentationRepository,
        toolchain: DocumentationToolchainIdentity,
        importerVersion: DocumentationImporterVersion = .current,
        derive: @escaping @Sendable (
            DocumentationMaterialization
        ) async throws -> DocumentationSnapshot
    ) async throws -> DocumentationSnapshot {
        let retainedRepository = try await retainedRepository(
            for: repository
        )

        let commit = try await resolvedCommit(
            for: repository,
            at: retainedRepository.root,
            repositoryWasCreated: retainedRepository.wasCreated
        )

        let revision = DocumentationResolvedRevision(
            requested: repository.revision,
            commit: commit
        )

        let identity = DocumentationSnapshotIdentity(
            repository: repository,
            revision: revision,
            toolchain: toolchain,
            importerVersion: importerVersion
        )

        let store = DocumentationSnapshotStore(
            root: storageRoot
        )

        if let cached = try cachedSnapshot(
            identity,
            from: store
        ) {
            return snapshot(
                cached,
                rebindingTo: repository,
                revision: revision
            )
        }

        let checkoutRoot = checkoutsRoot
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: checkoutsRoot,
            withIntermediateDirectories: true
        )

        let worktree = try await GitManagerWorktree.create(
            .init(
                repository: retainedRepository.root,
                destination: checkoutRoot,
                baseRef: commit,
                checkout: .detached
            )
        )

        let materialization = DocumentationMaterialization(
            repository: repository,
            revision: .init(
                requested: repository.revision,
                commit: worktree.baseCommit
            ),
            storageRoot: storageRoot,
            repositoryRoot: retainedRepository.root,
            checkoutRoot: checkoutRoot
        )

        let derived: DocumentationSnapshot

        do {
            derived = try await derive(
                materialization
            )
        } catch {
            try? await GitManagerWorktree.remove(
                checkoutRoot,
                at: retainedRepository.root,
                force: true
            )

            throw error
        }

        do {
            try await GitManagerWorktree.remove(
                checkoutRoot,
                at: retainedRepository.root,
                force: true
            )
        } catch {
            throw error
        }

        guard derived.identity == identity else {
            throw DocumentationRepositorySnapshotError
                .derivedSnapshotIdentityMismatch
        }

        let snapshot = snapshot(
            derived,
            rebindingTo: repository,
            revision: revision
        )

        try store.save(
            snapshot
        )

        return snapshot
    }

    package func repositoryRoot(
        for repository: DocumentationRepository
    ) -> URL {
        repositoriesRoot
            .appendingPathComponent(
                repositoryKey(
                    repository.origin
                ),
                isDirectory: true
            )
            .appendingPathComponent(
                "repository",
                isDirectory: true
            )
    }

    private var repositoriesRoot: URL {
        storageRoot.appendingPathComponent(
            "repositories",
            isDirectory: true
        )
    }

    private var checkoutsRoot: URL {
        storageRoot.appendingPathComponent(
            "checkouts",
            isDirectory: true
        )
    }

    private func retainedRepository(
        for repository: DocumentationRepository
    ) async throws -> (
        root: URL,
        wasCreated: Bool
    ) {
        let repositoryRoot = repositoryRoot(
            for: repository
        )

        if FileManager.default.fileExists(
            atPath: repositoryRoot.path
        ) {
            return (
                repositoryRoot,
                false
            )
        }

        try FileManager.default.createDirectory(
            at: repositoryRoot.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try await GitRepo.clone(
            repository.origin,
            to: repositoryRoot
        )

        return (
            repositoryRoot,
            true
        )
    }

    private func resolvedCommit(
        for repository: DocumentationRepository,
        at repositoryRoot: URL,
        repositoryWasCreated: Bool
    ) async throws -> String {
        if
            case .commit = repository.revision,
            !repositoryWasCreated,
            let existing = try? await GitRepo.resolveCommit(
                repository.revision.gitReference,
                at: repositoryRoot
            )
        {
            return existing
        }

        if !repositoryWasCreated {
            try await refreshRetainedRepository(
                repositoryRoot
            )
        }

        do {
            return try await GitRepo.resolveCommit(
                repository.revision.gitReference,
                at: repositoryRoot
            )
        } catch {
            switch repository.revision {
            case .commit(let reference),
                 .reference(let reference):
                return try await fetchAndResolveRequestedReference(
                    reference,
                    at: repositoryRoot
                )

            case .branch,
                 .tag:
                throw error
            }
        }
    }

    /// Refresh every ordinary remote branch plus tags in the retained clone.
    ///
    /// Interfaces currently exposes GitRepo.git as the generic repository
    /// substrate; keeping the refspec here makes repository acquisition policy
    /// a Documentation concern without introducing AgenticGit or launching a
    /// process directly from Documentation.
    private func refreshRetainedRepository(
        _ repositoryRoot: URL
    ) async throws {
        let result = try await GitRepo.git(
            repositoryRoot,
            [
                "fetch",
                "--prune",
                "--tags",
                "origin",
                "+refs/heads/*:refs/remotes/origin/*",
            ]
        )

        guard result.code == 0 else {
            throw DocumentationRepositorySnapshotError
                .repositoryRefreshFailed(
                    result.err
                )
        }
    }

    private func fetchAndResolveRequestedReference(
        _ reference: String,
        at repositoryRoot: URL
    ) async throws -> String {
        let result = try await GitRepo.git(
            repositoryRoot,
            [
                "fetch",
                "--tags",
                "origin",
                reference,
            ]
        )

        guard result.code == 0 else {
            throw DocumentationRepositorySnapshotError
                .requestedRevisionFetchFailed(
                    result.err
                )
        }

        return try await GitRepo.resolveCommit(
            "FETCH_HEAD",
            at: repositoryRoot
        )
    }

    private func cachedSnapshot(
        _ identity: DocumentationSnapshotIdentity,
        from store: DocumentationSnapshotStore
    ) throws -> DocumentationSnapshot? {
        do {
            return try store.load(
                identity
            )
        } catch is DecodingError {
            return nil
        } catch is DocumentationSnapshotStorageError {
            return nil
        }
    }

    private func snapshot(
        _ snapshot: DocumentationSnapshot,
        rebindingTo repository: DocumentationRepository,
        revision: DocumentationResolvedRevision
    ) -> DocumentationSnapshot {
        .init(
            identity: snapshot.identity,
            repository: repository,
            revision: revision,
            package: snapshot.package,
            collection: snapshot.collection
        )
    }

    private func repositoryKey(
        _ origin: URL
    ) -> String {
        SHA256
            .hash(
                data: Data(
                    origin.absoluteString.utf8
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
