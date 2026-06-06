import AlgoCVData

public extension ImageRGB {
    /// Splits this image into per-channel `Image8Bit`s under `space`.
    /// Returns `space.channelCount` images (3 for everything except `.cmyk`).
    func split(into space: ColorSpace = .rgb,
               backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> [Image8Bit] {
        try await backend.split(self, into: space)
    }

    /// Recomposes per-channel `Image8Bit`s back into an `ImageRGB` under
    /// `space`. The channel count and (cols, rows) must match — throws if not.
    /// Inverse of `split(into:)` for each color space.
    static func recomposed(from channels: [Image8Bit],
                           in space: ColorSpace = .rgb,
                           backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> ImageRGB {
        try await backend.compose(channels, from: space)
    }
}
