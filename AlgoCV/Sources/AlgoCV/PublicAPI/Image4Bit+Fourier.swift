import AlgoCVData

public extension Image4Bit {
    /// Computes the 2D forward Fourier transform of this image.
    func fourier(backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Spectrum4Bit {
        try await backend.fourier(of: self)
    }
}
