import DSL

public struct DocumentationContent:
    Sendable,
    Hashable
{
    public let authoredMarkup: String?
    public let structuredContent: StructuredContent

    public init(
        authoredMarkup: String? = nil,
        structuredContent: StructuredContent = .collection([])
    ) {
        self.authoredMarkup = authoredMarkup
        self.structuredContent = structuredContent
    }
}
