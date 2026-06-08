import Foundation

/// 256-bin grayscale histogram. `counts[i]` is the number of source pixels
/// with intensity `i`; `size` is the pixel count of the source image used
/// to build it. Bin-wise ops (`and`, `or`, `xor`, saturating add/diff) and
/// `invert` operate on the bin array directly and may break the
/// `sum(counts) == size` invariant, which is intentional and matches ImPro.
public struct Histogram: Sendable, Equatable, Codable {
    public static let binCount = 256

    public let counts: [UInt32]
    public let size: UInt32

    public init(counts: [UInt32], size: UInt32) throws {
        guard counts.count == Self.binCount else {
            throw AlgoCVError.invalidBinCount(expected: Self.binCount, actual: counts.count)
        }
        self.counts = counts
        self.size = size
    }
}
