import Foundation

/// 4-bit grayscale (palette) image with two pixels packed per byte (high nibble
/// = even pixel, low nibble = odd pixel), row-major. If `cols` is odd the last
/// byte of each row stores the trailing pixel in the high nibble.
public struct Image4Bit: Sendable, Equatable {
    public let cols: UInt16
    public let rows: UInt16
    public let pixels: [UInt8]

    public init(cols: UInt16, rows: UInt16, pixels: [UInt8]) throws {
        guard cols > 0, rows > 0 else {
            throw AlgoCVError.invalidDimensions(cols: cols, rows: rows)
        }
        let packedRow = (Int(cols) + 1) / 2
        let expected = packedRow * Int(rows)
        guard pixels.count == expected else {
            throw AlgoCVError.invalidPixelCount(expected: expected, actual: pixels.count)
        }
        self.cols = cols
        self.rows = rows
        self.pixels = pixels
    }
}
