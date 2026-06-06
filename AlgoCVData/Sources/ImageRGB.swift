import Foundation

/// 8-bit RGB image with interleaved R/G/B bytes (3 bytes per pixel), row-major.
public struct ImageRGB: Sendable, Equatable {
    public let cols: UInt16
    public let rows: UInt16
    public let pixels: [UInt8]

    public init(cols: UInt16, rows: UInt16, pixels: [UInt8]) throws {
        guard cols > 0, rows > 0 else {
            throw AlgoCVError.invalidDimensions(cols: cols, rows: rows)
        }
        let expected = Int(cols) * Int(rows) * 3
        guard pixels.count == expected else {
            throw AlgoCVError.invalidPixelCount(expected: expected, actual: pixels.count)
        }
        self.cols = cols
        self.rows = rows
        self.pixels = pixels
    }
}
