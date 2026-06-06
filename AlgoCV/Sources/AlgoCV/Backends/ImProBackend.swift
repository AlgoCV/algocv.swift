import AlgoCVData
import ImPro

struct ImProBackend: AlgoCVBackend {
    // MARK: - 8-bit grayvalue linear

    func apply(_ kernel: KernelZeroSum, to image: Image8Bit) async throws -> Image8Bit {
        let gray = try image.toImPro()
        let out  = try gray.filtered(try kernel.toImPro())
        return try Image8Bit(out)
    }

    func apply(_ kernel: KernelUnitSum, to image: Image8Bit) async throws -> Image8Bit {
        let gray = try image.toImPro()
        let out  = try gray.filtered(try kernel.toImPro())
        return try Image8Bit(out)
    }

    // MARK: - 4-bit grayvalue linear (native via PaletteImage)

    func apply(_ kernel: KernelZeroSum, to image: Image4Bit) async throws -> Image4Bit {
        let pal = try image.toImPro()
        let out = try pal.filtered(try kernel.toImPro())
        return try Image4Bit(out)
    }

    func apply(_ kernel: KernelUnitSum, to image: Image4Bit) async throws -> Image4Bit {
        let pal = try image.toImPro()
        let out = try pal.filtered(try kernel.toImPro())
        return try Image4Bit(out)
    }

    // MARK: - Shape + transformation on grayvalue (NOT morphology)

    func filter(_ image: Image8Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image8Bit {
        let gray = try image.toImPro()
        let out  = try gray.filtered(try shape.toImProKernel(with: transformation))
        return try Image8Bit(out)
    }

    func filter(_ image: Image4Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image4Bit {
        let pal = try image.toImPro()
        let out = try pal.filtered(try shape.toImProKernel(with: transformation))
        return try Image4Bit(out)
    }

    // MARK: - Binary morphology with passes

    func erode(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        guard passes >= 1 else { throw AlgoCVError.invalidPasses(passes) }
        let s = try shape.toImProBinaryShape()
        var current: ImPro.BinaryImage = try image.toImPro()
        for _ in 0..<passes {
            current = try current.eroded(using: s)
        }
        return try ImageMono(current)
    }

    func dilate(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        guard passes >= 1 else { throw AlgoCVError.invalidPasses(passes) }
        let s = try shape.toImProBinaryShape()
        var current: ImPro.BinaryImage = try image.toImPro()
        for _ in 0..<passes {
            current = try current.dilated(using: s)
        }
        return try ImageMono(current)
    }

    // MARK: - RGB channel decomposition / recomposition

    func split(_ image: ImageRGB, into space: ColorSpace) async throws -> [Image8Bit] {
        let rgb = try image.toImPro()
        let (red, green, blue) = try rgb.split()
        let r = red.readPixels(), g = green.readPixels(), b = blue.readPixels()
        let planes = ImProColorFormulas.decompose(space, r: r, g: g, b: b)
        return try planes.map { try Image8Bit(cols: image.cols, rows: image.rows, pixels: $0) }
    }

    func compose(_ channels: [Image8Bit], from space: ColorSpace) async throws -> ImageRGB {
        guard channels.count == space.channelCount else {
            throw AlgoCVError.invalidChannelCount(expected: space.channelCount, actual: channels.count)
        }
        guard let first = channels.first else {
            throw AlgoCVError.invalidChannelCount(expected: space.channelCount, actual: 0)
        }
        for channel in channels where channel.cols != first.cols || channel.rows != first.rows {
            throw AlgoCVError.mismatchedChannelDimensions
        }

        let (r, g, b) = try ImProColorFormulas.compose(space, channels: channels.map(\.pixels))
        let cols = first.cols, rows = first.rows
        let pixelCount = Int(cols) * Int(rows)
        var bytes = [UInt8](repeating: 0, count: pixelCount * 3)
        for i in 0..<pixelCount {
            bytes[i * 3]     = r[i]
            bytes[i * 3 + 1] = g[i]
            bytes[i * 3 + 2] = b[i]
        }
        return try ImageRGB(cols: cols, rows: rows, pixels: bytes)
    }
}
