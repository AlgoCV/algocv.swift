import AlgoCVData

public extension Spectrum8Bit {
    /// Reconstructs the spatial-domain image via inverse 2D Fourier transform.
    func inverseFourier(backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Image8Bit {
        try await backend.inverseFourier(of: self)
    }
}
