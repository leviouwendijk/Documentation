import Documentation
import TestFlows

extension DocumentationFlowSuite {
    static var documentationModelFlow: TestFlow {
        TestFlow(
            "documentation-model",
            tags: [
                "documentation",
                "model",
                "semantic",
            ]
        ) {
            Step("semantic model preserves structure without renderer lowering") {
                let identity = DocumentationSymbolIdentity(
                    rawValue: "s:4Demo4TypeV"
                )

                let symbol = DocumentationSymbol(
                    identity: identity,
                    name: "Type",
                    path: [
                        "Type",
                    ],
                    kind: .init(
                        rawValue: "swift.struct"
                    ),
                    declaration: .init(
                        fragments: [
                            .init(
                                kind: .init(
                                    rawValue: "keyword"
                                ),
                                spelling: "struct"
                            ),
                            .init(
                                kind: .init(
                                    rawValue: "identifier"
                                ),
                                spelling: "Type",
                                referencedSymbol: identity
                            ),
                        ]
                    ),
                    content: .init(
                        authoredMarkup:
                            "A **semantic** documentation symbol with `code`.",
                        structuredContent: .paragraph(
                            [
                                .text("A "),
                                .strong(
                                    [
                                        .text("semantic"),
                                    ]
                                ),
                                .text(" documentation symbol with "),
                                .code("code"),
                                .text("."),
                            ]
                        )
                    ),
                    source: .init(
                        uri: "Sources/Demo/Type.swift",
                        line: 1,
                        character: 1
                    ),
                    provenance: .source
                )

                let collection = DocumentationCollection(
                    identity: .init(
                        rawValue: "demo"
                    ),
                    title: "Demo",
                    symbols: [
                        symbol,
                    ]
                )

                try Expect.equal(
                    collection.symbols.first?
                        .declaration?
                        .fragments
                        .last?
                        .referencedSymbol,
                    Optional(identity),
                    "declaration fragments keep typed symbol references"
                )

                try Expect.equal(
                    collection.symbols.first?
                        .content
                        .authoredMarkup,
                    Optional(
                        "A **semantic** documentation symbol with `code`."
                    ),
                    "symbol content preserves canonical authored markup"
                )

                try Expect.equal(
                    collection.symbols.first?
                        .content
                        .structuredContent,
                    Optional(
                        .paragraph(
                            [
                                .text("A "),
                                .strong(
                                    [
                                        .text("semantic"),
                                    ]
                                ),
                                .text(" documentation symbol with "),
                                .code("code"),
                                .text("."),
                            ]
                        )
                    ),
                    "symbol content stores shared structured semantics"
                )
            }
        }
    }
}
