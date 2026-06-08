import Foundation

public extension Histogram {
    /// Reads one bin count. Traps if `bin` is out of range — but `UInt8`
    /// already covers the full `[0, 255]` bin space.
    func count(for bin: UInt8) -> UInt32 {
        counts[Int(bin)]
    }

    /// Applies a bin-wise binary `operation` against `source`. Saturating
    /// add/diff clamp at `UInt32.max` / `0`; AND/OR/XOR are bitwise on the
    /// 32-bit bin values. The result preserves `self.size`.
    func applying(_ operation: HistogramOperation, source: Histogram) -> Histogram {
        let combined = zip(counts, source.counts).map { lhs, rhs in
            operation.apply(lhs, rhs)
        }
        return try! Histogram(counts: combined, size: size)
    }

    /// Bin-wise bitwise NOT on the 32-bit bin values. Preserves `size`.
    func inverted() -> Histogram {
        let flipped = counts.map { ~$0 }
        return try! Histogram(counts: flipped, size: size)
    }
}

extension HistogramOperation {
    func apply(_ lhs: UInt32, _ rhs: UInt32) -> UInt32 {
        switch self {
        case .addSaturate:
            return lhs.addingReportingOverflow(rhs).overflow ? .max : lhs &+ rhs
        case .diffSaturate:
            return lhs < rhs ? 0 : lhs - rhs
        case .and: return lhs & rhs
        case .or:  return lhs | rhs
        case .xor: return lhs ^ rhs
        }
    }
}
