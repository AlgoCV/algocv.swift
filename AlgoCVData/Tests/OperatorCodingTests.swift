import Foundation
import Testing

@testable import AlgoCVData

@Suite("Operator coding")
struct OperatorCodingTests {
    @Test
    func parameterEachCaseRoundTrips() throws {
        let kernelUnit = KernelUnitSum(values: [[1, 1], [1, 1]])
        let kernelZero = KernelZeroSum(values: [[1, -1]])
        let kernelNonlinear = KernelNonlinear(values: [[true, true]], nonlinear: .max)
        let shape = try Shape([[true, false], [false, true]])

        let cases: [OperatorParameter] = [
            .kernelUnitSum(kernelUnit),
            .kernelZeroSum(kernelZero),
            .kernelNonlinear(kernelNonlinear),
            .shape(shape),
            .colorSpace(.cmyk),
            .nonlinearTransformation(.median),
            .gray(0x42),
            .count(1234),
            .size(width: 640, height: 480),
            .flag(true),
            .label("hello"),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for parameter in cases {
            let data = try encoder.encode(parameter)
            let decoded = try decoder.decode(OperatorParameter.self, from: data)
            #expect(decoded == parameter)
        }
    }

    @Test
    func operatorRoundTripsAndRecomputesSignature() throws {
        let op = try Operator(
            name: "Gaussian blur 3×3",
            details: "test fixture",
            kind: .lowpass,
            subKind: .linearBlur,
            call: .applyKernelUnitSumImage8Bit,
            parameters: [
                NamedParameter(
                    name: "kernel",
                    value: .kernelUnitSum(KernelUnitSum(values: [
                        [1, 2, 1],
                        [2, 4, 2],
                        [1, 2, 1],
                    ]))
                ),
            ],
            inputs:  [OperatorSlot(name: "source", kind: .image8Bit)],
            outputs: [OperatorSlot(name: "result", kind: .image8Bit)]
        )
        let data = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(Operator.self, from: data)
        #expect(decoded == op)
        #expect(decoded.signature == op.signature)
    }

    @Test
    func cvLibraryRoundTrips() throws {
        let original = CVLibrary.standard
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CVLibrary.self, from: data)
        #expect(decoded == original)
        #expect(decoded.operators.count == original.operators.count)
    }
}
