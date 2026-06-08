/// Content-addressable description of a single call into the AlgoCV frontend.
///
/// An `Operator` captures the dispatch token (`call`), the fixed parameter
/// bindings (`parameters`), and the ordered input / output slot lists.
/// Variable parameters are modelled as input slots, not as parameters.
///
/// The `signature` is the operator's identity: an `FNV1a` digest over `call`,
/// the ordered parameter payloads (count + discriminator + canonical bytes),
/// and the ordered slot kind lists (count + kinds). It deliberately omits
/// `name`, `details`, `kind`, `subKind`, parameter names, and slot names —
/// two operators are the same iff they invoke the same call with the same
/// bindings and the same typed slot lists, regardless of how they are
/// catalogued or labelled.
public struct Operator: Codable, Equatable, Sendable, Identifiable {
    public var id: UInt64 {
        Self.computeSignature(
            call: call,
            parameters: parameters,
            inputs: inputs,
            outputs: outputs
        )
    }

    public let name: String
    public let details: String?
    public let kind: OperatorKind
    public let subKind: OperatorSubKind?
    public let call: OperatorCall
    public let parameters: [NamedParameter]
    public let inputs: [OperatorSlot]
    public let outputs: [OperatorSlot]

    private enum CodingKeys: String, CodingKey {
        case name
        case details
        case kind
        case subKind
        case call
        case parameters
        case inputs
        case outputs
    }
    
    public init(
        name: String,
        details: String? = nil,
        kind: OperatorKind,
        subKind: OperatorSubKind? = nil,
        call: OperatorCall,
        parameters: [NamedParameter] = [],
        inputs: [OperatorSlot],
        outputs: [OperatorSlot]
    ) throws {
        try Self.validateKind(kind, subKind: subKind)
        try call.validate(parameters: parameters, inputs: inputs, outputs: outputs)
        self.name = name
        self.details = details
        self.kind = kind
        self.subKind = subKind
        self.call = call
        self.parameters = parameters
        self.inputs = inputs
        self.outputs = outputs
    }
    
    private static func validateKind(_ kind: OperatorKind, subKind: OperatorSubKind?) throws {
        let allowed = kind.allowedSubKinds
        if allowed.isEmpty {
            guard subKind == nil else {
                throw OperatorValidationError.invalidSubKind(kind: kind, subKind: subKind)
            }
        } else {
            guard let subKind, allowed.contains(subKind) else {
                throw OperatorValidationError.invalidSubKind(kind: kind, subKind: subKind)
            }
        }
    }

    static func computeSignature(
        call: OperatorCall,
        parameters: [NamedParameter],
        inputs: [OperatorSlot],
        outputs: [OperatorSlot]
    ) -> UInt64 {
        var hasher = FNV1a()
        hasher.mix("operator")
        hasher.mix(call.rawValue)
        hasher.mix(UInt32(parameters.count))
        for parameter in parameters {
            parameter.value.mix(into: &hasher)
        }
        hasher.mix(UInt32(inputs.count))
        for slot in inputs {
            hasher.mix(slot.kind.rawValue)
        }
        hasher.mix(UInt32(outputs.count))
        for slot in outputs {
            hasher.mix(slot.kind.rawValue)
        }
        return hasher.digest
    }
}
