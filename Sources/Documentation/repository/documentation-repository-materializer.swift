import Foundation
import Interfaces

public enum DocumentationRepositoryMaterializer {
    public static func materialize(
        _ repository: DocumentationRepository,
        in storageRoot: URL
    ) async throws -> DocumentationMaterialization {
        let storageRoot = storageRoot.standardizedFileURL

        try FileManager.default.createDirectory(
            at: storageRoot,
            withIntermediateDirectories: true
        )

        let repositoryRoot = storageRoot.appendingPathComponent(
            "repository",
            isDirectory: true
        )

        let checkoutRoot = storageRoot.appendingPathComponent(
            "checkout",
            isDirectory: true
        )

        try await GitRepo.clone(
            repository.origin,
            to: repositoryRoot
        )

        let worktree = try await GitManagerWorktree.create(
            .init(
                repository: repositoryRoot,
                destination: checkoutRoot,
                baseRef: repository.revision.gitReference,
                checkout: .detached
            )
        )

        return .init(
            repository: repository,
            revision: .init(
                requested: repository.revision,
                commit: worktree.baseCommit
            ),
            storageRoot: storageRoot,
            repositoryRoot: repositoryRoot,
            checkoutRoot: checkoutRoot
        )
    }

    public static func withTemporaryMaterialization<Result>(
        _ repository: DocumentationRepository,
        _ body: (DocumentationMaterialization) async throws -> Result
    ) async throws -> Result {
        let storageRoot = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "documentation-repository-\(UUID().uuidString)",
                isDirectory: true
            )

        defer {
            try? FileManager.default.removeItem(
                at: storageRoot
            )
        }

        let materialization = try await materialize(
            repository,
            in: storageRoot
        )

        return try await body(
            materialization
        )
    }
}
