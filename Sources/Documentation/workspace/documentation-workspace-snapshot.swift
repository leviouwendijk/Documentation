import Executable
import Foundation

/// One semantic capture of the Swift package currently present at a filesystem
/// root. Unlike DocumentationSnapshot, this value does not claim immutable Git
/// revision identity and may represent uncommitted working-tree state.
public struct DocumentationWorkspaceSnapshot:
    Sendable,
    Hashable
{
    public let packageRoot: URL
    public let package: DocumentationPackage
    public let collection: DocumentationCollection

    public init(
        packageRoot: URL,
        package: DocumentationPackage,
        collection: DocumentationCollection
    ) {
        self.packageRoot = packageRoot.standardizedFileURL
        self.package = package
        self.collection = collection
    }
}

public enum DocumentationWorkspace {
    /// Derive compiler-backed semantic Documentation directly from the package
    /// currently present at packageRoot. No clone or Git revision resolution is
    /// performed.
    public static func snapshot(
        at packageRoot: URL,
        minimumAccessLevel: SwiftSymbolGraphAccessLevel = .internal
    ) async throws -> DocumentationWorkspaceSnapshot {
        let root = packageRoot.standardizedFileURL
        let manifest = try await Package.manifest(
            at: root
        )
        let symbolGraphs = try await Package.symbolGraphs(
            at: root,
            minimumAccessLevel: minimumAccessLevel
        )
        let graphImport = try DocumentationSymbolGraphImporter.importGraph(
            from: symbolGraphs,
            identity: .init(
                rawValue: "workspace:\(root.path)"
            ),
            title: manifest.name,
            sourceRoot: root
        )

        let modules = graphImport.moduleNames.map { name in
            DocumentationModule(
                identity: .init(
                    rawValue: name
                ),
                name: name
            )
        }
        let moduleNames = Set(
            graphImport.moduleNames
        )
        let targets = manifest.targets.map { target in
            DocumentationTarget(
                identity: .init(
                    rawValue: target.name
                ),
                name: target.name,
                type: target.type,
                path: target.path,
                module:
                    moduleNames.contains(
                        target.name
                    )
                        ? .init(
                            rawValue: target.name
                        )
                        : nil
            )
        }
        let products = manifest.products.map { product in
            DocumentationProduct(
                name: product.name,
                kind: .init(
                    rawValue: product.kind.rawValue
                ),
                targets: product.targets.map {
                    .init(
                        rawValue: $0
                    )
                }
            )
        }
        let package = DocumentationPackage(
            name: manifest.name,
            toolsVersion: manifest.toolsVersion,
            products: products,
            targets: targets,
            modules: modules
        )

        return .init(
            packageRoot: root,
            package: package,
            collection: graphImport.collection
        )
    }
}
