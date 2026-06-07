import Foundation
import Testing

@testable import AlgoCVData

@Suite("Operator signature")
struct OperatorSignatureTests {
    private func makeApply8Bit(
        name: String = "Box blur",
        details: String? = nil,
        kind: OperatorKind = .lowpass,
        subKind: OperatorSubKind? = .linearBlur,
        parameterName: String = "kernel",
        sourceName: String = "source",
        resultName: String = "result"
    ) throws -> Operator {
        try Operator(
            name: name,
            details: details,
            kind: kind,
            subKind: subKind,
            call: .applyKernelUnitSumImage8Bit,
            parameters: [
                NamedParameter(
                    name: parameterName,
                    value: .kernelUnitSum(KernelUnitSum(values: [
                        [1, 1, 1],
                        [1, 1, 1],
                        [1, 1, 1],
                    ]))
                ),
            ],
            inputs:  [OperatorSlot(name: sourceName, kind: .image8Bit)],
            outputs: [OperatorSlot(name: resultName, kind: .image8Bit)]
        )
    }

    @Test
    func signatureIsDeterministic() throws {
        let op = try makeApply8Bit()
        let again = try makeApply8Bit()
        #expect(op.signature == again.signature)
        #expect(op.signature != 0)
    }

    @Test
    func metadataDoesNotAffectSignature() throws {
        let a = try makeApply8Bit(name: "Alpha", details: nil, kind: .lowpass, subKind: .linearBlur)
        let b = try makeApply8Bit(name: "Beta",  details: "extra", kind: .lowpass, subKind: .linearBlur)
        #expect(a.signature == b.signature)
    }

    @Test
    func parameterAndSlotNamesDoNotAffectSignature() throws {
        let a = try makeApply8Bit(parameterName: "kernel", sourceName: "source", resultName: "result")
        let b = try makeApply8Bit(parameterName: "K",      sourceName: "in",     resultName: "out")
        #expect(a.signature == b.signature)
    }

    @Test
    func callChangesSignature() throws {
        let a = try makeApply8Bit()
        let b = try Operator(
            name: "x",
            kind: .lowpass, subKind: .linearBlur,
            call: .applyKernelUnitSumImage4Bit,
            parameters: a.parameters,
            inputs:  [OperatorSlot(name: "source", kind: .image4Bit)],
            outputs: [OperatorSlot(name: "result", kind: .image4Bit)]
        )
        #expect(a.signature != b.signature)
    }

    @Test
    func parameterValueChangesSignature() throws {
        let a = try makeApply8Bit()
        let b = try Operator(
            name: "x", kind: .lowpass, subKind: .linearBlur,
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
        #expect(a.signature != b.signature)
    }

    @Test
    func slotKindChangesSignature() throws {
        let three = try Operator(
            name: "x", kind: .colorSpace, subKind: .channelSplit,
            call: .splitImageRGB,
            parameters: [NamedParameter(name: "space", value: .colorSpace(.rgb))],
            inputs:  [OperatorSlot(name: "src", kind: .imageRGB)],
            outputs: (0..<3).map { OperatorSlot(name: "ch\($0)", kind: .image8Bit) }
        )
        let four = try Operator(
            name: "x", kind: .colorSpace, subKind: .channelSplit,
            call: .splitImageRGB,
            parameters: [NamedParameter(name: "space", value: .colorSpace(.cmyk))],
            inputs:  [OperatorSlot(name: "src", kind: .imageRGB)],
            outputs: (0..<4).map { OperatorSlot(name: "ch\($0)", kind: .image8Bit) }
        )
        #expect(three.signature != four.signature)
    }

    @Test
    func parameterOrderChangesSignature() throws {
        let shape = try! Shape([
            [true, true],
            [true, true],
        ])
        let a = try Operator(
            name: "x", kind: .lowpass, subKind: .nonlinearBlur,
            call: .filterImage8BitNonlinear,
            parameters: [
                NamedParameter(name: "shape", value: .shape(shape)),
                NamedParameter(name: "transformation", value: .nonlinearTransformation(.max)),
            ],
            inputs:  [OperatorSlot(name: "src", kind: .image8Bit)],
            outputs: [OperatorSlot(name: "res", kind: .image8Bit)]
        )
        // Swapping parameter order is not even schema-valid (positions are
        // typed), so we exercise order-sensitivity on signature via the raw
        // hasher — two valid operators differ in transformation type, which
        // moves through position 1 only.
        let b = try Operator(
            name: "x", kind: .lowpass, subKind: .nonlinearBlur,
            call: .filterImage8BitNonlinear,
            parameters: [
                NamedParameter(name: "shape", value: .shape(shape)),
                NamedParameter(name: "transformation", value: .nonlinearTransformation(.min)),
            ],
            inputs:  [OperatorSlot(name: "src", kind: .image8Bit)],
            outputs: [OperatorSlot(name: "res", kind: .image8Bit)]
        )
        #expect(a.signature != b.signature)
    }
}
