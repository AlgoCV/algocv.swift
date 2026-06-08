import Foundation

public enum CVLibraryError: Error, Equatable, LocalizedError, Sendable {
    case duplicateKernel(id: UInt64)
    case duplicateOperator(signature: UInt64)

    public var errorDescription: String? {
        switch self {
        case .duplicateKernel(let id):
            "CVLibrary contains duplicate kernel with id 0x\(String(id, radix: 16, uppercase: true))."
        case .duplicateOperator(let signature):
            "CVLibrary contains duplicate operator with signature 0x\(String(signature, radix: 16, uppercase: true))."
        }
    }
}

/// Curated collection of convolution / morphology kernels and operators.
///
/// All kernels stored in a `CVLibrary` are guaranteed to have distinct `id`s
/// across kinds, so it is safe to use the library as a content-addressable
/// catalogue. The same applies to operator signatures, in a separate
/// namespace (kernel ids and operator signatures share the `FNV1a` output
/// space but are domain-separated, so cross-set equality has no semantic
/// meaning and is not enforced).
public struct CVLibrary: Codable, Equatable, Sendable {
    public let unitSumKernels: [KernelUnitSum]
    public let zeroSumKernels: [KernelZeroSum]
    public let nonlinearKernels: [KernelNonlinear]
    public let operators: [Operator]

    public init(
        unitSumKernels: [KernelUnitSum] = [],
        zeroSumKernels: [KernelZeroSum] = [],
        nonlinearKernels: [KernelNonlinear] = [],
        operators: [Operator] = []
    ) throws {
        try Self.requireDistinct(
            unitSumKernels: unitSumKernels,
            zeroSumKernels: zeroSumKernels,
            nonlinearKernels: nonlinearKernels
        )
        try Self.requireDistinctOperators(operators)
        self.unitSumKernels = unitSumKernels
        self.zeroSumKernels = zeroSumKernels
        self.nonlinearKernels = nonlinearKernels
        self.operators = operators
    }

    private static func requireDistinct(
        unitSumKernels: [KernelUnitSum],
        zeroSumKernels: [KernelZeroSum],
        nonlinearKernels: [KernelNonlinear]
    ) throws {
        var seen: Set<UInt64> = []
        seen.reserveCapacity(unitSumKernels.count + zeroSumKernels.count + nonlinearKernels.count)
        for id in unitSumKernels.lazy.map(\.id) {
            guard seen.insert(id).inserted else {
                throw CVLibraryError.duplicateKernel(id: id)
            }
        }
        for id in zeroSumKernels.lazy.map(\.id) {
            guard seen.insert(id).inserted else {
                throw CVLibraryError.duplicateKernel(id: id)
            }
        }
        for id in nonlinearKernels.lazy.map(\.id) {
            guard seen.insert(id).inserted else {
                throw CVLibraryError.duplicateKernel(id: id)
            }
        }
    }

    private static func requireDistinctOperators(_ operators: [Operator]) throws {
        var seen: Set<UInt64> = []
        seen.reserveCapacity(operators.count)
        for signature in operators.lazy.map(\.id) {
            guard seen.insert(signature).inserted else {
                throw CVLibraryError.duplicateOperator(signature: signature)
            }
        }
    }
}

public extension CVLibrary {
    /// Classical computer-vision kernels and the standard operator catalogue
    /// built on top of them.
    static let standard: CVLibrary = {
        do {
            return try CVLibrary(
                unitSumKernels: standardUnitSumKernels,
                zeroSumKernels: standardZeroSumKernels,
                nonlinearKernels: standardNonlinearKernels,
                operators: standardOperators
            )
        } catch {
            preconditionFailure("CVLibrary.standard violated distinctness invariant: \(error.localizedDescription)")
        }
    }()

    static var standardUnitSumKernels: [KernelUnitSum] {
        [
            KernelUnitSum(values: [
                [1, 1, 1],
                [1, 1, 1],
                [1, 1, 1],
            ]),
            KernelUnitSum(values: Array(
                repeating: Array(repeating: 1, count: 5),
                count: 5
            )),
            KernelUnitSum(values: [
                [1, 2, 1],
                [2, 4, 2],
                [1, 2, 1],
            ]),
            KernelUnitSum(values: [
                [1,  4,  6,  4, 1],
                [4, 16, 24, 16, 4],
                [6, 24, 36, 24, 6],
                [4, 16, 24, 16, 4],
                [1,  4,  6,  4, 1],
            ]),
        ]
    }

    static var standardZeroSumKernels: [KernelZeroSum] {
        [
            KernelZeroSum(values: [
                [0,  1, 0],
                [1, -4, 1],
                [0,  1, 0],
            ]),
            KernelZeroSum(values: [
                [1,  1, 1],
                [1, -8, 1],
                [1,  1, 1],
            ]),
            KernelZeroSum(values: [
                [-1, 0, 1],
                [-1, 0, 1],
                [-1, 0, 1],
            ]),
            KernelZeroSum(values: [
                [-1, -1, -1],
                [ 0,  0,  0],
                [ 1,  1,  1],
            ]),
            KernelZeroSum(values: [
                [-1, 0, 1],
                [-2, 0, 2],
                [-1, 0, 1],
            ]),
            KernelZeroSum(values: [
                [-1, -2, -1],
                [ 0,  0,  0],
                [ 1,  2,  1],
            ]),
            KernelZeroSum(values: [
                [ -3, 0,  3],
                [-10, 0, 10],
                [ -3, 0,  3],
            ]),
            KernelZeroSum(values: [
                [-3, -10, -3],
                [ 0,   0,  0],
                [ 3,  10,  3],
            ]),
        ]
    }

    static var standardNonlinearKernels: [KernelNonlinear] {
        let box3: [[Bool]] = Array(
            repeating: Array(repeating: true, count: 3),
            count: 3
        )
        let cross3: [[Bool]] = [
            [false, true, false],
            [true,  true, true ],
            [false, true, false],
        ]
        let transformations: [KernelNonlinear.Transformation] = [.max, .min, .median]
        return transformations.flatMap { transformation in
            [
                KernelNonlinear(values: box3, nonlinear: transformation),
                KernelNonlinear(values: cross3, nonlinear: transformation),
            ]
        }
    }
}
