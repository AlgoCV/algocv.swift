import Foundation

public enum CVLibraryError: Error, Equatable, LocalizedError, Sendable {
    case duplicateKernel(id: UInt64)

    public var errorDescription: String? {
        switch self {
        case .duplicateKernel(let id):
            "CVLibrary contains duplicate kernel with id 0x\(String(id, radix: 16, uppercase: true))."
        }
    }
}

/// Curated collection of convolution and morphology kernels.
///
/// All kernels stored in a `CVLibrary` are guaranteed to have distinct `id`s
/// across kinds, so it is safe to use the library as a content-addressable
/// catalogue.
public struct CVLibrary: Codable, Equatable, Sendable {
    public let unitSumKernels: [KernelUnitSum]
    public let zeroSumKernels: [KernelZeroSum]
    public let nonlinearKernels: [KernelNonlinear]

    public init(
        unitSumKernels: [KernelUnitSum] = [],
        zeroSumKernels: [KernelZeroSum] = [],
        nonlinearKernels: [KernelNonlinear] = []
    ) throws {
        try Self.requireDistinct(
            unitSumKernels: unitSumKernels,
            zeroSumKernels: zeroSumKernels,
            nonlinearKernels: nonlinearKernels
        )
        self.unitSumKernels = unitSumKernels
        self.zeroSumKernels = zeroSumKernels
        self.nonlinearKernels = nonlinearKernels
    }

    private enum CodingKeys: String, CodingKey {
        case unitSumKernels
        case zeroSumKernels
        case nonlinearKernels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let unitSum = try container.decodeIfPresent([KernelUnitSum].self, forKey: .unitSumKernels) ?? []
        let zeroSum = try container.decodeIfPresent([KernelZeroSum].self, forKey: .zeroSumKernels) ?? []
        let nonlinear = try container.decodeIfPresent([KernelNonlinear].self, forKey: .nonlinearKernels) ?? []
        try self.init(
            unitSumKernels: unitSum,
            zeroSumKernels: zeroSum,
            nonlinearKernels: nonlinear
        )
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
}

public extension CVLibrary {
    /// Classical computer-vision kernels: smoothing low-pass filters,
    /// edge / Laplacian high-pass filters, and morphology structuring elements.
    static let standard: CVLibrary = {
        do {
            return try CVLibrary(
                unitSumKernels: standardUnitSumKernels,
                zeroSumKernels: standardZeroSumKernels,
                nonlinearKernels: standardNonlinearKernels
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
