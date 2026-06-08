import AlgoCVData

public extension Image8Bit {
    /// Builds a 256-bin grayscale histogram from this image.
    func histogram(backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Histogram {
        try await backend.histogram(of: self)
    }
}
