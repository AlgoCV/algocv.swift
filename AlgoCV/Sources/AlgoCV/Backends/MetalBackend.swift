import AlgoCVData
import AlgoCVMetal
import Metal

struct MetalBackend: AlgoCVBackend {
    let engine: AlgoCVMetalEngine

    init?() {
        guard let engine = AlgoCVMetalEngine() else { return nil }
        self.engine = engine
    }

    // MARK: - Grid dispatch helper

    private func dispatch2D(_ encoder: MTLComputeCommandEncoder,
                            pso: MTLComputePipelineState,
                            width: Int,
                            height: Int) {
        let tw = min(pso.threadExecutionWidth, width)
        let th = min(max(pso.maxTotalThreadsPerThreadgroup / tw, 1), height)
        let threadsPerThreadgroup = MTLSize(width: tw, height: th, depth: 1)
        let threadsPerGrid = MTLSize(width: width, height: height, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func dispatch1D(_ encoder: MTLComputeCommandEncoder,
                            pso: MTLComputePipelineState,
                            count: Int) {
        let tw = min(pso.maxTotalThreadsPerThreadgroup, count)
        let threadsPerThreadgroup = MTLSize(width: tw, height: 1, depth: 1)
        let threadsPerGrid = MTLSize(width: count, height: 1, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func commit(_ buffer: MTLCommandBuffer) {
        buffer.commit()
        buffer.waitUntilCompleted()
    }

    // MARK: - 8-bit grayvalue convolution

    func apply(_ kernel: KernelZeroSum, to image: Image8Bit) async throws -> Image8Bit {
        try convolveZeroSum(kernel: kernel, source: image)
    }

    func apply(_ kernel: KernelUnitSum, to image: Image8Bit) async throws -> Image8Bit {
        try convolveUnitSum(kernel: kernel, source: image)
    }

    private func convolveZeroSum(kernel: KernelZeroSum, source: Image8Bit) throws -> Image8Bit {
        let device = engine.device
        let src = try source.toMetalBuffer(device: device)
        let dst = try Image8Bit.makeDestinationBuffer(cols: source.cols, rows: source.rows, device: device)
        let weights = try kernel.toMetalBuffer(device: device)

        var params = ConvolutionParams(cols: UInt32(source.cols),
                                       rows: UInt32(source.rows),
                                       kCols: UInt32(kernel.colCount),
                                       kRows: UInt32(kernel.rowCount),
                                       denominator: 0)

        guard let cb = engine.queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else {
            throw AlgoCVError.backendUnavailable("Failed to make Metal command buffer/encoder.")
        }
        enc.setComputePipelineState(engine.convolveZeroSumPSO)
        enc.setBuffer(src, offset: 0, index: 0)
        enc.setBuffer(dst, offset: 0, index: 1)
        enc.setBuffer(weights, offset: 0, index: 2)
        enc.setBytes(&params, length: MemoryLayout<ConvolutionParams>.stride, index: 3)
        dispatch2D(enc, pso: engine.convolveZeroSumPSO, width: Int(source.cols), height: Int(source.rows))
        enc.endEncoding()
        commit(cb)
        return try Image8Bit(dst, cols: source.cols, rows: source.rows)
    }

    private func convolveUnitSum(kernel: KernelUnitSum, source: Image8Bit) throws -> Image8Bit {
        let device = engine.device
        let src = try source.toMetalBuffer(device: device)
        let dst = try Image8Bit.makeDestinationBuffer(cols: source.cols, rows: source.rows, device: device)
        let weights = try kernel.toMetalBuffer(device: device)

        var params = ConvolutionParams(cols: UInt32(source.cols),
                                       rows: UInt32(source.rows),
                                       kCols: UInt32(kernel.colCount),
                                       kRows: UInt32(kernel.rowCount),
                                       denominator: kernel.denominator)

        guard let cb = engine.queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else {
            throw AlgoCVError.backendUnavailable("Failed to make Metal command buffer/encoder.")
        }
        enc.setComputePipelineState(engine.convolveUnitSumPSO)
        enc.setBuffer(src, offset: 0, index: 0)
        enc.setBuffer(dst, offset: 0, index: 1)
        enc.setBuffer(weights, offset: 0, index: 2)
        enc.setBytes(&params, length: MemoryLayout<ConvolutionParams>.stride, index: 3)
        dispatch2D(enc, pso: engine.convolveUnitSumPSO, width: Int(source.cols), height: Int(source.rows))
        enc.endEncoding()
        commit(cb)
        return try Image8Bit(dst, cols: source.cols, rows: source.rows)
    }

    // MARK: - 4-bit grayvalue (expand → 8-bit Metal → re-quantize)

    func apply(_ kernel: KernelZeroSum, to image: Image4Bit) async throws -> Image4Bit {
        let gray = try expandTo8Bit(image)
        let filtered = try convolveZeroSum(kernel: kernel, source: gray)
        return try quantizeTo4Bit(filtered, cols: image.cols, rows: image.rows)
    }

    func apply(_ kernel: KernelUnitSum, to image: Image4Bit) async throws -> Image4Bit {
        let gray = try expandTo8Bit(image)
        let filtered = try convolveUnitSum(kernel: kernel, source: gray)
        return try quantizeTo4Bit(filtered, cols: image.cols, rows: image.rows)
    }

    private func expandTo8Bit(_ image: Image4Bit) throws -> Image8Bit {
        var pixels = [UInt8](); pixels.reserveCapacity(Int(image.cols) * Int(image.rows))
        let packedRow = (Int(image.cols) + 1) / 2
        for r in 0..<Int(image.rows) {
            for c in 0..<Int(image.cols) {
                let byte = image.pixels[r * packedRow + c / 2]
                let nibble: UInt8 = (c % 2 == 0) ? (byte >> 4) : (byte & 0x0F)
                pixels.append(nibble * 17)   // 4-bit nibble replication: 0…15 → {0,17,…,255}
            }
        }
        return try Image8Bit(cols: image.cols, rows: image.rows, pixels: pixels)
    }

    private func quantizeTo4Bit(_ image: Image8Bit, cols: UInt16, rows: UInt16) throws -> Image4Bit {
        let packedRow = (Int(cols) + 1) / 2
        var packed = [UInt8](repeating: 0, count: packedRow * Int(rows))
        for r in 0..<Int(rows) {
            for c in 0..<Int(cols) {
                let nibble = image.pixels[r * Int(cols) + c] >> 4   // top 4 bits
                if c % 2 == 0 {
                    packed[r * packedRow + c / 2] |= nibble << 4
                } else {
                    packed[r * packedRow + c / 2] |= nibble
                }
            }
        }
        return try Image4Bit(cols: cols, rows: rows, pixels: packed)
    }

    // MARK: - Shape + transformation on grayvalue

    func filter(_ image: Image8Bit, through shape: Shape, by t: NonlinearTransformation) async throws -> Image8Bit {
        try shapeFilter(source: image, shape: shape, op: t)
    }

    func filter(_ image: Image4Bit, through shape: Shape, by t: NonlinearTransformation) async throws -> Image4Bit {
        let gray = try expandTo8Bit(image)
        let out  = try shapeFilter(source: gray, shape: shape, op: t)
        return try quantizeTo4Bit(out, cols: image.cols, rows: image.rows)
    }

    private func shapeFilter(source: Image8Bit, shape: Shape, op: NonlinearTransformation) throws -> Image8Bit {
        let device = engine.device
        let src = try source.toMetalBuffer(device: device)
        let dst = try Image8Bit.makeDestinationBuffer(cols: source.cols, rows: source.rows, device: device)
        let mask = try shape.toMetalBuffer(device: device)

        var params = ShapeFilterParams(cols: UInt32(source.cols),
                                       rows: UInt32(source.rows),
                                       kCols: UInt32(shape.cols),
                                       kRows: UInt32(shape.rows),
                                       op: op.metalOpCode)

        guard let cb = engine.queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else {
            throw AlgoCVError.backendUnavailable("Failed to make Metal command buffer/encoder.")
        }
        enc.setComputePipelineState(engine.shapeFilterPSO)
        enc.setBuffer(src, offset: 0, index: 0)
        enc.setBuffer(dst, offset: 0, index: 1)
        enc.setBuffer(mask, offset: 0, index: 2)
        enc.setBytes(&params, length: MemoryLayout<ShapeFilterParams>.stride, index: 3)
        dispatch2D(enc, pso: engine.shapeFilterPSO, width: Int(source.cols), height: Int(source.rows))
        enc.endEncoding()
        commit(cb)
        return try Image8Bit(dst, cols: source.cols, rows: source.rows)
    }

    // MARK: - Binary morphology

    func erode(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        guard passes >= 1 else { throw AlgoCVError.invalidPasses(passes) }
        return try morphology(source: image, shape: shape, passes: passes, pso: engine.erodePSO)
    }

    func dilate(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        guard passes >= 1 else { throw AlgoCVError.invalidPasses(passes) }
        return try morphology(source: image, shape: shape, passes: passes, pso: engine.dilatePSO)
    }

    private func morphology(source: ImageMono, shape: Shape, passes: Int, pso: MTLComputePipelineState) throws -> ImageMono {
        let device = engine.device
        var ping = try source.toMetalBuffer(device: device)
        var pong = try ImageMono.makeDestinationBuffer(cols: source.cols, rows: source.rows, device: device)
        let mask = try shape.toMetalBuffer(device: device)
        let stride = (Int(source.cols) + 31) / 32

        var params = MorphologyParams(cols: UInt32(source.cols),
                                      rows: UInt32(source.rows),
                                      stride: UInt32(stride),
                                      kCols: UInt32(shape.cols),
                                      kRows: UInt32(shape.rows))

        guard let cb = engine.queue.makeCommandBuffer() else {
            throw AlgoCVError.backendUnavailable("Failed to make Metal command buffer.")
        }
        for pass in 0..<passes {
            // Clear pong before each pass (atomic_fetch_or accumulates into it).
            memset(pong.contents(), 0, pong.length)
            guard let enc = cb.makeComputeCommandEncoder() else {
                throw AlgoCVError.backendUnavailable("Failed to make Metal encoder.")
            }
            enc.setComputePipelineState(pso)
            enc.setBuffer(ping, offset: 0, index: 0)
            enc.setBuffer(pong, offset: 0, index: 1)
            enc.setBuffer(mask, offset: 0, index: 2)
            enc.setBytes(&params, length: MemoryLayout<MorphologyParams>.stride, index: 3)
            dispatch2D(enc, pso: pso, width: Int(source.cols), height: Int(source.rows))
            enc.endEncoding()

            if pass < passes - 1 {
                // We need pong to be valid as input to the next pass — swap.
                swap(&ping, &pong)
            }
        }
        commit(cb)
        return try ImageMono(pong, cols: source.cols, rows: source.rows)
    }

    // MARK: - Channel decompose / compose

    func split(_ image: ImageRGB, into space: ColorSpace) async throws -> [Image8Bit] {
        let device = engine.device
        let src = try image.toMetalBuffer(device: device)
        let pixelCount = Int(image.cols) * Int(image.rows)
        let dstLength = pixelCount * space.channelCount
        guard let dst = device.makeBuffer(length: dstLength, options: [.storageModeShared]) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate decompose dest buffer.")
        }
        memset(dst.contents(), 0, dstLength)

        var params = DecomposeParams(cols: UInt32(image.cols),
                                     rows: UInt32(image.rows),
                                     pixelCount: UInt32(pixelCount),
                                     colorSpace: space.metalCode,
                                     channelCount: UInt32(space.channelCount))

        guard let cb = engine.queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else {
            throw AlgoCVError.backendUnavailable("Failed to make Metal command buffer/encoder.")
        }
        enc.setComputePipelineState(engine.channelDecomposePSO)
        enc.setBuffer(src, offset: 0, index: 0)
        enc.setBuffer(dst, offset: 0, index: 1)
        enc.setBytes(&params, length: MemoryLayout<DecomposeParams>.stride, index: 2)
        dispatch1D(enc, pso: engine.channelDecomposePSO, count: pixelCount)
        enc.endEncoding()
        commit(cb)

        let ptr = dst.contents().assumingMemoryBound(to: UInt8.self)
        var planes: [Image8Bit] = []
        for ch in 0..<space.channelCount {
            let slice = UnsafeBufferPointer(start: ptr.advanced(by: ch * pixelCount), count: pixelCount)
            try planes.append(Image8Bit(cols: image.cols, rows: image.rows, pixels: Array(slice)))
        }
        return planes
    }

    // MARK: - Histogram

    func histogram(of image: Image8Bit) async throws -> Histogram {
        throw AlgoCVError.unsupportedByBackend("Metal backend does not implement histogram.")
    }

    func compose(_ channels: [Image8Bit], from space: ColorSpace) async throws -> ImageRGB {
        guard channels.count == space.channelCount else {
            throw AlgoCVError.invalidChannelCount(expected: space.channelCount, actual: channels.count)
        }
        guard let first = channels.first else {
            throw AlgoCVError.invalidChannelCount(expected: space.channelCount, actual: 0)
        }
        for channel in channels where channel.cols != first.cols || channel.rows != first.rows {
            throw AlgoCVError.mismatchedChannelDimensions
        }

        let device = engine.device
        let pixelCount = Int(first.cols) * Int(first.rows)
        let srcLength = pixelCount * space.channelCount
        guard let src = device.makeBuffer(length: srcLength, options: [.storageModeShared]) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate compose src buffer.")
        }
        let srcPtr = src.contents().assumingMemoryBound(to: UInt8.self)
        for (i, channel) in channels.enumerated() {
            channel.pixels.withUnsafeBufferPointer { buf in
                if let base = buf.baseAddress {
                    srcPtr.advanced(by: i * pixelCount).update(from: base, count: pixelCount)
                }
            }
        }

        let dst = try ImageRGB.makeDestinationBuffer(cols: first.cols, rows: first.rows, device: device)
        var params = ComposeParams(cols: UInt32(first.cols),
                                   rows: UInt32(first.rows),
                                   pixelCount: UInt32(pixelCount),
                                   colorSpace: space.metalCode,
                                   channelCount: UInt32(space.channelCount))

        guard let cb = engine.queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder() else {
            throw AlgoCVError.backendUnavailable("Failed to make Metal command buffer/encoder.")
        }
        enc.setComputePipelineState(engine.channelComposePSO)
        enc.setBuffer(src, offset: 0, index: 0)
        enc.setBuffer(dst, offset: 0, index: 1)
        enc.setBytes(&params, length: MemoryLayout<ComposeParams>.stride, index: 2)
        dispatch1D(enc, pso: engine.channelComposePSO, count: pixelCount)
        enc.endEncoding()
        commit(cb)

        return try ImageRGB(dst, cols: first.cols, rows: first.rows)
    }
}

// MARK: - Param structs shared with the Metal shaders

private struct ConvolutionParams {
    var cols: UInt32
    var rows: UInt32
    var kCols: UInt32
    var kRows: UInt32
    var denominator: UInt32
}

private struct ShapeFilterParams {
    var cols: UInt32
    var rows: UInt32
    var kCols: UInt32
    var kRows: UInt32
    var op: UInt32
}

private struct MorphologyParams {
    var cols: UInt32
    var rows: UInt32
    var stride: UInt32
    var kCols: UInt32
    var kRows: UInt32
}

private struct DecomposeParams {
    var cols: UInt32
    var rows: UInt32
    var pixelCount: UInt32
    var colorSpace: UInt32
    var channelCount: UInt32
}

private struct ComposeParams {
    var cols: UInt32
    var rows: UInt32
    var pixelCount: UInt32
    var colorSpace: UInt32
    var channelCount: UInt32
}
