import Documentation
import Foundation
import Interfaces
import TestFlows

extension DocumentationFlowSuite {
    static var documentationRepositorySnapshotFlow: TestFlow {
        TestFlow(
            "documentation-repository-snapshot",
            tags: [
                "documentation",
                "repository",
                "snapshot",
                "incremental",
                "local",
            ]
        ) {
            Step("retained repository refresh reuses immutable snapshots") {
                let fixture = try DocumentationRepositorySnapshotFixture()

                defer {
                    fixture.remove()
                }

                let commitA = try await fixture.initialize()

                let repository = DocumentationRepository(
                    origin: fixture.source,
                    revision: .branch(
                        "master"
                    )
                )

                let provider = DocumentationRepositorySnapshotProvider(
                    storageRoot: fixture.cache
                )

                let store = DocumentationSnapshotStore(
                    root: fixture.cache
                )

                let toolchain = DocumentationToolchainIdentity(
                    rawValue: "swift-retained-fixture"
                )

                let counter = DocumentationRepositorySnapshotDerivationCounter()

                let derive: @Sendable (
                    DocumentationMaterialization
                ) async throws -> DocumentationSnapshot = { materialization in
                    await counter.increment()

                    let identity = DocumentationSnapshotIdentity(
                        repository: materialization.repository,
                        revision: materialization.revision,
                        toolchain: toolchain
                    )

                    return .init(
                        identity: identity,
                        repository: materialization.repository,
                        revision: materialization.revision,
                        package: .init(
                            name: "Fixture"
                        ),
                        collection: .init(
                            identity: .init(
                                rawValue:
                                    materialization.repository.origin.absoluteString
                                    + "#"
                                    + materialization.revision.commit
                            ),
                            title:
                                "Fixture "
                                + String(
                                    materialization.revision.commit.prefix(
                                        12
                                    )
                                )
                        )
                    )
                }

                let snapshotA = try await provider.snapshot(
                    for: repository,
                    toolchain: toolchain,
                    derive: derive
                )

                try Expect.equal(
                    snapshotA.revision.commit,
                    commitA,
                    "first refresh resolves source branch to immutable commit A"
                )

                try Expect.equal(
                    await counter.value(),
                    1,
                    "first uncached revision enters semantic derivation once"
                )

                let retainedRepositoryRoot = provider.repositoryRoot(
                    for: repository
                )

                try Expect.true(
                    FileManager.default.fileExists(
                        atPath: retainedRepositoryRoot.path
                    ),
                    "repository object state remains retained after derivation"
                )

                try Expect.equal(
                    try await GitManagerWorktree.list(
                        at: retainedRepositoryRoot
                    ).count,
                    1,
                    "derived checkout is removed after snapshot creation"
                )

                let repeatedA = try await provider.snapshot(
                    for: repository,
                    toolchain: toolchain,
                    derive: derive
                )

                try Expect.equal(
                    repeatedA,
                    snapshotA,
                    "unchanged branch reuses persisted semantic snapshot"
                )

                try Expect.equal(
                    await counter.value(),
                    1,
                    "snapshot cache hit never enters semantic derivation"
                )

                try Expect.equal(
                    try await GitManagerWorktree.list(
                        at: retainedRepositoryRoot
                    ).count,
                    1,
                    "snapshot cache hit creates no disposable checkout"
                )

                let commitB = try await fixture.commit(
                    "revision-b",
                    message: "revision B"
                )

                let snapshotB = try await provider.snapshot(
                    for: repository,
                    toolchain: toolchain,
                    derive: derive
                )

                try Expect.equal(
                    snapshotB.revision.commit,
                    commitB,
                    "refresh observes branch advancement to commit B"
                )

                try Expect.true(
                    snapshotB.identity != snapshotA.identity,
                    "new immutable commit produces a distinct snapshot identity"
                )

                try Expect.equal(
                    await counter.value(),
                    2,
                    "new immutable revision derives exactly once"
                )

                try Expect.equal(
                    try store.load(
                        snapshotA.identity
                    ),
                    Optional(
                        snapshotA
                    ),
                    "older immutable snapshot remains independently retained"
                )

                try Expect.equal(
                    try store.load(
                        snapshotB.identity
                    ),
                    Optional(
                        snapshotB
                    ),
                    "new immutable snapshot is persisted independently"
                )

                let exactARepository = DocumentationRepository(
                    origin: fixture.source,
                    revision: .commit(
                        commitA
                    )
                )

                let exactA = try await provider.snapshot(
                    for: exactARepository,
                    toolchain: toolchain,
                    derive: derive
                )

                try Expect.equal(
                    exactA.identity,
                    snapshotA.identity,
                    "exact commit request shares the semantic identity already cached for branch A"
                )

                try Expect.equal(
                    exactA.repository.revision,
                    DocumentationRepositoryRevision.commit(
                        commitA
                    ),
                    "cache reuse rebinds repository provenance to the current request"
                )

                try Expect.equal(
                    exactA.revision.requested,
                    DocumentationRepositoryRevision.commit(
                        commitA
                    ),
                    "cache reuse preserves current requested revision provenance"
                )

                try Expect.equal(
                    exactA.collection,
                    snapshotA.collection,
                    "provenance rebinding does not alter shared semantic content"
                )

                try Expect.equal(
                    await counter.value(),
                    2,
                    "exact commit cache reuse does not derive again"
                )

                try Data(
                    "corrupt-cache".utf8
                )
                    .write(
                        to: store.fileURL(
                            for: snapshotA.identity
                        ),
                        options: .atomic
                    )

                let regeneratedA = try await provider.snapshot(
                    for: exactARepository,
                    toolchain: toolchain,
                    derive: derive
                )

                try Expect.equal(
                    regeneratedA.identity,
                    snapshotA.identity,
                    "corrupt disposable cache regenerates the same semantic identity"
                )

                try Expect.equal(
                    await counter.value(),
                    3,
                    "corrupt cache enters derivation rather than returning invalid content"
                )

                let commitC = try await fixture.commit(
                    "revision-c",
                    message: "revision C"
                )

                let revisionC = DocumentationResolvedRevision(
                    requested: repository.revision,
                    commit: commitC
                )

                let identityC = DocumentationSnapshotIdentity(
                    repository: repository,
                    revision: revisionC,
                    toolchain: toolchain
                )

                var derivationFailed = false

                do {
                    _ = try await provider.snapshot(
                        for: repository,
                        toolchain: toolchain
                    ) { _ in
                        throw DocumentationRepositorySnapshotFlowError
                            .forcedDerivationFailure
                    }
                } catch DocumentationRepositorySnapshotFlowError
                    .forcedDerivationFailure
                {
                    derivationFailed = true
                }

                try Expect.true(
                    derivationFailed,
                    "derivation failure propagates to the caller"
                )

                try Expect.equal(
                    store.contains(
                        identityC
                    ),
                    false,
                    "failed derivation never publishes a snapshot"
                )

                try Expect.equal(
                    try await GitManagerWorktree.list(
                        at: retainedRepositoryRoot
                    ).count,
                    1,
                    "failed derivation still removes its disposable checkout"
                )

                try Expect.equal(
                    try store.load(
                        snapshotB.identity
                    ),
                    Optional(
                        snapshotB
                    ),
                    "failed refresh does not invalidate older valid snapshots"
                )
            }
        }
    }
}

private actor DocumentationRepositorySnapshotDerivationCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private struct DocumentationRepositorySnapshotFixture {
    let root: URL
    let source: URL
    let cache: URL

    init() throws {
        root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "documentation-retained-refresh-\(UUID().uuidString)",
                isDirectory: true
            )

        source = root.appendingPathComponent(
            "source",
            isDirectory: true
        )

        cache = root.appendingPathComponent(
            "cache",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
    }

    func initialize() async throws -> String {
        try await git(
            [
                "init",
                "--initial-branch=master",
            ]
        )

        try await git(
            [
                "config",
                "user.name",
                "Documentation Fixture",
            ]
        )

        try await git(
            [
                "config",
                "user.email",
                "documentation-fixture@example.invalid",
            ]
        )

        try await git(
            [
                "config",
                "commit.gpgsign",
                "false",
            ]
        )

        return try await commit(
            "revision-a",
            message: "revision A"
        )
    }

    func commit(
        _ value: String,
        message: String
    ) async throws -> String {
        try Data(
            (value + "\n").utf8
        )
            .write(
                to: source.appendingPathComponent(
                    "revision.txt",
                    isDirectory: false
                ),
                options: .atomic
            )

        try await git(
            [
                "add",
                "revision.txt",
            ]
        )

        try await git(
            [
                "commit",
                "-m",
                message,
            ]
        )

        return try await GitRepo.resolveCommit(
            "HEAD",
            at: source
        )
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }

    private func git(
        _ arguments: [String]
    ) async throws {
        let result = try await GitRepo.git(
            source,
            arguments
        )

        guard result.code == 0 else {
            throw DocumentationRepositorySnapshotFlowError
                .gitFailed(
                    result.err
                )
        }
    }
}

private enum DocumentationRepositorySnapshotFlowError:
    Error
{
    case gitFailed(String)
    case forcedDerivationFailure
}
