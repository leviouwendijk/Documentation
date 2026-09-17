import Executable

package struct DocumentationRepositoryInspection:
    Sendable
{
    package let manifest: SwiftPackageManifest
    package let symbolGraphs: SwiftSymbolGraphDump

    package init(
        manifest: SwiftPackageManifest,
        symbolGraphs: SwiftSymbolGraphDump
    ) {
        self.manifest = manifest
        self.symbolGraphs = symbolGraphs
    }
}

package enum DocumentationRepositoryInspector {
    package static func inspect(
        _ materialization: DocumentationMaterialization,
        minimumAccessLevel: SwiftSymbolGraphAccessLevel = .public
    ) async throws -> DocumentationRepositoryInspection {
        let manifest = try await Package.manifest(
            at: materialization.checkoutRoot
        )

        let symbolGraphs = try await Package.symbolGraphs(
            at: materialization.checkoutRoot,
            minimumAccessLevel: minimumAccessLevel
        )

        return .init(
            manifest: manifest,
            symbolGraphs: symbolGraphs
        )
    }
}
