import Foundation

/// 8-bit grayscale image stored as a row-major byte buffer.
public struct Image8Bit: Sendable, Equatable {
    public let cols: UInt16
    public let rows: UInt16
    public let pixels: [UInt8]

    public init(cols: UInt16, rows: UInt16, pixels: [UInt8]) throws {
        guard cols > 0, rows > 0 else {
            throw AlgoCVError.invalidDimensions(cols: cols, rows: rows)
        }
        let expected = Int(cols) * Int(rows)
        guard pixels.count == expected else {
            throw AlgoCVError.invalidPixelCount(expected: expected, actual: pixels.count)
        }
        self.cols = cols
        self.rows = rows
        self.pixels = pixels
    }
}
