import Accelerate
import AlgoCVData
import Foundation

/// CPU reference backend using Apple's vImage. Pinned to one thread via
/// `kvImageDoNotTile`, which disables vImage's internal tiling / GCD
/// dispatch, so it acts as a deterministic single-core baseline against the
/// Metal GPU backend and the single-thread SIMD ImPro backend.
///
/// vImage only natively supports linear convolution on 8-bit grayvalue
/// planes; all other `AlgoCVBackend` methods throw
/// `AlgoCVError.unsupportedByBackend`.
struct VImageBackend: AlgoCVBackend {

    // MARK: - 8-bit grayvalue linear convolution

    func apply(_ kernel: KernelZeroSum, to image: Image8Bit) async throws -> Image8Bit {
        let widened = kernel.values.flatMap { row in row.map { Int16($0) } }
        return try convolvePlanar8(
            image: image,
            kernel: widened,
            kRows: Int(kernel.rowCount),
            kCols: Int(kernel.colCount),
            divisor: 1
        )
    }

    func apply(_ kernel: KernelUnitSum, to image: Image8Bit) async throws -> Image8Bit {
        let widened = kernel.values.flatMap { row in row.map { Int16($0) } }
        return try convolvePlanar8(
            image: image,
            kernel: widened,
            kRows: Int(kernel.rowCount),
            kCols: Int(kernel.colCount),
            divisor: Int32(kernel.denominator)
        )
    }

    private func convolvePlanar8(
        image: Image8Bit,
        kernel: [Int16],
        kRows: Int,
        kCols: Int,
        divisor: Int32
    ) throws -> Image8Bit {
        let cols = Int(image.cols)
        let rows = Int(image.rows)
        var src = image.pixels
        var dst = [UInt8](repeating: 0, count: cols * rows)
        let flags = vImage_Flags(kvImageEdgeExtend | kvImageDoNotTile)

        let err: vImage_Error = src.withUnsafeMutableBufferPointer { srcBuf -> vImage_Error in
            dst.withUnsafeMutableBufferPointer { dstBuf -> vImage_Error in
                kernel.withUnsafeBufferPointer { kBuf -> vImage_Error in
                    guard let srcBase = srcBuf.baseAddress,
                          let dstBase = dstBuf.baseAddress,
                          let kBase = kBuf.baseAddress else {
                        return vImage_Error(kvImageInvalidParameter)
                    }
                    var srcBuffer = vImage_Buffer(
                        data: UnsafeMutableRawPointer(srcBase),
                        height: vImagePixelCount(rows),
                        width: vImagePixelCount(cols),
                        rowBytes: cols
                    )
                    var dstBuffer = vImage_Buffer(
                        data: UnsafeMutableRawPointer(dstBase),
                        height: vImagePixelCount(rows),
                        width: vImagePixelCount(cols),
                        rowBytes: cols
                    )
                    return vImageConvolve_Planar8(
                        &srcBuffer,
                        &dstBuffer,
                        nil,
                        0, 0,
                        kBase,
                        UInt32(kRows),
                        UInt32(kCols),
                        divisor,
                        0,
                        flags
                    )
                }
            }
        }
        guard err == kvImageNoError else {
            throw AlgoCVError.backendUnavailable("vImageConvolve_Planar8 failed (error \(err)).")
        }
        return try Image8Bit(cols: image.cols, rows: image.rows, pixels: dst)
    }

    // MARK: - Operations vImage does not cover

    func apply(_ kernel: KernelZeroSum, to image: Image4Bit) async throws -> Image4Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement 4-bit grayvalue convolution.")
    }

    func apply(_ kernel: KernelUnitSum, to image: Image4Bit) async throws -> Image4Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement 4-bit grayvalue convolution.")
    }

    func filter(_ image: Image8Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image8Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement nonlinear shape filter.")
    }

    func filter(_ image: Image4Bit,
                through shape: Shape,
                by transformation: NonlinearTransformation) async throws -> Image4Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement nonlinear shape filter.")
    }

    func erode(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement binary morphology.")
    }

    func dilate(_ image: ImageMono, by shape: Shape, passes: Int) async throws -> ImageMono {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement binary morphology.")
    }

    func split(_ image: ImageRGB, into space: ColorSpace) async throws -> [Image8Bit] {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement channel split.")
    }

    func compose(_ channels: [Image8Bit], from space: ColorSpace) async throws -> ImageRGB {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement channel compose.")
    }

    func histogram(of image: Image8Bit) async throws -> Histogram {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement histogram.")
    }

    func fourier(of image: Image8Bit) async throws -> Spectrum8Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement Fourier transform.")
    }

    func inverseFourier(of spectrum: Spectrum8Bit) async throws -> Image8Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement inverse Fourier transform.")
    }

    func fourier(of image: Image4Bit) async throws -> Spectrum4Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement Fourier transform.")
    }

    func inverseFourier(of spectrum: Spectrum4Bit) async throws -> Image4Bit {
        throw AlgoCVError.unsupportedByBackend("vImage backend does not implement inverse Fourier transform.")
    }
}
