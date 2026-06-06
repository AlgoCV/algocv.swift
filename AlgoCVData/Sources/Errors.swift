import Foundation

public enum AlgoCVError: Error, Equatable, Sendable, LocalizedError {
    case invalidDimensions(cols: UInt16, rows: UInt16)
    case invalidPixelCount(expected: Int, actual: Int)
    case invalidWordCount(expected: Int, actual: Int)
    case invalidChannelCount(expected: Int, actual: Int)
    case mismatchedChannelDimensions
    case emptyShape
    case unsupportedByBackend(String)
    case backendUnavailable(String)
    case invalidPasses(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidDimensions(let cols, let rows):
            return "Invalid image dimensions \(cols)×\(rows)."
        case .invalidPixelCount(let expected, let actual):
            return "Pixel buffer length \(actual) does not match expected \(expected)."
        case .invalidWordCount(let expected, let actual):
            return "Packed-word buffer length \(actual) does not match expected \(expected)."
        case .invalidChannelCount(let expected, let actual):
            return "Expected \(expected) channel(s); received \(actual)."
        case .mismatchedChannelDimensions:
            return "Channel planes must share a common (cols, rows)."
        case .emptyShape:
            return "Shape mask must contain at least one active cell."
        case .unsupportedByBackend(let reason):
            return "Operation not supported by this backend: \(reason)."
        case .backendUnavailable(let reason):
            return "Backend unavailable: \(reason)."
        case .invalidPasses(let n):
            return "Number of passes must be ≥ 1 (received \(n))."
        }
    }
}
