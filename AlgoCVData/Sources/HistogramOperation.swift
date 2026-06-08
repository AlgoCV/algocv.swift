/// Bin-wise binary operations between two 256-bin histograms.
public enum HistogramOperation: String, Sendable, CaseIterable, Codable, Equatable {
    /// Saturating bin-wise addition.
    case addSaturate

    /// Saturating bin-wise subtraction.
    case diffSaturate

    /// Bin-wise bitwise AND.
    case and

    /// Bin-wise bitwise OR.
    case or

    /// Bin-wise bitwise XOR.
    case xor
}
