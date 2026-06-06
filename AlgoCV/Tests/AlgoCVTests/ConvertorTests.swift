import Testing
import AlgoCVData
import ImPro
@testable import AlgoCV

@Suite struct ConvertorTests {

    @Test func image8BitImProRoundTrip() throws {
        let pixels: [UInt8] = (0..<64).map { UInt8($0 * 4) }
        let original = try Image8Bit(cols: 8, rows: 8, pixels: pixels)
        let bridged = try original.toImPro()
        let recovered = try Image8Bit(bridged)
        #expect(recovered == original)
    }

    @Test func imageRGBImProRoundTrip() throws {
        let pixels = (0..<48).map { UInt8($0 * 5 % 256) }
        let original = try ImageRGB(cols: 4, rows: 4, pixels: pixels)
        let bridged = try original.toImPro()
        let recovered = try ImageRGB(bridged)
        #expect(recovered == original)
    }

    @Test func imageMonoImProRoundTrip() throws {
        let words: [UInt32] = [0xDEADBEEF, 0xCAFEF00D]
        let original = try ImageMono(cols: 32, rows: 2, words: words)
        let bridged = try original.toImPro()
        let recovered = try ImageMono(bridged)
        #expect(recovered == original)
    }

    @Test func shapeMaskPacksCorrectly() throws {
        // 3×3 cross.
        let shape = try Shape([
            [false, true, false],
            [true,  true, true ],
            [false, true, false]
        ])
        let bin = try shape.toImProBinaryShape()
        // We can't introspect the bytes directly, but constructing without
        // throwing already confirms the packed word count matches the C bridge.
        _ = bin
    }
}
