import Foundation

/// One package occurrence inside a Documentation catalog.
///
/// The snapshot identity disambiguates equal package names across repositories
/// and immutable revisions without introducing presentation URLs or routes.
public struct DocumentationCatalogPackage:
    Sendable,
    Hashable
{
    public let snapshotIdentity: DocumentationSnapshotIdentity
    public let package: DocumentationPackage

    public init(
        snapshotIdentity: DocumentationSnapshotIdentity,
        package: DocumentationPackage
    ) {
        self.snapshotIdentity = snapshotIdentity
        self.package = package
    }
}

/// One compiler module occurrence inside a Documentation catalog.
public struct DocumentationCatalogModule:
    Sendable,
    Hashable
{
    public let snapshotIdentity: DocumentationSnapshotIdentity
    public let packageName: String
    public let module: DocumentationModule

    public init(
        snapshotIdentity: DocumentationSnapshotIdentity,
        packageName: String,
        module: DocumentationModule
    ) {
        self.snapshotIdentity = snapshotIdentity
        self.packageName = packageName
        self.module = module
    }
}

/// One symbol occurrence inside a Documentation catalog.
///
/// Symbol identities may legitimately recur across immutable revisions. The
/// containing snapshot identity therefore remains part of every catalog result.
public struct DocumentationCatalogSymbol:
    Sendable,
    Hashable
{
    public let snapshotIdentity: DocumentationSnapshotIdentity
    public let packageName: String
    public let symbol: DocumentationSymbol

    public init(
        snapshotIdentity: DocumentationSnapshotIdentity,
        packageName: String,
        symbol: DocumentationSymbol
    ) {
        self.snapshotIdentity = snapshotIdentity
        self.packageName = packageName
        self.symbol = symbol
    }
}

/// Renderer-neutral query surface over one or more immutable Documentation
/// snapshots.
///
/// This intentionally remains a plain library model. Agentic, terminal, web,
/// and other consumers can project these semantics without becoming the owner
/// of documentation lookup rules.
public struct DocumentationCatalog:
    Sendable,
    Hashable
{
    public let snapshots: [DocumentationSnapshot]

    public init(
        snapshots: [DocumentationSnapshot]
    ) {
        self.snapshots = snapshots.sorted(
            by: Self.snapshotPrecedes
        )
    }

    public func snapshot(
        _ identity: DocumentationSnapshotIdentity
    ) -> DocumentationSnapshot? {
        snapshots.first {
            $0.identity == identity
        }
    }

    public func snapshots(
        repositoryOrigin: String
    ) -> [DocumentationSnapshot] {
        snapshots.filter {
            $0.identity.repositoryOrigin == repositoryOrigin
        }
    }

    public func packages(
        named name: String? = nil
    ) -> [DocumentationCatalogPackage] {
        snapshots.compactMap { snapshot in
            if let name,
               snapshot.package.name != name
            {
                return nil
            }

            return .init(
                snapshotIdentity: snapshot.identity,
                package: snapshot.package
            )
        }
    }

    public func modules(
        named name: String? = nil
    ) -> [DocumentationCatalogModule] {
        snapshots
            .flatMap { snapshot in
                snapshot.package.modules.compactMap { module in
                    if let name,
                       module.name != name
                    {
                        return nil
                    }

                    return DocumentationCatalogModule(
                        snapshotIdentity: snapshot.identity,
                        packageName: snapshot.package.name,
                        module: module
                    )
                }
            }
            .sorted(
                by: Self.modulePrecedes
            )
    }

    public func symbols(
        identity: DocumentationSymbolIdentity
    ) -> [DocumentationCatalogSymbol] {
        snapshots
            .flatMap { snapshot in
                snapshot.collection.symbols.compactMap { symbol in
                    guard symbol.identity == identity else {
                        return nil
                    }

                    return DocumentationCatalogSymbol(
                        snapshotIdentity: snapshot.identity,
                        packageName: snapshot.package.name,
                        symbol: symbol
                    )
                }
            }
            .sorted(
                by: Self.symbolPrecedes
            )
    }

    public func symbols(
        named name: String,
        caseSensitive: Bool = true
    ) -> [DocumentationCatalogSymbol] {
        snapshots
            .flatMap { snapshot in
                snapshot.collection.symbols.compactMap { symbol in
                    let matches: Bool

                    if caseSensitive {
                        matches = symbol.name == name
                    } else {
                        matches = symbol.name.caseInsensitiveCompare(name) == .orderedSame
                    }

                    guard matches else {
                        return nil
                    }

                    return DocumentationCatalogSymbol(
                        snapshotIdentity: snapshot.identity,
                        packageName: snapshot.package.name,
                        symbol: symbol
                    )
                }
            }
            .sorted(
                by: Self.symbolPrecedes
            )
    }

    /// Deterministic lightweight symbol discovery over semantic name, path, and
    /// identity fields.
    ///
    /// This is deliberately not a fuzzy-search engine. More sophisticated
    /// ranking can later be projected through the shared Search package without
    /// changing the catalog's semantic result types.
    public func symbols(
        matching query: String,
        maximumResults: Int? = nil
    ) -> [DocumentationCatalogSymbol] {
        let query = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            return []
        }

        let normalizedQuery = query.lowercased()

        let scored: [(
            score: Int,
            result: DocumentationCatalogSymbol
        )] = snapshots.flatMap { snapshot in
            snapshot.collection.symbols.compactMap { symbol in
                guard let score = Self.matchScore(
                    symbol,
                    query: query,
                    normalizedQuery: normalizedQuery
                ) else {
                    return nil
                }

                return (
                    score,
                    DocumentationCatalogSymbol(
                        snapshotIdentity: snapshot.identity,
                        packageName: snapshot.package.name,
                        symbol: symbol
                    )
                )
            }
        }

        let ordered = scored.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score < rhs.score
            }

            return Self.symbolPrecedes(
                lhs.result,
                rhs.result
            )
        }

        guard let maximumResults else {
            return ordered.map(\.result)
        }

        guard maximumResults > 0 else {
            return []
        }

        return Array(
            ordered
                .prefix(maximumResults)
                .map(\.result)
        )
    }

    public func relationships(
        from source: DocumentationSymbolIdentity,
        in snapshotIdentity: DocumentationSnapshotIdentity
    ) -> [DocumentationRelationship] {
        guard let snapshot = snapshot(
            snapshotIdentity
        ) else {
            return []
        }

        return snapshot.collection.relationships.filter {
            $0.source == source
        }
    }

    public func relationships(
        to target: DocumentationSymbolIdentity,
        in snapshotIdentity: DocumentationSnapshotIdentity
    ) -> [DocumentationRelationship] {
        guard let snapshot = snapshot(
            snapshotIdentity
        ) else {
            return []
        }

        return snapshot.collection.relationships.filter {
            $0.target == target
        }
    }

    /// Returns declaration reference identities exactly as carried by semantic
    /// declaration fragments.
    ///
    /// Missing targets are intentionally retained as identities rather than
    /// discarded. A future cross-snapshot resolver can therefore operate on the
    /// same query surface without changing declaration semantics.
    public func referencedSymbolIdentities(
        from source: DocumentationSymbolIdentity,
        in snapshotIdentity: DocumentationSnapshotIdentity
    ) -> [DocumentationSymbolIdentity] {
        guard
            let snapshot = snapshot(
                snapshotIdentity
            ),
            let symbol = snapshot.collection.symbols.first(
                where: {
                    $0.identity == source
                }
            ),
            let declaration = symbol.declaration
        else {
            return []
        }

        return declaration.fragments.compactMap(
            \.referencedSymbol
        )
    }

    private static func matchScore(
        _ symbol: DocumentationSymbol,
        query: String,
        normalizedQuery: String
    ) -> Int? {
        if symbol.name == query {
            return 0
        }

        let normalizedName = symbol.name.lowercased()

        if normalizedName == normalizedQuery {
            return 1
        }

        if normalizedName.hasPrefix(
            normalizedQuery
        ) {
            return 2
        }

        if normalizedName.contains(
            normalizedQuery
        ) {
            return 3
        }

        let normalizedPath = symbol.path
            .joined(
                separator: "."
            )
            .lowercased()

        if normalizedPath.contains(
            normalizedQuery
        ) {
            return 4
        }

        if symbol.identity.rawValue
            .lowercased()
            .contains(
                normalizedQuery
            )
        {
            return 5
        }

        return nil
    }

    private static func snapshotPrecedes(
        _ lhs: DocumentationSnapshot,
        _ rhs: DocumentationSnapshot
    ) -> Bool {
        snapshotKey(
            lhs.identity
        ) < snapshotKey(
            rhs.identity
        )
    }

    private static func modulePrecedes(
        _ lhs: DocumentationCatalogModule,
        _ rhs: DocumentationCatalogModule
    ) -> Bool {
        let lhsKey = (
            snapshotKey(lhs.snapshotIdentity),
            lhs.packageName,
            lhs.module.name,
            lhs.module.identity.rawValue
        )

        let rhsKey = (
            snapshotKey(rhs.snapshotIdentity),
            rhs.packageName,
            rhs.module.name,
            rhs.module.identity.rawValue
        )

        if lhsKey.0 != rhsKey.0 {
            return lhsKey.0 < rhsKey.0
        }

        if lhsKey.1 != rhsKey.1 {
            return lhsKey.1 < rhsKey.1
        }

        if lhsKey.2 != rhsKey.2 {
            return lhsKey.2 < rhsKey.2
        }

        return lhsKey.3 < rhsKey.3
    }

    private static func symbolPrecedes(
        _ lhs: DocumentationCatalogSymbol,
        _ rhs: DocumentationCatalogSymbol
    ) -> Bool {
        let lhsSnapshot = snapshotKey(
            lhs.snapshotIdentity
        )
        let rhsSnapshot = snapshotKey(
            rhs.snapshotIdentity
        )

        if lhsSnapshot != rhsSnapshot {
            return lhsSnapshot < rhsSnapshot
        }

        if lhs.packageName != rhs.packageName {
            return lhs.packageName < rhs.packageName
        }

        let lhsPath = lhs.symbol.path.joined(
            separator: "."
        )
        let rhsPath = rhs.symbol.path.joined(
            separator: "."
        )

        if lhsPath != rhsPath {
            return lhsPath < rhsPath
        }

        if lhs.symbol.name != rhs.symbol.name {
            return lhs.symbol.name < rhs.symbol.name
        }

        return lhs.symbol.identity.rawValue
            < rhs.symbol.identity.rawValue
    }

    private static func snapshotKey(
        _ identity: DocumentationSnapshotIdentity
    ) -> String {
        [
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
    }
}
