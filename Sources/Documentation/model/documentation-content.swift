public struct DocumentationContent:
    Sendable,
    Hashable
{
    public indirect enum Block:
        Sendable,
        Hashable
    {
        case paragraph(String)

        case code(
            language: String?,
            source: String
        )

        case section(
            title: String,
            blocks: [Block]
        )
    }

    public let blocks: [Block]

    public init(
        blocks: [Block] = []
    ) {
        self.blocks = blocks
    }
}
