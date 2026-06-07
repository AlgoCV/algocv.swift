import Foundation

/// Type tag for an `OperatorParameter`, used by per-call schema validation
/// (§6 of `Docs/Operators.md`). Mirrors the case set of `OperatorParameter`
/// without the payload.
public enum ParameterKind: String, Codable, Sendable, Equatable, CaseIterable {
    case kernelUnitSum
    case kernelZeroSum
    case kernelNonlinear
    case shape
    case colorSpace
    case nonlinearTransformation
    case gray
    case count
    case size
    case flag
    case label
}

/// A fixed-value parameter bound into an operator's call. Variable parameters
/// (e.g. a kernel computed at runtime) are modelled as input slots instead.
public enum OperatorParameter: Equatable, Sendable {
    case kernelUnitSum(KernelUnitSum)
    case kernelZeroSum(KernelZeroSum)
    case kernelNonlinear(KernelNonlinear)
    case shape(Shape)
    case colorSpace(ColorSpace)
    case nonlinearTransformation(NonlinearTransformation)
    case gray(UInt8)
    case count(UInt32)
    case size(width: UInt16, height: UInt16)
    case flag(Bool)
    case label(String)

    public var kind: ParameterKind {
        switch self {
        case .kernelUnitSum:            .kernelUnitSum
        case .kernelZeroSum:            .kernelZeroSum
        case .kernelNonlinear:          .kernelNonlinear
        case .shape:                    .shape
        case .colorSpace:               .colorSpace
        case .nonlinearTransformation:  .nonlinearTransformation
        case .gray:                     .gray
        case .count:                    .count
        case .size:                     .size
        case .flag:                     .flag
        case .label:                    .label
        }
    }
}

extension OperatorParameter: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum SizeCodingKeys: String, CodingKey {
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(ParameterKind.self, forKey: .type)
        switch kind {
        case .kernelUnitSum:
            self = .kernelUnitSum(try container.decode(KernelUnitSum.self, forKey: .value))
        case .kernelZeroSum:
            self = .kernelZeroSum(try container.decode(KernelZeroSum.self, forKey: .value))
        case .kernelNonlinear:
            self = .kernelNonlinear(try container.decode(KernelNonlinear.self, forKey: .value))
        case .shape:
            self = .shape(try container.decode(Shape.self, forKey: .value))
        case .colorSpace:
            self = .colorSpace(try container.decode(ColorSpace.self, forKey: .value))
        case .nonlinearTransformation:
            self = .nonlinearTransformation(try container.decode(NonlinearTransformation.self, forKey: .value))
        case .gray:
            self = .gray(try container.decode(UInt8.self, forKey: .value))
        case .count:
            self = .count(try container.decode(UInt32.self, forKey: .value))
        case .size:
            let nested = try container.nestedContainer(keyedBy: SizeCodingKeys.self, forKey: .value)
            let width = try nested.decode(UInt16.self, forKey: .width)
            let height = try nested.decode(UInt16.self, forKey: .height)
            self = .size(width: width, height: height)
        case .flag:
            self = .flag(try container.decode(Bool.self, forKey: .value))
        case .label:
            self = .label(try container.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .type)
        switch self {
        case .kernelUnitSum(let kernel):
            try container.encode(kernel, forKey: .value)
        case .kernelZeroSum(let kernel):
            try container.encode(kernel, forKey: .value)
        case .kernelNonlinear(let kernel):
            try container.encode(kernel, forKey: .value)
        case .shape(let shape):
            try container.encode(shape, forKey: .value)
        case .colorSpace(let space):
            try container.encode(space, forKey: .value)
        case .nonlinearTransformation(let transformation):
            try container.encode(transformation, forKey: .value)
        case .gray(let value):
            try container.encode(value, forKey: .value)
        case .count(let value):
            try container.encode(value, forKey: .value)
        case .size(let width, let height):
            var nested = container.nestedContainer(keyedBy: SizeCodingKeys.self, forKey: .value)
            try nested.encode(width, forKey: .width)
            try nested.encode(height, forKey: .height)
        case .flag(let value):
            try container.encode(value, forKey: .value)
        case .label(let value):
            try container.encode(value, forKey: .value)
        }
    }
}

extension OperatorParameter {
    /// Folds the parameter's discriminator and canonical payload bytes into
    /// `hasher` for operator-signature computation. Field-by-field stable
    /// across runs and processes. Names are NOT mixed here — see §5.
    func mix(into hasher: inout FNV1a) {
        hasher.mix(kind.rawValue)
        switch self {
        case .kernelUnitSum(let kernel):
            hasher.mix(kernel.id)
        case .kernelZeroSum(let kernel):
            hasher.mix(kernel.id)
        case .kernelNonlinear(let kernel):
            hasher.mix(kernel.id)
        case .shape(let shape):
            hasher.mix(shape.cols)
            hasher.mix(shape.rows)
            for row in shape.mask {
                for cell in row {
                    hasher.mix(cell ? UInt8(1) : UInt8(0))
                }
            }
        case .colorSpace(let space):
            hasher.mix(space.rawValue)
        case .nonlinearTransformation(let transformation):
            hasher.mix(transformation.rawValue)
        case .gray(let value):
            hasher.mix(value)
        case .count(let value):
            hasher.mix(value)
        case .size(let width, let height):
            hasher.mix(width)
            hasher.mix(height)
        case .flag(let value):
            hasher.mix(value ? UInt8(1) : UInt8(0))
        case .label(let value):
            hasher.mix(value)
        }
    }
}

/// A parameter together with its display-only name. The name does not
/// participate in the operator signature.
public struct NamedParameter: Codable, Equatable, Sendable {
    public let name: String
    public let value: OperatorParameter

    public init(name: String, value: OperatorParameter) {
        self.name = name
        self.value = value
    }
}
