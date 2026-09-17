public struct DocumentationRelationshipKind:
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

public struct DocumentationRelationship:
    Sendable,
    Hashable
{
    public struct SourceOrigin:
        Sendable,
        Hashable
    {
        public let symbol: DocumentationSymbolIdentity
        public let displayName: String

        public init(
            symbol: DocumentationSymbolIdentity,
            displayName: String
        ) {
            self.symbol = symbol
            self.displayName = displayName
        }
    }

    public let source: DocumentationSymbolIdentity
    public let target: DocumentationSymbolIdentity
    public let kind: DocumentationRelationshipKind
    public let targetFallback: String?
    public let sourceOrigin: SourceOrigin?

    public init(
        source: DocumentationSymbolIdentity,
        target: DocumentationSymbolIdentity,
        kind: DocumentationRelationshipKind,
        targetFallback: String? = nil,
        sourceOrigin: SourceOrigin? = nil
    ) {
        self.source = source
        self.target = target
        self.kind = kind
        self.targetFallback = targetFallback
        self.sourceOrigin = sourceOrigin
    }
}
