public struct DocumentationSymbolKind:
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

public enum DocumentationSymbolProvenance:
    String,
    Sendable,
    Hashable
{
    case source
    case synthesized
    case unknown
}

public struct DocumentationSymbol:
    Sendable,
    Hashable
{
    public let identity: DocumentationSymbolIdentity
    public let name: String
    public let path: [String]
    public let kind: DocumentationSymbolKind
    public let declaration: DocumentationDeclaration?
    public let content: DocumentationContent
    public let source: DocumentationSourceReference?
    public let provenance: DocumentationSymbolProvenance

    public init(
        identity: DocumentationSymbolIdentity,
        name: String,
        path: [String],
        kind: DocumentationSymbolKind,
        declaration: DocumentationDeclaration? = nil,
        content: DocumentationContent = .init(),
        source: DocumentationSourceReference? = nil,
        provenance: DocumentationSymbolProvenance = .unknown
    ) {
        self.identity = identity
        self.name = name
        self.path = path
        self.kind = kind
        self.declaration = declaration
        self.content = content
        self.source = source
        self.provenance = provenance
    }
}
