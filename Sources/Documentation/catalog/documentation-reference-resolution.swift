public enum DocumentationCatalogReferenceKind:
    Sendable,
    Hashable
{
    /// A precise symbol identity carried by one declaration fragment.
    case declarationFragment(index: Int)

    /// A semantic API relationship carried by DocumentationCollection.
    case relationship(kind: DocumentationRelationshipKind)
}

/// Result of resolving one precise Documentation symbol identity in the
/// context of a source snapshot.
///
/// Resolution deliberately does not invent recency or dependency-version
/// policy. A same-snapshot occurrence wins because it is part of the exact
/// immutable semantic artifact being queried. Otherwise exactly one external
/// occurrence can resolve; multiple external occurrences remain ambiguous.
public enum DocumentationCatalogReferenceResolution:
    Sendable,
    Hashable
{
    case resolved(DocumentationCatalogSymbol)
    case ambiguous([DocumentationCatalogSymbol])
    case unresolved(DocumentationSymbolIdentity)

    public var resolvedSymbol: DocumentationCatalogSymbol? {
        guard case .resolved(let symbol) = self else {
            return nil
        }

        return symbol
    }

    public var candidates: [DocumentationCatalogSymbol] {
        switch self {
        case .resolved(let symbol):
            return [
                symbol,
            ]

        case .ambiguous(let symbols):
            return symbols

        case .unresolved:
            return []
        }
    }
}

/// One outbound semantic reference from a symbol occurrence in a catalog.
///
/// This is a query projection rather than persisted snapshot data. It contains
/// semantic identities and snapshot context only; no href, filesystem route,
/// or presentation address is introduced here.
public struct DocumentationCatalogReference:
    Sendable,
    Hashable
{
    public let source: DocumentationCatalogSymbol
    public let kind: DocumentationCatalogReferenceKind
    public let targetIdentity: DocumentationSymbolIdentity
    public let resolution: DocumentationCatalogReferenceResolution

    public init(
        source: DocumentationCatalogSymbol,
        kind: DocumentationCatalogReferenceKind,
        targetIdentity: DocumentationSymbolIdentity,
        resolution: DocumentationCatalogReferenceResolution
    ) {
        self.source = source
        self.kind = kind
        self.targetIdentity = targetIdentity
        self.resolution = resolution
    }
}

extension DocumentationCatalog {
    /// Resolve a precise symbol identity relative to one immutable source
    /// snapshot.
    ///
    /// Resolution order:
    /// 1. occurrence in the exact source snapshot;
    /// 2. exactly one occurrence elsewhere in the catalog;
    /// 3. explicit ambiguity when multiple external occurrences exist;
    /// 4. unresolved identity when no occurrence exists.
    public func resolveSymbol(
        _ identity: DocumentationSymbolIdentity,
        from snapshotIdentity: DocumentationSnapshotIdentity
    ) -> DocumentationCatalogReferenceResolution {
        let occurrences = symbols(
            identity: identity
        )

        let local = occurrences.filter {
            $0.snapshotIdentity == snapshotIdentity
        }

        if local.count == 1,
           let symbol = local.first
        {
            return .resolved(
                symbol
            )
        }

        if local.count > 1 {
            return .ambiguous(
                local
            )
        }

        let external = occurrences.filter {
            $0.snapshotIdentity != snapshotIdentity
        }

        if external.count == 1,
           let symbol = external.first
        {
            return .resolved(
                symbol
            )
        }

        if external.count > 1 {
            return .ambiguous(
                external
            )
        }

        return .unresolved(
            identity
        )
    }

    /// Project every precise outbound declaration and relationship reference
    /// carried by one symbol occurrence and resolve each against the wider
    /// catalog.
    ///
    /// Declaration fragment order and collection relationship order are
    /// preserved. Repeated identities are retained because separate reference
    /// occurrences can carry different semantic meaning.
    public func references(
        from sourceIdentity: DocumentationSymbolIdentity,
        in snapshotIdentity: DocumentationSnapshotIdentity
    ) -> [DocumentationCatalogReference] {
        guard
            let snapshot = snapshot(
                snapshotIdentity
            ),
            let sourceSymbol = snapshot.collection.symbols.first(
                where: {
                    $0.identity == sourceIdentity
                }
            )
        else {
            return []
        }

        let source = DocumentationCatalogSymbol(
            snapshotIdentity: snapshot.identity,
            packageName: snapshot.package.name,
            symbol: sourceSymbol
        )

        var references: [DocumentationCatalogReference] = []

        if let declaration = sourceSymbol.declaration {
            for (index, fragment) in declaration.fragments.enumerated() {
                guard let target = fragment.referencedSymbol else {
                    continue
                }

                references.append(
                    .init(
                        source: source,
                        kind: .declarationFragment(
                            index: index
                        ),
                        targetIdentity: target,
                        resolution: resolveSymbol(
                            target,
                            from: snapshotIdentity
                        )
                    )
                )
            }
        }

        for relationship in snapshot.collection.relationships
            where relationship.source == sourceIdentity
        {
            references.append(
                .init(
                    source: source,
                    kind: .relationship(
                        kind: relationship.kind
                    ),
                    targetIdentity: relationship.target,
                    resolution: resolveSymbol(
                        relationship.target,
                        from: snapshotIdentity
                    )
                )
            )
        }

        return references
    }
}
