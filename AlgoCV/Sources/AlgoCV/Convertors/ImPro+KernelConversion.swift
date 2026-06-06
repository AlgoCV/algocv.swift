import AlgoCVData
import ImPro

extension KernelZeroSum {
    func toImPro() throws -> ImPro.Kernel {
        let flat: [Int8] = values.flatMap { $0 }
        return try ImPro.Kernel(rows: rowCount, cols: colCount, zeroSumWeights: flat)
    }
}

extension KernelUnitSum {
    func toImPro() throws -> ImPro.Kernel {
        let flat: [UInt8] = values.flatMap { $0 }
        return try ImPro.Kernel(
            rows: rowCount,
            cols: colCount,
            unitWeights: flat,
            denominator: denominator
        )
    }
}

extension NonlinearTransformation {
    func toImProNonlinearOp() -> ImPro.Kernel.NonlinearOp {
        switch self {
        case .max: return .max
        case .min: return .min
        case .avg: return .average
        case .hAvg: return .harmonicAverage
        case .gAvg: return .geometricAverage
        case .median: return .median
        case .and: return .and
        case .or:  return .or
        case .xor: return .xor
        }
    }
}

extension Shape {
    /// Builds a custom-shape nonlinear `ImPro.Kernel` (mask + reducer).
    func toImProKernel(with op: NonlinearTransformation) throws -> ImPro.Kernel {
        let flat: [UInt8] = mask.flatMap { row in row.map { $0 ? UInt8(1) : UInt8(0) } }
        return try ImPro.Kernel(
            rows: rows,
            cols: cols,
            nonlinearShape: flat,
            op: op.toImProNonlinearOp()
        )
    }

    /// Builds an `ImPro.BinaryShape` for morphology. The mask is packed into
    /// little-endian 32-bit words, one row at a time, matching the C bridge
    /// layout (`ceil(cols / 32)` words per row).
    func toImProBinaryShape() throws -> ImPro.BinaryShape {
        let wordsPerRow = (Int(cols) + 31) / 32
        var packed = [UInt32](repeating: 0, count: wordsPerRow * Int(rows))
        for (r, row) in mask.enumerated() {
            for (c, bit) in row.enumerated() where bit {
                let wordIndex = r * wordsPerRow + (c / 32)
                packed[wordIndex] |= UInt32(1) &<< UInt32(c % 32)
            }
        }
        return try ImPro.BinaryShape(rows: rows, cols: cols, maskWords: packed)
    }
}
