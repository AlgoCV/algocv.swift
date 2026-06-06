import AlgoCVData

public extension Image8Bit {
    func applying(_ kernel: KernelZeroSum,
                  backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Image8Bit {
        try await backend.apply(kernel, to: self)
    }

    func applying(_ kernel: KernelUnitSum,
                  backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Image8Bit {
        try await backend.apply(kernel, to: self)
    }

    /// Reduces the neighbourhood selected by `shape` using `transformation`
    /// (min/max/avg/median/hAvg/gAvg/and/or/xor). NOT morphology — the word
    /// "morphology" is reserved for the binary `ImageMono` operations.
    func filtered(through shape: Shape,
                  by transformation: NonlinearTransformation,
                  backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Image8Bit {
        try await backend.filter(self, through: shape, by: transformation)
    }

    /// Convenience: destructures a `KernelNonlinear` into its mask + reduction.
    func applying(_ kernel: KernelNonlinear,
                  backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Image8Bit {
        try await backend.filter(self, through: Shape(kernel), by: kernel.nonlinear)
    }
}
