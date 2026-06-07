import Foundation
import Testing

@testable import AlgoCVData

@Suite("CVLibrary operators")
struct CVLibraryOperatorTests {
    private func makeOp(name: String = "x") throws -> Operator {
        try Operator(
            name: name,
            kind: .lowpass,
            subKind: .linearBlur,
            call: .applyKernelUnitSumImage8Bit,
            parameters: [
                NamedParameter(
                    name: "kernel",
                    value: .kernelUnitSum(KernelUnitSum(values: [[1]]))
                ),
            ],
            inputs:  [OperatorSlot(name: "source", kind: .image8Bit)],
            outputs: [OperatorSlot(name: "result", kind: .image8Bit)]
        )
    }

    @Test
    func acceptsDistinctOperators() throws {
        _ = try CVLibrary(operators: CVLibrary.standardOperators)
    }

    @Test
    func rejectsDuplicateOperators() throws {
        let op = try makeOp()
        #expect(throws: CVLibraryError.duplicateOperator(signature: op.signature)) {
            try CVLibrary(operators: [op, op])
        }
    }

    @Test
    func duplicateKernelErrorPathUnchanged() {
        let kernel = KernelUnitSum(values: [[1]])
        #expect(throws: CVLibraryError.duplicateKernel(id: kernel.id)) {
            try CVLibrary(unitSumKernels: [kernel, kernel])
        }
    }

    @Test
    func standardOperatorsIsNonEmpty() {
        #expect(!CVLibrary.standard.operators.isEmpty)
    }
}
