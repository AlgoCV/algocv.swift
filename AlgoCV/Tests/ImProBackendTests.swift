import Testing
import AlgoCVData
@testable import AlgoCV

@Suite struct ImProBackendTests {

    // A flat 4×4 input — box blur should leave a constant image untouched.
    @Test func boxBlurOfConstantImage() async throws {
        let backend = ImProBackend()
        let pixels = [UInt8](repeating: 100, count: 16)
        let image = try Image8Bit(cols: 4, rows: 4, pixels: pixels)
        let kernel = try KernelUnitSum(
            validating: Array(repeating: Array(repeating: UInt8(1), count: 3), count: 3)
        )
        let out = try await image.applying(kernel, backend: backend)
        #expect(out.pixels == pixels)
    }

    // Zero-sum Laplacian on a constant image gives all zeros.
    @Test func laplaceOfConstantImage() async throws {
        let backend = ImProBackend()
        let pixels = [UInt8](repeating: 128, count: 25)
        let image = try Image8Bit(cols: 5, rows: 5, pixels: pixels)
        let kernel = try KernelZeroSum(validating: [
            [ 0,  1,  0],
            [ 1, -4,  1],
            [ 0,  1,  0]
        ])
        let out = try await image.applying(kernel, backend: backend)
        #expect(out.pixels.allSatisfy { $0 == 0 })
    }

    // Shape + max transformation on a one-pixel hotspot produces a hotspot
    // dilated to the shape.
    @Test func shapeMaxFilter() async throws {
        let backend = ImProBackend()
        var pixels = [UInt8](repeating: 0, count: 9)
        pixels[4] = 200   // centre pixel
        let image = try Image8Bit(cols: 3, rows: 3, pixels: pixels)
        let shape = try Shape([
            [true, true, true],
            [true, true, true],
            [true, true, true]
        ])
        let out = try await image.filtered(through: shape, by: .max, backend: backend)
        #expect(out.pixels.allSatisfy { $0 == 200 })
    }
}
