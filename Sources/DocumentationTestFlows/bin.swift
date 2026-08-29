import TestFlows

@main
enum DocumentationFlowTestMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: DocumentationFlowSuite.self
        )
    }
}

enum DocumentationFlowSuite:
    TestFlowRegistry
{
    static let title = "Documentation flow tests"

    static let flows: [TestFlow] = [
        documentationModelFlow,
        documentationRepositoryFlow,
    ]
}
