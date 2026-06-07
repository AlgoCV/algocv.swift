import Foundation
import Testing

@testable import AlgoCVData

@Suite("Operator signature collisions")
struct OperatorIDCollisionTests {
    @Test
    func standardOperatorsHaveUniqueSignatures() {
        let operators = CVLibrary.standardOperators
        let collisions = Dictionary(grouping: operators, by: \.signature)
            .filter { $0.value.count > 1 }

        if !collisions.isEmpty {
            let report = collisions
                .sorted { $0.key < $1.key }
                .map { entry in
                    let id = String(entry.key, radix: 16, uppercase: true)
                    let names = entry.value
                        .map(\.name)
                        .sorted()
                        .joined(separator: "\n  ")
                    return "0x\(id):\n  \(names)"
                }
                .joined(separator: "\n\n")
            Issue.record("Operator signature collisions found:\n\(report)")
        }

        // Pin the catalogue cardinality so accidental churn is caught in review.
        // 4 unitSum × 2 image bit-depths +
        // 8 zeroSum × 2 image bit-depths +
        // 6 nonlinear × 2 image bit-depths +
        // 4 morphology calls × 2 shapes +
        // 10 color spaces × 2 (split + compose)
        // = 8 + 16 + 12 + 8 + 20 = 64
        #expect(operators.count == 64)
        #expect(collisions.isEmpty)
    }
}
