/// Stable dispatch token identifying the AlgoCV frontend method an operator
/// invokes. The `rawValue` participates in the operator signature, so a case
/// can never be renamed once shipped.
///
/// Cases are versioned by *behaviour*, not by current Swift method names —
/// once an operator with `call = .applyKernelZeroSumImage8Bit` has a
/// signature, that signature is frozen even if the underlying Swift function
/// is renamed.
public enum OperatorCall: String, Codable, Sendable, CaseIterable {
    // Implemented in AlgoCV today.
    case applyKernelUnitSumImage8Bit
    case applyKernelZeroSumImage8Bit
    case applyKernelUnitSumImage4Bit
    case applyKernelZeroSumImage4Bit
    case filterImage8BitNonlinear
    case filterImage4BitNonlinear
    case erodeImageMono
    case dilateImageMono
    case openImageMono
    case closeImageMono

    // One case each: the bound ColorSpace parameter is what distinguishes
    // a Split-into-HSV operator from a Split-into-CMYK operator. The output
    // slot list of any individual operator instance is fixed (no variadics);
    // its cardinality just happens to equal the bound space.channelCount.
    case splitImageRGB
    case composeImageRGB

    // Reserved — call sites not yet implemented in AlgoCV but reserved here
    // so signatures remain stable when they land.
    case cropImage8Bit
    case resampleImage8Bit
    case reflectImage8Bit
    case invertImage8Bit
    case histogramOfImage8Bit
    case histogramEqualise
    case histogramThreshold
    case addImage8Bit
    case subtractImage8Bit
    case bitwiseAndImageMono
    case bitwiseOrImageMono
    case bitwiseXorImageMono
}

extension OperatorCall {
    /// Validates that the supplied parameter / slot lists match this call's
    /// schema. Some calls have parameter-dependent slot lists (notably
    /// `splitImageRGB` / `composeImageRGB`, where the bound `ColorSpace`
    /// determines the channel count); for those calls the validator inspects
    /// the parameter values.
    func validate(
        parameters: [NamedParameter],
        inputs: [OperatorSlot],
        outputs: [OperatorSlot]
    ) throws {
        switch self {
        case .applyKernelUnitSumImage8Bit:
            try requireParameters(parameters, [.kernelDC1])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .applyKernelZeroSumImage8Bit:
            try requireParameters(parameters, [.kernelDC0])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .applyKernelUnitSumImage4Bit:
            try requireParameters(parameters, [.kernelDC1])
            try requireInputs(inputs, [.image4Bit])
            try requireOutputs(outputs, [.image4Bit])
        case .applyKernelZeroSumImage4Bit:
            try requireParameters(parameters, [.kernelDC0])
            try requireInputs(inputs, [.image4Bit])
            try requireOutputs(outputs, [.image4Bit])

        case .filterImage8BitNonlinear:
            try requireParameters(parameters, [.shape, .nonlinear])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .filterImage4BitNonlinear:
            try requireParameters(parameters, [.shape, .nonlinear])
            try requireInputs(inputs, [.image4Bit])
            try requireOutputs(outputs, [.image4Bit])

        case .erodeImageMono, .dilateImageMono, .openImageMono, .closeImageMono:
            try requireParameters(parameters, [.shape, .count])
            try requireInputs(inputs, [.imageMono])
            try requireOutputs(outputs, [.imageMono])

        case .splitImageRGB:
            let space = try requireColorSpaceParameter(parameters)
            try requireInputs(inputs, [.imageRGB])
            try requireOutputs(
                outputs,
                Array(repeating: .image8Bit, count: space.channelCount)
            )
        case .composeImageRGB:
            let space = try requireColorSpaceParameter(parameters)
            try requireInputs(
                inputs,
                Array(repeating: .image8Bit, count: space.channelCount)
            )
            try requireOutputs(outputs, [.imageRGB])

        // Reserved cases — schemas defined for future use.
        case .cropImage8Bit:
            try requireParameters(parameters, [.size, .size])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .resampleImage8Bit:
            try requireParameters(parameters, [.size, .label])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .reflectImage8Bit:
            try requireParameters(parameters, [.label])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .invertImage8Bit:
            try requireParameters(parameters, [])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .histogramOfImage8Bit:
            try requireParameters(parameters, [])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.histogram])
        case .histogramEqualise:
            try requireParameters(parameters, [])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .histogramThreshold:
            try requireParameters(parameters, [.gray])
            try requireInputs(inputs, [.image8Bit])
            try requireOutputs(outputs, [.imageMono])
        case .addImage8Bit, .subtractImage8Bit:
            try requireParameters(parameters, [])
            try requireInputs(inputs, [.image8Bit, .image8Bit])
            try requireOutputs(outputs, [.image8Bit])
        case .bitwiseAndImageMono, .bitwiseOrImageMono, .bitwiseXorImageMono:
            try requireParameters(parameters, [])
            try requireInputs(inputs, [.imageMono, .imageMono])
            try requireOutputs(outputs, [.imageMono])
        }
    }

    private func requireParameters(_ parameters: [NamedParameter], _ expected: [ParameterKind]) throws {
        guard parameters.count == expected.count else {
            throw OperatorValidationError.mismatchedCallSchema(
                call: self,
                reason: "expected \(expected.count) parameter(s), got \(parameters.count)"
            )
        }
        for (i, (actual, kind)) in zip(parameters, expected).enumerated() where actual.value.kind != kind {
            throw OperatorValidationError.mismatchedCallSchema(
                call: self,
                reason: "parameter \(i) expected \(kind.rawValue), got \(actual.value.kind.rawValue)"
            )
        }
    }

    private func requireInputs(_ inputs: [OperatorSlot], _ expected: [DataKind]) throws {
        try requireSlots(inputs, expected, label: "input")
    }

    private func requireOutputs(_ outputs: [OperatorSlot], _ expected: [DataKind]) throws {
        try requireSlots(outputs, expected, label: "output")
    }

    private func requireSlots(_ slots: [OperatorSlot], _ expected: [DataKind], label: String) throws {
        guard slots.count == expected.count else {
            throw OperatorValidationError.mismatchedCallSchema(
                call: self,
                reason: "expected \(expected.count) \(label) slot(s), got \(slots.count)"
            )
        }
        for (i, (actual, kind)) in zip(slots, expected).enumerated() where actual.kind != kind {
            throw OperatorValidationError.mismatchedCallSchema(
                call: self,
                reason: "\(label) slot \(i) expected \(kind.rawValue), got \(actual.kind.rawValue)"
            )
        }
    }

    private func requireColorSpaceParameter(_ parameters: [NamedParameter]) throws -> ColorSpace {
        guard parameters.count == 1 else {
            throw OperatorValidationError.mismatchedCallSchema(
                call: self,
                reason: "expected 1 parameter, got \(parameters.count)"
            )
        }
        guard case .colorSpace(let space) = parameters[0].value else {
            throw OperatorValidationError.mismatchedCallSchema(
                call: self,
                reason: "parameter 0 expected \(ParameterKind.color.rawValue), got \(parameters[0].value.kind.rawValue)"
            )
        }
        return space
    }
}
