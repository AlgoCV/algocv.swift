public protocol Filter: Codable, Equatable, Sendable {
    var id: UInt64 { get }
    var name: String { get }
    var details: String? { get }
}

public struct FilterLowpass: Identifiable, Codable, Equatable, Sendable, Filter {
    public var id: UInt64 {
        kernel.id
    }

    public var name: String
    public var details: String?
    public var kernel: KernelUnitSum

    public init(name: String, details: String? = nil, kernel: KernelUnitSum) {
        self.name = name
        self.details = details
        self.kernel = kernel
    }
}

public struct FilterHighpass: Identifiable, Codable, Equatable, Sendable, Filter {
    public var id: UInt64 {
        kernel.id
    }

    public var name: String
    public var details: String?
    public var kernel: KernelZeroSum

    public init(name: String, details: String? = nil, kernel: KernelZeroSum) {
        self.name = name
        self.details = details
        self.kernel = kernel
    }
}

public struct FilterNonlinear: Identifiable, Codable, Equatable, Sendable, Filter {
    public var id: UInt64 {
        kernel.id
    }

    public var name: String
    public var details: String?
    public var kernel: KernelNonlinear

    public init(name: String, details: String? = nil, kernel: KernelNonlinear) {
        self.name = name
        self.details = details
        self.kernel = kernel
    }
}
