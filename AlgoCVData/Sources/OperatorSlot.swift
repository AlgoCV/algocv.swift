/// Descriptor for a single positional input or output of an operator.
///
/// `name` is display-only metadata (UI / debugging) and does not participate
/// in the operator's signature. Duplicate or overlapping names within a slot
/// list are permitted — labels like `["red", "green", "blue"]` are fine, but
/// so is `["channel", "channel", "channel"]`.
public struct OperatorSlot: Codable, Equatable, Sendable {
    public let name: String
    public let kind: DataKind

    public init(name: String, kind: DataKind) {
        self.name = name
        self.kind = kind
    }
}
