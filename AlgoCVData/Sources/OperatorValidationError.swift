import Foundation

public enum OperatorValidationError: Error, Equatable, LocalizedError, Sendable {
    case invalidSubKind(kind: OperatorKind, subKind: OperatorSubKind?)
    case mismatchedCallSchema(call: OperatorCall, reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidSubKind(let kind, let subKind):
            if let subKind {
                return "Operator subkind \(subKind.rawValue) is not legal for kind \(kind.rawValue)."
            } else {
                return "Operator kind \(kind.rawValue) requires a subkind."
            }
        case .mismatchedCallSchema(let call, let reason):
            return "Operator call \(call.rawValue) failed schema validation: \(reason)."
        }
    }
}
