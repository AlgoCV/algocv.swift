public extension CVLibrary {
    /// Initial operator catalogue built on top of the standard kernel library.
    /// One operator per `(call, fixed binding)` pair the runtime currently
    /// supports. Distinctness is exercised by `OperatorIDCollisionTests`.
    static var standardOperators: [Operator] {
        unitSumConvolutionOperators(on: .image8Bit) +
        unitSumConvolutionOperators(on: .image4Bit) +
        zeroSumConvolutionOperators(on: .image8Bit) +
        zeroSumConvolutionOperators(on: .image4Bit) +
        nonlinearFilterOperators(on: .image8Bit) +
        nonlinearFilterOperators(on: .image4Bit) +
        morphologyOperators() +
        colorSpaceOperators()
    }

    private static func unitSumConvolutionOperators(on imageKind: DataKind) -> [Operator] {
        let call: OperatorCall = imageKind == .image8Bit
            ? .applyKernelUnitSumImage8Bit
            : .applyKernelUnitSumImage4Bit
        return standardUnitSumKernels.enumerated().map { index, kernel in
            try! Operator(
                name: "Lowpass convolution #\(index) on \(imageKind.rawValue)",
                kind: .lowpass,
                subKind: .linearBlur,
                call: call,
                parameters: [NamedParameter(name: "kernel", value: .kernelUnitSum(kernel))],
                inputs:  [OperatorSlot(name: "source", kind: imageKind)],
                outputs: [OperatorSlot(name: "result", kind: imageKind)]
            )
        }
    }

    private static func zeroSumConvolutionOperators(on imageKind: DataKind) -> [Operator] {
        let call: OperatorCall = imageKind == .image8Bit
            ? .applyKernelZeroSumImage8Bit
            : .applyKernelZeroSumImage4Bit
        return standardZeroSumKernels.enumerated().map { index, kernel in
            try! Operator(
                name: "Highpass convolution #\(index) on \(imageKind.rawValue)",
                kind: .highpass,
                subKind: .edgeDetection,
                call: call,
                parameters: [NamedParameter(name: "kernel", value: .kernelZeroSum(kernel))],
                inputs:  [OperatorSlot(name: "source", kind: imageKind)],
                outputs: [OperatorSlot(name: "result", kind: imageKind)]
            )
        }
    }

    private static func nonlinearFilterOperators(on imageKind: DataKind) -> [Operator] {
        let call: OperatorCall = imageKind == .image8Bit
            ? .filterImage8BitNonlinear
            : .filterImage4BitNonlinear
        return standardNonlinearKernels.enumerated().map { index, kernel in
            try! Operator(
                name: "Nonlinear filter #\(index) on \(imageKind.rawValue)",
                kind: .lowpass,
                subKind: .nonlinearBlur,
                call: call,
                parameters: [
                    NamedParameter(name: "shape", value: .shape(Shape(kernel))),
                    NamedParameter(name: "transformation", value: .nonlinearTransformation(kernel.nonlinear)),
                ],
                inputs:  [OperatorSlot(name: "source", kind: imageKind)],
                outputs: [OperatorSlot(name: "result", kind: imageKind)]
            )
        }
    }

    private static func morphologyOperators() -> [Operator] {
        let shapes: [(name: String, shape: Shape)] = [
            ("box 3×3", try! Shape(Array(
                repeating: Array(repeating: true, count: 3),
                count: 3
            ))),
            ("cross 3×3", try! Shape([
                [false, true, false],
                [true,  true, true ],
                [false, true, false],
            ])),
        ]
        let calls: [(name: String, call: OperatorCall)] = [
            ("Erode",  .erodeImageMono),
            ("Dilate", .dilateImageMono),
            ("Open",   .openImageMono),
            ("Close",  .closeImageMono),
        ]
        return calls.flatMap { entry in
            shapes.map { shape in
                try! Operator(
                    name: "\(entry.name) by \(shape.name)",
                    kind: .morphology,
                    call: entry.call,
                    parameters: [
                        NamedParameter(name: "shape", value: .shape(shape.shape)),
                        NamedParameter(name: "passes", value: .count(1)),
                    ],
                    inputs:  [OperatorSlot(name: "source", kind: .imageMono)],
                    outputs: [OperatorSlot(name: "result", kind: .imageMono)]
                )
            }
        }
    }

    private static func colorSpaceOperators() -> [Operator] {
        ColorSpace.allCases.flatMap { space -> [Operator] in
            let channelSlots = (0..<space.channelCount).map { index in
                OperatorSlot(name: "channel \(index)", kind: .image8Bit)
            }
            let split = try! Operator(
                name: "Split into \(space.rawValue.uppercased())",
                kind: .colorSpace,
                subKind: .channelSplit,
                call: .splitImageRGB,
                parameters: [NamedParameter(name: "space", value: .colorSpace(space))],
                inputs:  [OperatorSlot(name: "source", kind: .imageRGB)],
                outputs: channelSlots
            )
            let compose = try! Operator(
                name: "Compose from \(space.rawValue.uppercased())",
                kind: .colorSpace,
                subKind: .channelComposition,
                call: .composeImageRGB,
                parameters: [NamedParameter(name: "space", value: .colorSpace(space))],
                inputs:  channelSlots,
                outputs: [OperatorSlot(name: "result", kind: .imageRGB)]
            )
            return [split, compose]
        }
    }
}
