import AlgoCVData
import Foundation
import opencv2

/// CPU reference backend using OpenCV's `Imgproc.filter2D`. The thread count
/// is pinned to one via `Core.setNumThreads(nthreads: 1)` so this backend
/// serves as a deterministic single-core baseline alongside ImPro and vImage.
///
/// Only 8-bit grayvalue linear convolution is wired up — OpenCV does support
/// the other operations (`erode`, `dilate`, channel ops, etc.), but threading
/// them through the existing `AlgoCVBackend` types is out of scope here; the
/// other methods throw `AlgoCVError.unsupportedByBackend`.
struct OpenCVBackend: AlgoCVBackend {

    init() {
        Core.setNumThreads(nthreads: 1)
    }

    // MARK: - 8-bit grayvalue linear convolution

    func apply(_ kernel: KernelZeroSum, to image: Image8Bit) async throws -> Image8Bit {
        let floats = kernel.values.flatMap { row in row.map { Float($0) } }
        return try filter2D(image: image,
                            kernelFloats: floats,
                            kRows: Int32(kernel.rowCount),
                            kCols: Int32(kernel.colCount))
    }

    func apply(_ kernel: KernelUnitSum, to image: Image8Bit) async throws -> Image8Bit {
        let inv: Float = 1.0 / Float(kernel.denominator)
        let floats = kernel.values.flatMap { row in row.map { Float($0) * inv } }
        return try filter2D(image: image,
                            kernelFloats: floats,
                            kRows: Int32(kernel.rowCount),
                            kCols: Int32(kernel.colCount))
    }

    private func filter2D(image: Image8Bit,
                          kernelFloats: [Float],
                          kRows: Int32,
                          kCols: Int32) throws -> Image8Bit {
        let cols = Int32(image.cols)
        let rows = Int32(image.rows)
        let pixelCount = Int(cols) * Int(rows)

        let src = Mat(rows: rows, cols: cols, type: CvType.CV_8UC1, data: Data(image.pixels))
        let dst = Mat()
        let kernel = Mat(rows: kRows, cols: kCols, type: CvType.CV_32F)
        _ = try kernel.put(row: 0, col: 0, data: kernelFloats)

        // ddepth = -1 → output keeps source depth (CV_8UC1, clamped to [0,255]).
        // Default border policy is BORDER_REFLECT_101; the parity-test cropping
        // already excludes the border, so this matters only for the borders
        // we do not compare.
        Imgproc.filter2D(src: src, dst: dst, ddepth: -1, kernel: kernel)

        var result = [UInt8](repeating: 0, count: pixelCount)
        result.withUnsafeMutableBufferPointer { buf in
            if let base = buf.baseAddress {
                memcpy(base, dst.dataPointer(), pixelCount)
            }
        }
        return try Image8Bit(cols: image.cols, rows: image.rows, pixels: result)
    }

    // MARK: - Operations not wired up here

    func apply(_ kernel: KernelZeroSum, to image: Image4Bit) async throws -> Image4Bit {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement 4-bit grayvalue convolution.")
    }

    func apply(_ kernel: KernelUnitSum, to image: Image4Bit) async throws -> Image4Bit {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement 4-bit grayvalue convolution.")
    }

    func filter(_ image: Image8Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image8Bit {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement nonlinear shape filter.")
    }

    func filter(_ image: Image4Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image4Bit {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement nonlinear shape filter.")
    }

    func erode(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement binary morphology.")
    }

    func dilate(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement binary morphology.")
    }

    func split(_ image: ImageRGB, into space: ColorSpace) async throws -> [Image8Bit] {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement channel split.")
    }

    func compose(_ channels: [Image8Bit], from space: ColorSpace) async throws -> ImageRGB {
        throw AlgoCVError.unsupportedByBackend("OpenCV backend does not implement channel compose.")
    }
}
