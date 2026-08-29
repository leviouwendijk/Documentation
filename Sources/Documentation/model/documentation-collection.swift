public struct DocumentationCollection:
    Sendable,
    Hashable
{
    public let identity: DocumentationIdentity
    public let title: String
    public let content: DocumentationContent
    public let symbols: [DocumentationSymbol]
    public let relationships: [DocumentationRelationship]

    public init(
        identity: DocumentationIdentity,
        title: String,
        content: DocumentationContent = .init(),
        symbols: [DocumentationSymbol] = [],
        relationships: [DocumentationRelationship] = []
    ) {
        self.identity = identity
        self.title = title
        self.content = content
        self.symbols = symbols
        self.relationships = relationships
    }
}
