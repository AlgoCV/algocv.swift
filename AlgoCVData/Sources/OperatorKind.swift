/// Top-level taxonomy for operators. Used for catalogue grouping and UI; does
/// not participate in operator signatures.
public enum OperatorKind: String, CaseIterable, Codable, Sendable, Equatable {
    case colorSpace
    case histogram
    case transformation
    case highpass
    case lowpass
    case morphology
    case combinator
}

/// Second-level taxonomy. Each subkind belongs to exactly one kind; the
/// `OperatorKind.allowedSubKinds` table enforces the mapping. Kinds without a
/// subkind (`.transformation`, `.morphology`) accept `nil`.
public enum OperatorSubKind: String, CaseIterable, Codable, Sendable, Equatable {
    case channelSplit
    case channelComposition
    case spaceTransformation

    case histogramTransformation
    case histogramFilter
    case histogramCombinator

    case sharpening
    case edgeDetection

    case linearBlur
    case nonlinearBlur

    case arithmetic
    case bitwise
}

public extension OperatorKind {
    /// Legal subkinds for this kind. An empty set means this kind takes no
    /// subkind (its operator must use `subKind: nil`).
    var allowedSubKinds: Set<OperatorSubKind> {
        switch self {
        case .colorSpace:
            [.channelSplit, .channelComposition, .spaceTransformation]
        case .histogram:
            [.histogramTransformation, .histogramFilter, .histogramCombinator]
        case .transformation:
            []
        case .highpass:
            [.sharpening, .edgeDetection]
        case .lowpass:
            [.linearBlur, .nonlinearBlur]
        case .morphology:
            []
        case .combinator:
            [.arithmetic, .bitwise]
        }
    }
}
