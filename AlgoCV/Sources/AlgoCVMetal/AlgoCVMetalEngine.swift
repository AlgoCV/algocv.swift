import Foundation
import Metal

public final class AlgoCVMetalEngine: @unchecked Sendable {
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let library: MTLLibrary

    public let convolveZeroSumPSO: MTLComputePipelineState
    public let convolveUnitSumPSO: MTLComputePipelineState
    public let shapeFilterPSO:     MTLComputePipelineState
    public let erodePSO:           MTLComputePipelineState
    public let dilatePSO:          MTLComputePipelineState
    public let channelDecomposePSO: MTLComputePipelineState
    public let channelComposePSO:   MTLComputePipelineState

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        guard let queue = device.makeCommandQueue() else { return nil }
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else { return nil }

        func pso(_ name: String) -> MTLComputePipelineState? {
            guard let fn = library.makeFunction(name: name) else { return nil }
            return try? device.makeComputePipelineState(function: fn)
        }
        guard
            let convolveZero = pso("convolve_zero_sum"),
            let convolveUnit = pso("convolve_unit_sum"),
            let shape       = pso("shape_filter_gray"),
            let erode       = pso("morph_erode"),
            let dilate      = pso("morph_dilate"),
            let decompose   = pso("channel_decompose"),
            let compose     = pso("channel_compose")
        else { return nil }

        self.device  = device
        self.queue   = queue
        self.library = library
        self.convolveZeroSumPSO  = convolveZero
        self.convolveUnitSumPSO  = convolveUnit
        self.shapeFilterPSO      = shape
        self.erodePSO            = erode
        self.dilatePSO           = dilate
        self.channelDecomposePSO = decompose
        self.channelComposePSO   = compose
    }
}
