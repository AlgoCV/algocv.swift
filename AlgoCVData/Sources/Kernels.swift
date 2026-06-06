
public enum KernelKind: String, Codable, Equatable, CaseIterable, Sendable {
    case zeroSum
    case unitSum
    case nonlinear
}

public struct KernelZeroSum: Identifiable, Codable, Equatable, Sendable, Matrix {
    public let values: [[Int8]]

    public var id: UInt64 {
        matrixHasher(kind: .zeroSum).digest
    }

    public init(values: [[Int8]]) {
        preconditionValidMatrix(values)
        self.values = values
    }

    public init(validating values: [[Int8]]) throws {
        try Self.validate(values)
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: MatrixCodingKeys.self)
        try self.init(validating: container.decode([[Int8]].self, forKey: .values))
    }
}

public struct KernelUnitSum: Identifiable, Codable, Equatable, Sendable, Matrix {
    public let values: [[UInt8]]
    public let denominator: UInt32

    public var id: UInt64 {
        var hasher = matrixHasher(kind: .unitSum)
        hasher.mix(denominator)
        return hasher.digest
    }

    public init(values: [[UInt8]], denominator: UInt32? = nil) {
        do {
            try self.init(validating: values, denominator: denominator)
        } catch {
            preconditionFailure(error.localizedDescription)
        }
    }

    public init(validating values: [[UInt8]], denominator: UInt32? = nil) throws {
        try Self.validate(values)
        let resolvedDenominator = try Self.resolvedDenominator(for: values, denominator: denominator)
        self.values = values
        self.denominator = resolvedDenominator
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: MatrixCodingKeys.self)
        let values = try container.decode([[UInt8]].self, forKey: .values)
        let denominator = try container.decodeIfPresent(UInt32.self, forKey: .denominator)
        try self.init(validating: values, denominator: denominator)
    }

    public static func defaultDenominator(for values: [[UInt8]]) throws -> UInt32 {
        try resolvedDenominator(for: values, denominator: nil)
    }

    private static func resolvedDenominator(for values: [[UInt8]], denominator: UInt32?) throws -> UInt32 {
        if let denominator {
            guard denominator > 0 else {
                throw MatrixValidationError.zeroDenominator
            }
            return denominator
        }

        let sum = values.reduce(UInt64(0)) { partialResult, row in
            partialResult + row.reduce(UInt64(0)) { $0 + UInt64($1) }
        }

        guard sum > 0 else {
            throw MatrixValidationError.zeroDenominator
        }
        guard sum <= UInt64(UInt32.max) else {
            throw MatrixValidationError.denominatorTooLarge(sum)
        }
        return UInt32(sum)
    }
}

public extension KernelUnitSum {
    /// Sum of all cells; can exceed `UInt32.max` for large kernels.
    var sum: UInt64 {
        Self.sum(of: values)
    }

    static func sum(of values: [[UInt8]]) -> UInt64 {
        values.reduce(UInt64(0)) { partial, row in
            partial + row.reduce(UInt64(0)) { $0 + UInt64($1) }
        }
    }
}

public extension KernelZeroSum {
    /// Algebraic sum of all signed cells.
    var sum: Int {
        Self.sum(of: values)
    }

    static func sum(of values: [[Int8]]) -> Int {
        values.reduce(0) { partial, row in
            partial + row.reduce(0) { $0 + Int($1) }
        }
    }
}

public extension KernelNonlinear {
    /// Number of `true` cells in the structuring element.
    var activeCount: Int {
        Self.activeCount(of: values)
    }

    static func activeCount(of values: [[Bool]]) -> Int {
        values.reduce(0) { partial, row in
            partial + row.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
    }
}

public struct KernelNonlinear: Identifiable, Codable, Equatable, Sendable, Matrix {
    public enum Transformation: String, Codable, Equatable, CaseIterable, Sendable {
        case max
        case min
        case avg
        case hAvg
        case gAvg
        case median
        case and
        case or
        case xor
    }

    public let values: [[Bool]]
    public let nonlinear: Transformation

    public var id: UInt64 {
        var hasher = matrixHasher(kind: .nonlinear)
        hasher.mix(nonlinear.rawValue)
        return hasher.digest
    }

    public var transformation: Transformation {
        nonlinear
    }

    public init(values: [[Bool]], nonlinear: Transformation) {
        preconditionValidMatrix(values)
        self.values = values
        self.nonlinear = nonlinear
    }

    public init(validating values: [[Bool]], nonlinear: Transformation) throws {
        try Self.validate(values)
        self.values = values
        self.nonlinear = nonlinear
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: MatrixCodingKeys.self)
        let values = try container.decode([[Bool]].self, forKey: .values)
        let nonlinear = try container.decode(Transformation.self, forKey: .nonlinear)
        try self.init(validating: values, nonlinear: nonlinear)
    }
}
