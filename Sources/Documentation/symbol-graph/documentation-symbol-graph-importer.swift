import Executable
import Foundation
import ParsersStructuredContent
import SymbolKit

package struct DocumentationSymbolGraphImport:
    Sendable,
    Hashable
{
    package let collection: DocumentationCollection
    package let moduleNames: [String]

    package init(
        collection: DocumentationCollection,
        moduleNames: [String]
    ) {
        self.collection = collection
        self.moduleNames = moduleNames
    }
}

package enum DocumentationSymbolGraphImporter {
    package static func importGraph(
        from dump: SwiftSymbolGraphDump,
        identity: DocumentationIdentity,
        title: String,
        sourceRoot: URL
    ) throws -> DocumentationSymbolGraphImport {
        let graphs = try dump.files
            .sorted {
                $0.path < $1.path
            }
            .map { file in
                try JSONDecoder().decode(
                    SymbolGraph.self,
                    from: Data(
                        contentsOf: file
                    )
                )
            }

        let sourceOriginSymbols = Set(
            graphs
                .flatMap(\.relationships)
                .compactMap { relationship -> String? in
                    let origin: SymbolGraph.Relationship.SourceOrigin? =
                        relationship[
                            mixin: SymbolGraph.Relationship.SourceOrigin.self
                        ]

                    guard origin != nil else {
                        return nil
                    }

                    return relationship.source
                }
        )

        var symbolsByIdentity: [
            DocumentationSymbolIdentity: DocumentationSymbol
        ] = [:]

        var relationships = Set<DocumentationRelationship>()

        for graph in graphs {
            for symbol in graph.symbols.values.sorted(
                by: {
                    $0.identifier.precise
                        < $1.identifier.precise
                }
            ) {
                let imported = documentationSymbol(
                    from: symbol,
                    module: .init(
                        rawValue: graph.module.name
                    ),
                    sourceOriginSymbols: sourceOriginSymbols,
                    sourceRoot: sourceRoot
                )

                if symbolsByIdentity[imported.identity] == nil {
                    symbolsByIdentity[imported.identity] = imported
                }
            }

            for relationship in graph.relationships {
                relationships.insert(
                    documentationRelationship(
                        from: relationship
                    )
                )
            }
        }

        let symbols = symbolsByIdentity
            .values
            .sorted {
                $0.identity.rawValue
                    < $1.identity.rawValue
            }

        let sortedRelationships = relationships.sorted {
            relationshipSortKey(
                $0
            ) < relationshipSortKey(
                $1
            )
        }

        let collection = DocumentationCollection(
            identity: identity,
            title: title,
            symbols: symbols,
            relationships: sortedRelationships
        )

        let moduleNames = Array(
            Set(
                graphs.map {
                    $0.module.name
                }
            )
        )
            .sorted()

        return .init(
            collection: collection,
            moduleNames: moduleNames
        )
    }
}

private extension DocumentationSymbolGraphImporter {
    static func documentationSymbol(
        from symbol: SymbolGraph.Symbol,
        module: DocumentationModuleIdentity,
        sourceOriginSymbols: Set<String>,
        sourceRoot: URL
    ) -> DocumentationSymbol {
        let identity = DocumentationSymbolIdentity(
            rawValue: symbol.identifier.precise
        )

        let source = sourceReference(
            from: symbol,
            sourceRoot: sourceRoot
        )

        let kindIdentifier = symbol
            .kind
            .identifier
            .identifier

        let kind: String

        if symbol.identifier.interfaceLanguage.isEmpty {
            kind = kindIdentifier
        } else {
            kind = "\(symbol.identifier.interfaceLanguage).\(kindIdentifier)"
        }

        return .init(
            identity: identity,
            name: symbol.names.title,
            path: symbol.pathComponents,
            kind: .init(
                rawValue: kind
            ),
            module: module,
            declaration: declaration(
                from: symbol
            ),
            content: content(
                from: symbol
            ),
            source: source,
            provenance: provenance(
                for: symbol,
                source: source,
                sourceOriginSymbols: sourceOriginSymbols
            )
        )
    }

    static func declaration(
        from symbol: SymbolGraph.Symbol
    ) -> DocumentationDeclaration? {
        guard
            let fragments = symbol.declarationFragments,
            !fragments.isEmpty
        else {
            return nil
        }

        return .init(
            fragments: fragments.map { fragment in
                .init(
                    kind: .init(
                        rawValue: fragment.kind.rawValue
                    ),
                    spelling: fragment.spelling,
                    referencedSymbol: fragment.preciseIdentifier.map {
                        .init(
                            rawValue: $0
                        )
                    }
                )
            }
        )
    }

    static func content(
        from symbol: SymbolGraph.Symbol
    ) -> DocumentationContent {
        guard
            let docComment = symbol.docComment,
            !docComment.lines.isEmpty
        else {
            return .init()
        }

        let authoredMarkup = docComment.lines
            .map(\.text)
            .joined(
                separator: "\n"
            )

        return .init(
            authoredMarkup: authoredMarkup,
            structuredContent:
                MarkdownStructuredContentParser.parse(
                    authoredMarkup
                )
        )
    }

    static func sourceReference(
        from symbol: SymbolGraph.Symbol,
        sourceRoot: URL
    ) -> DocumentationSourceReference? {
        let location: SymbolGraph.Symbol.Location? = symbol[
            mixin: SymbolGraph.Symbol.Location.self
        ]

        guard let location else {
            return nil
        }

        return .init(
            uri: normalizedSourceURI(
                location,
                relativeTo: sourceRoot
            ),
            line: location.position.line,
            character: location.position.character
        )
    }

    static func normalizedSourceURI(
        _ location: SymbolGraph.Symbol.Location,
        relativeTo sourceRoot: URL
    ) -> String {
        guard
            let sourceURL = location.url,
            sourceURL.isFileURL
        else {
            return location.uri
        }

        let root = sourceRoot
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        let source = sourceURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        let prefix = root.hasSuffix("/")
            ? root
            : "\(root)/"

        guard source.hasPrefix(prefix) else {
            return location.uri
        }

        return String(
            source.dropFirst(
                prefix.count
            )
        )
    }

    static func provenance(
        for symbol: SymbolGraph.Symbol,
        source: DocumentationSourceReference?,
        sourceOriginSymbols: Set<String>
    ) -> DocumentationSymbolProvenance {
        let precise = symbol.identifier.precise

        if symbol.isVirtual
            || precise.contains(
                "::SYNTHESIZED::"
            )
            || sourceOriginSymbols.contains(
                precise
            )
        {
            return .synthesized
        }

        if source != nil {
            return .source
        }

        return .unknown
    }

    static func documentationRelationship(
        from relationship: SymbolGraph.Relationship
    ) -> DocumentationRelationship {
        let origin: SymbolGraph.Relationship.SourceOrigin? = relationship[
            mixin: SymbolGraph.Relationship.SourceOrigin.self
        ]

        return .init(
            source: .init(
                rawValue: relationship.source
            ),
            target: .init(
                rawValue: relationship.target
            ),
            kind: .init(
                rawValue: relationship.kind.rawValue
            ),
            targetFallback: relationship.targetFallback,
            sourceOrigin: origin.map {
                .init(
                    symbol: .init(
                        rawValue: $0.identifier
                    ),
                    displayName: $0.displayName
                )
            }
        )
    }

    static func relationshipSortKey(
        _ relationship: DocumentationRelationship
    ) -> String {
        [
            relationship.source.rawValue,
            relationship.target.rawValue,
            relationship.kind.rawValue,
            relationship.targetFallback ?? "",
            relationship.sourceOrigin?.symbol.rawValue ?? "",
            relationship.sourceOrigin?.displayName ?? "",
        ]
        .joined(
            separator: "\u{1F}"
        )
    }
}
