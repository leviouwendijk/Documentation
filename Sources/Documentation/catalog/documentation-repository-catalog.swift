/// One configured repository request and the immutable Documentation snapshot
/// resolved for that request.
///
/// Multiple entries may intentionally share one semantic snapshot identity when,
/// for example, a branch and an exact commit resolve to the same commit. The
/// entry retains request provenance even when the semantic catalog deduplicates
/// the underlying immutable artifact.
public struct DocumentationRepositoryCatalogEntry:
    Sendable,
    Hashable
{
    public let repository: DocumentationRepository
    public let snapshot: DocumentationSnapshot

    public init(
        repository: DocumentationRepository,
        snapshot: DocumentationSnapshot
    ) {
        self.repository = repository
        self.snapshot = snapshot
    }
}

/// A configured documentation set plus its deduplicated semantic query catalog.
///
/// `entries` preserve configuration order and requested revision provenance.
/// `catalog` contains each immutable semantic snapshot identity at most once so
/// package/module/symbol queries do not duplicate results merely because the
/// same commit was requested through multiple refs.
public struct DocumentationRepositoryCatalog:
    Sendable,
    Hashable
{
    public let entries: [DocumentationRepositoryCatalogEntry]
    public let catalog: DocumentationCatalog

    public init(
        entries: [DocumentationRepositoryCatalogEntry]
    ) {
        self.entries = entries

        var identities = Set<DocumentationSnapshotIdentity>()

        let snapshots = entries.compactMap { entry in
            identities.insert(
                entry.snapshot.identity
            ).inserted
                ? entry.snapshot
                : nil
        }

        self.catalog = DocumentationCatalog(
            snapshots: snapshots
        )
    }
}
