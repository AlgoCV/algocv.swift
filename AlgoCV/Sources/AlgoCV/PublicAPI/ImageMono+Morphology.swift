public extension ImageMono {
    /// Erodes the foreground by the structuring element `shape`. `passes` ≥ 1
    /// repeats the structuring-element pass.
    func eroded(by shape: Shape,
                passes: Int = 1,
                backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> ImageMono {
        try await backend.erode(self, by: shape, passes: passes)
    }

    /// Dilates the foreground by the structuring element `shape`. `passes` ≥ 1
    /// repeats the structuring-element pass.
    func dilated(by shape: Shape,
                 passes: Int = 1,
                 backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> ImageMono {
        try await backend.dilate(self, by: shape, passes: passes)
    }

    /// Morphological open = erode × passes, then dilate × passes.
    func opened(by shape: Shape,
                passes: Int = 1,
                backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> ImageMono {
        let eroded = try await backend.erode(self, by: shape, passes: passes)
        return try await backend.dilate(eroded, by: shape, passes: passes)
    }

    /// Morphological close = dilate × passes, then erode × passes.
    func closed(by shape: Shape,
                passes: Int = 1,
                backend: AlgoCVBackend = AlgoCV.defaultBackend) async throws -> ImageMono {
        let dilated = try await backend.dilate(self, by: shape, passes: passes)
        return try await backend.erode(dilated, by: shape, passes: passes)
    }
}
