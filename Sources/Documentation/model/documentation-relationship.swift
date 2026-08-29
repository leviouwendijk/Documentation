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
    public let source: DocumentationSymbolIdentity
    public let target: DocumentationSymbolIdentity
    public let kind: DocumentationRelationshipKind

    public init(
        source: DocumentationSymbolIdentity,
        target: DocumentationSymbolIdentity,
        kind: DocumentationRelationshipKind
    ) {
        self.source = source
        self.target = target
        self.kind = kind
    }
}
