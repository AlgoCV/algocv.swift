import Testing
import AlgoCVData
@testable import AlgoCV

@Suite struct ImageRoundTripTests {

    @Test func image8BitRoundTrip() throws {
        let pixels: [UInt8] = (0..<16).map { UInt8($0 * 16) }
        let img = try Image8Bit(cols: 4, rows: 4, pixels: pixels)
        #expect(img.pixels == pixels)
        #expect(img.cols == 4 && img.rows == 4)
    }

    @Test func image8BitRejectsBadLength() {
        #expect(throws: AlgoCVError.self) {
            _ = try Image8Bit(cols: 3, rows: 3, pixels: [0, 1])
        }
    }

    @Test func imageRGBRoundTrip() throws {
        let pixels = (0..<27).map { UInt8($0 * 3) }
        let img = try ImageRGB(cols: 3, rows: 3, pixels: pixels)
        #expect(img.pixels == pixels)
        #expect(img.pixels.count == 3 * Int(img.cols) * Int(img.rows))
    }

    @Test func image4BitRoundTripEvenCols() throws {
        let packed: [UInt8] = [0x12, 0x34, 0x56, 0x78]
        let img = try Image4Bit(cols: 4, rows: 2, pixels: packed)
        #expect(img.pixels == packed)
    }

    @Test func image4BitRoundTripOddCols() throws {
        // 3 cols × 2 rows → packed length = 2 bytes/row × 2 rows = 4 bytes.
        let packed: [UInt8] = [0x12, 0x30, 0x45, 0x60]
        let img = try Image4Bit(cols: 3, rows: 2, pixels: packed)
        #expect(img.pixels == packed)
    }

    @Test func imageMonoRoundTrip() throws {
        // 64-col image: stride = 2 words/row.
        let words: [UInt32] = [0xDEADBEEF, 0xCAFEF00D, 0x01234567, 0x89ABCDEF]
        let img = try ImageMono(cols: 64, rows: 2, words: words)
        #expect(img.words == words)
        #expect(img.stride == 2)
    }

    @Test func imageMonoRejectsBadWordCount() {
        #expect(throws: AlgoCVError.self) {
            _ = try ImageMono(cols: 32, rows: 4, words: [0, 0])  // expected 4 words
        }
    }
}
