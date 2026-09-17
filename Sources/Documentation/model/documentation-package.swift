public struct DocumentationModuleIdentity:
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

public struct DocumentationTargetIdentity:
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

public struct DocumentationProductKind:
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

/// One Swift package product and the package targets it exposes.
public struct DocumentationProduct:
    Sendable,
    Hashable
{
    public let name: String
    public let kind: DocumentationProductKind
    public let targets: [DocumentationTargetIdentity]

    public init(
        name: String,
        kind: DocumentationProductKind,
        targets: [DocumentationTargetIdentity] = []
    ) {
        self.name = name
        self.kind = kind
        self.targets = targets
    }
}

/// One SwiftPM target retained as package topology.
///
/// `module` is present only when compiler symbol-graph output proves that this
/// target corresponds to a documented module. A package target is therefore not
/// assumed to be a public documentation module merely because it exists.
public struct DocumentationTarget:
    Sendable,
    Hashable
{
    public let identity: DocumentationTargetIdentity
    public let name: String
    public let type: String
    public let path: String?
    public let module: DocumentationModuleIdentity?

    public init(
        identity: DocumentationTargetIdentity,
        name: String,
        type: String,
        path: String? = nil,
        module: DocumentationModuleIdentity? = nil
    ) {
        self.identity = identity
        self.name = name
        self.type = type
        self.path = path
        self.module = module
    }
}

/// One compiler-produced module represented in the snapshot.
public struct DocumentationModule:
    Sendable,
    Hashable
{
    public let identity: DocumentationModuleIdentity
    public let name: String

    public init(
        identity: DocumentationModuleIdentity,
        name: String
    ) {
        self.identity = identity
        self.name = name
    }
}

/// Renderer-neutral Swift package topology associated with a documentation
/// snapshot.
///
/// Symbols and API relationships remain in DocumentationCollection. This model
/// retains only package/product/target/module structure rather than duplicating
/// the semantic symbol graph into a second hierarchy.
public struct DocumentationPackage:
    Sendable,
    Hashable
{
    public let name: String
    public let toolsVersion: String?
    public let products: [DocumentationProduct]
    public let targets: [DocumentationTarget]
    public let modules: [DocumentationModule]

    public init(
        name: String,
        toolsVersion: String? = nil,
        products: [DocumentationProduct] = [],
        targets: [DocumentationTarget] = [],
        modules: [DocumentationModule] = []
    ) {
        self.name = name
        self.toolsVersion = toolsVersion
        self.products = products
        self.targets = targets
        self.modules = modules
    }
}
