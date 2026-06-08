import AlgoCVData

public extension Image8Bit {
    /// Computes the 2D forward Fourier transform of this image.
    func fourier(backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Spectrum8Bit {
        try await backend.fourier(of: self)
    }
}
