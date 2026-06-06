import AlgoCVData

/// Backend abstraction for the computer-vision engine. AlgoCV ships an
/// `ImProBackend` (CPU) and a `MetalBackend` (GPU); applications call into
/// `AlgoCV.defaultBackend` unless they pin a specific one.
public protocol AlgoCVBackend: Sendable {
    // Linear convolution on grayvalue images
    func apply(_ kernel: KernelZeroSum, to image: Image8Bit) async throws -> Image8Bit
    func apply(_ kernel: KernelUnitSum, to image: Image8Bit) async throws -> Image8Bit
    func apply(_ kernel: KernelZeroSum, to image: Image4Bit) async throws -> Image4Bit
    func apply(_ kernel: KernelUnitSum, to image: Image4Bit) async throws -> Image4Bit

    // Shape + transformation on grayvalue images (NOT morphology — that name is
    // reserved for the binary operations). The shape selects which neighbours
    // contribute; the transformation reduces the masked values into the output
    // pixel (min/max/avg/median/hAvg/gAvg/and/or/xor).
    func filter(_ image: Image8Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image8Bit
    func filter(_ image: Image4Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image4Bit

    // Binary morphology. `passes` >= 1 repeats the structuring-element pass.
    func erode (_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono
    func dilate(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono

    // RGB channel decomposition / recomposition. `.rgb` is a pure deinterleave;
    // other spaces apply a color-space formula on top of the R/G/B planes.
    func split  (_ image: ImageRGB, into space: ColorSpace) async throws -> [Image8Bit]
    func compose(_ channels: [Image8Bit], from space: ColorSpace) async throws -> ImageRGB
}

public enum AlgoCV {
    /// Resolved once at first access: Metal if a device is available, else ImPro.
    public static var defaultBackend: AlgoCVBackend { _resolved }

    /// CPU backend using the SIMD-optimized ImPro library. Always available.
    public static let improBackend: AlgoCVBackend = ImProBackend()

    /// GPU backend using Metal compute shaders. `nil` on hosts without a
    /// usable Metal device (e.g. older Macs or Linux).
    public static let metalBackend: AlgoCVBackend? = MetalBackend()

    /// Single-thread CPU reference backend using Apple's vImage, pinned to
    /// one thread via `kvImageDoNotTile`. Only implements linear convolution
    /// on `Image8Bit`; the other backend methods throw
    /// `AlgoCVError.unsupportedByBackend`.
    public static let vImageBackend: AlgoCVBackend = VImageBackend()

    private static let _resolved: AlgoCVBackend = {
        if let metal = metalBackend { return metal }
        return improBackend
    }()
}
