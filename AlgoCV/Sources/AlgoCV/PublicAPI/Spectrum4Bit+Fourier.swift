import AlgoCVData

public extension Spectrum4Bit {
    /// Reconstructs the spatial-domain image via inverse 2D Fourier transform.
    /// Currently throws `AlgoCVError.unsupportedByBackend` because ImPro's
    /// `PaletteSpectrum` does not expose write access — there is no path to
    /// lift a Swift `Spectrum4Bit` value back into ImPro `Freq16` storage.
    func inverseFourier(backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> Image4Bit {
        try await backend.inverseFourier(of: self)
    }
}
