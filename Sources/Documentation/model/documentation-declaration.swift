public struct DocumentationDeclaration:
    Sendable,
    Hashable
{
    public struct Fragment:
        Sendable,
        Hashable
    {
        public struct Kind:
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

        public let kind: Kind
        public let spelling: String
        public let referencedSymbol: DocumentationSymbolIdentity?

        public init(
            kind: Kind,
            spelling: String,
            referencedSymbol: DocumentationSymbolIdentity? = nil
        ) {
            self.kind = kind
            self.spelling = spelling
            self.referencedSymbol = referencedSymbol
        }
    }

    public let fragments: [Fragment]

    public init(
        fragments: [Fragment]
    ) {
        self.fragments = fragments
    }
}
