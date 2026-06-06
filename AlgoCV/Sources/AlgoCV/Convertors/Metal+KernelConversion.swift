import AlgoCVData
import Metal

extension KernelZeroSum {
    func toMetalBuffer(device: MTLDevice) throws -> MTLBuffer {
        let flat: [Int8] = values.flatMap { $0 }
        guard let buffer = flat.withUnsafeBufferPointer({ ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: flat.count, options: [.storageModeShared])
        }) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate MTLBuffer for kernel weights.")
        }
        return buffer
    }
}

extension KernelUnitSum {
    func toMetalBuffer(device: MTLDevice) throws -> MTLBuffer {
        let flat: [UInt8] = values.flatMap { $0 }
        guard let buffer = flat.withUnsafeBufferPointer({ ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: flat.count, options: [.storageModeShared])
        }) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate MTLBuffer for kernel weights.")
        }
        return buffer
    }
}

extension Shape {
    func toMetalBuffer(device: MTLDevice) throws -> MTLBuffer {
        let flat: [UInt8] = mask.flatMap { row in row.map { $0 ? UInt8(1) : UInt8(0) } }
        guard let buffer = flat.withUnsafeBufferPointer({ ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: flat.count, options: [.storageModeShared])
        }) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate MTLBuffer for shape mask.")
        }
        return buffer
    }
}

extension NonlinearTransformation {
    /// Op code consumed by the Metal `shape_filter_gray` kernel.
    var metalOpCode: UInt32 {
        switch self {
        case .max:    return 0
        case .min:    return 1
        case .avg:    return 2
        case .hAvg:   return 3
        case .gAvg:   return 4
        case .median: return 5
        case .and:    return 6
        case .or:     return 7
        case .xor:    return 8
        }
    }
}

extension ColorSpace {
    /// Code consumed by the channel decompose/compose Metal kernels.
    var metalCode: UInt32 {
        switch self {
        case .rgb:    return 0
        case .hsv:    return 1
        case .hsl:    return 2
        case .lab:    return 3
        case .cmy:    return 4
        case .cmyk:   return 5
        case .yuv:    return 6
        case .yDbDr:  return 7
        case .yiq:    return 8
        case .yCbCr:  return 9
        }
    }
}
