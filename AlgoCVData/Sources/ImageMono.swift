import Foundation

/// Binary (1-bit) image with bits packed into 32-bit little-endian words,
/// matching `ImPro.BinaryImage`'s in-memory layout. Each row occupies
/// `ceil(cols / 32)` words; unused trailing bits within the last word of a row
/// are zero.
public struct ImageMono: Sendable, Equatable {
    public let cols: UInt16
    public let rows: UInt16
    public let words: [UInt32]

    public init(cols: UInt16, rows: UInt16, words: [UInt32]) throws {
        guard cols > 0, rows > 0 else {
            throw AlgoCVError.invalidDimensions(cols: cols, rows: rows)
        }
        let wordsPerRow = (Int(cols) + 31) / 32
        let expected = wordsPerRow * Int(rows)
        guard words.count == expected else {
            throw AlgoCVError.invalidWordCount(expected: expected, actual: words.count)
        }
        self.cols = cols
        self.rows = rows
        self.words = words
    }

    /// Number of 32-bit words per row.
    public var stride: Int {
        (Int(cols) + 31) / 32
    }
}
