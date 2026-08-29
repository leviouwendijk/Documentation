public struct DocumentationSourceReference:
    Sendable,
    Hashable
{
    public let uri: String
    public let line: Int?
    public let character: Int?

    public init(
        uri: String,
        line: Int? = nil,
        character: Int? = nil
    ) {
        self.uri = uri
        self.line = line
        self.character = character
    }
}
