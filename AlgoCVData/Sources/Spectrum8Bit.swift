import Foundation

/// Frequency-domain representation of an `Image8Bit`, stored as two row-major
/// `Int32` planes (real and imaginary parts), matching ImPro's `Freq256`
/// layout. Each plane has `cols * rows` complex coefficients.
public struct Spectrum8Bit: Sendable, Equatable {
    public let cols: UInt16
    public let rows: UInt16
    public let real: [Int32]
    public let imag: [Int32]

    public init(cols: UInt16, rows: UInt16, real: [Int32], imag: [Int32]) throws {
        guard cols > 0, rows > 0 else {
            throw AlgoCVError.invalidDimensions(cols: cols, rows: rows)
        }
        let expected = Int(cols) * Int(rows)
        guard real.count == expected else {
            throw AlgoCVError.invalidSpectrumPlaneCount(expected: expected, actual: real.count)
        }
        guard imag.count == expected else {
            throw AlgoCVError.invalidSpectrumPlaneCount(expected: expected, actual: imag.count)
        }
        self.cols = cols
        self.rows = rows
        self.real = real
        self.imag = imag
    }
}
