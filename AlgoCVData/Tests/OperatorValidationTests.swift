import Foundation
import Testing

@testable import AlgoCVData

@Suite("Operator validation")
struct OperatorValidationTests {
    private let image8Source = OperatorSlot(name: "source", kind: .image8Bit)
    private let image8Result = OperatorSlot(name: "result", kind: .image8Bit)
    private let imageMonoSource = OperatorSlot(name: "source", kind: .imageMono)
    private let imageMonoResult = OperatorSlot(name: "result", kind: .imageMono)

    private var kernelParam: NamedParameter {
        NamedParameter(name: "kernel", value: .kernelUnitSum(KernelUnitSum(values: [[1]])))
    }

    @Test
    func acceptsValidKindSubKindPair() throws {
        _ = try Operator(
            name: "x",
            kind: .lowpass,
            subKind: .linearBlur,
            call: .applyKernelUnitSumImage8Bit,
            parameters: [kernelParam],
            inputs:  [image8Source],
            outputs: [image8Result]
        )
    }

    @Test
    func rejectsForeignSubKind() {
        #expect(throws: OperatorValidationError.invalidSubKind(kind: .lowpass, subKind: .sharpening)) {
            try Operator(
                name: "x",
                kind: .lowpass,
                subKind: .sharpening,
                call: .applyKernelUnitSumImage8Bit,
                parameters: [kernelParam],
                inputs:  [image8Source],
                outputs: [image8Result]
            )
        }
    }

    @Test
    func requiresNilSubKindForKindsWithoutAny() {
        #expect(throws: OperatorValidationError.invalidSubKind(kind: .morphology, subKind: .arithmetic)) {
            try Operator(
                name: "x",
                kind: .morphology,
                subKind: .arithmetic,
                call: .erodeImageMono,
                parameters: [
                    NamedParameter(
                        name: "shape",
                        value: .shape(try! Shape([[true]]))
                    ),
                    NamedParameter(name: "passes", value: .count(1)),
                ],
                inputs:  [imageMonoSource],
                outputs: [imageMonoResult]
            )
        }
    }

    @Test
    func requiresSubKindWhenKindHasAny() {
        #expect(throws: OperatorValidationError.invalidSubKind(kind: .lowpass, subKind: nil)) {
            try Operator(
                name: "x",
                kind: .lowpass,
                subKind: nil,
                call: .applyKernelUnitSumImage8Bit,
                parameters: [kernelParam],
                inputs:  [image8Source],
                outputs: [image8Result]
            )
        }
    }

    @Test
    func overlappingSlotNamesAreAccepted() throws {
        let op = try Operator(
            name: "x",
            kind: .colorSpace,
            subKind: .channelSplit,
            call: .splitImageRGB,
            parameters: [NamedParameter(name: "space", value: .colorSpace(.rgb))],
            inputs:  [OperatorSlot(name: "source", kind: .imageRGB)],
            outputs: [
                OperatorSlot(name: "ch", kind: .image8Bit),
                OperatorSlot(name: "ch", kind: .image8Bit),
                OperatorSlot(name: "ch", kind: .image8Bit),
            ]
        )
        let other = try Operator(
            name: "x",
            kind: .colorSpace,
            subKind: .channelSplit,
            call: .splitImageRGB,
            parameters: [NamedParameter(name: "space", value: .colorSpace(.rgb))],
            inputs:  [OperatorSlot(name: "src", kind: .imageRGB)],
            outputs: [
                OperatorSlot(name: "red",   kind: .image8Bit),
                OperatorSlot(name: "green", kind: .image8Bit),
                OperatorSlot(name: "blue",  kind: .image8Bit),
            ]
        )
        #expect(op.signature == other.signature)
    }

    @Test
    func rejectsWrongParameterType() {
        #expect(throws: OperatorValidationError.self) {
            try Operator(
                name: "x",
                kind: .lowpass,
                subKind: .linearBlur,
                call: .applyKernelUnitSumImage8Bit,
                parameters: [NamedParameter(name: "kernel", value: .gray(1))],
                inputs:  [image8Source],
                outputs: [image8Result]
            )
        }
    }

    @Test
    func rejectsWrongSlotCount() {
        #expect(throws: OperatorValidationError.self) {
            try Operator(
                name: "x",
                kind: .lowpass,
                subKind: .linearBlur,
                call: .applyKernelUnitSumImage8Bit,
                parameters: [kernelParam],
                inputs:  [image8Source, image8Source],
                outputs: [image8Result]
            )
        }
    }

    @Test
    func rejectsWrongSlotKind() {
        #expect(throws: OperatorValidationError.self) {
            try Operator(
                name: "x",
                kind: .lowpass,
                subKind: .linearBlur,
                call: .applyKernelUnitSumImage8Bit,
                parameters: [kernelParam],
                inputs:  [OperatorSlot(name: "source", kind: .image4Bit)],
                outputs: [image8Result]
            )
        }
    }

    @Test
    func splitChannelCountMatchesColorSpace() throws {
        let cmykOutputs = (0..<4).map { OperatorSlot(name: "ch\($0)", kind: .image8Bit) }
        _ = try Operator(
            name: "x",
            kind: .colorSpace,
            subKind: .channelSplit,
            call: .splitImageRGB,
            parameters: [NamedParameter(name: "space", value: .colorSpace(.cmyk))],
            inputs:  [OperatorSlot(name: "source", kind: .imageRGB)],
            outputs: cmykOutputs
        )

        #expect(throws: OperatorValidationError.self) {
            try Operator(
                name: "x",
                kind: .colorSpace,
                subKind: .channelSplit,
                call: .splitImageRGB,
                parameters: [NamedParameter(name: "space", value: .colorSpace(.cmyk))],
                inputs:  [OperatorSlot(name: "source", kind: .imageRGB)],
                outputs: (0..<3).map { OperatorSlot(name: "ch\($0)", kind: .image8Bit) }
            )
        }
    }
}
