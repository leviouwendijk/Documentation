package enum DocumentationRepositoryDeriver {
    package static func derive(
        _ inspection: DocumentationRepositoryInspection,
        from materialization: DocumentationMaterialization,
        toolchain: DocumentationToolchainIdentity,
        importerVersion: DocumentationImporterVersion = .current
    ) throws -> DocumentationSnapshot {
        let graphImport = try DocumentationSymbolGraphImporter.importGraph(
            from: inspection.symbolGraphs,
            identity: .init(
                rawValue:
                    materialization.repository.origin.absoluteString
                    + "#"
                    + materialization.revision.commit
            ),
            title: inspection.manifest.name,
            sourceRoot: materialization.checkoutRoot
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

        let targets = inspection.manifest.targets.map { target in
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

        let products = inspection.manifest.products.map { product in
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
            name: inspection.manifest.name,
            toolsVersion: inspection.manifest.toolsVersion,
            products: products,
            targets: targets,
            modules: modules
        )

        let identity = DocumentationSnapshotIdentity(
            repository: materialization.repository,
            revision: materialization.revision,
            toolchain: toolchain,
            importerVersion: importerVersion
        )

        return .init(
            identity: identity,
            repository: materialization.repository,
            revision: materialization.revision,
            package: package,
            collection: graphImport.collection
        )
    }
}
