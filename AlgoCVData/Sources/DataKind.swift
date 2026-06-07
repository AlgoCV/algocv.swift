/// Type tag for operator input / output slots. Identifies the AlgoCVData value
/// type that flows through the slot at runtime. Closed enum: adding a new
/// slot type is a deliberate API change with compile-time fan-out.
public enum DataKind: String, Codable, Sendable, Equatable, CaseIterable {
    case imageRGB
    case image8Bit
    case image4Bit
    case imageMono
    // Reserved for the next phase — placeholders so adding them later does
    // not perturb the rawValues that already participate in operator signatures.
    case histogram
    case spectrum8Bit
    case spectrum4Bit
    case variable
}
