import Testing
import AlgoCVData
@testable import AlgoCV

@Suite struct MorphologyTests {

    /// Build a 4×4 binary image from explicit bit rows (LSB = column 0).
    private func makeMono(rows: [UInt32]) throws -> ImageMono {
        try ImageMono(cols: 4, rows: 4, words: rows)
    }

    @Test func dilateThreePassesEqualsLoopOfOne() async throws {
        let backend = ImProBackend()
        let original = try makeMono(rows: [
            0b0000,
            0b0100,
            0b0000,
            0b0000
        ])
        let shape = try Shape([
            [false, true, false],
            [true,  true, true ],
            [false, true, false]
        ])

        let multipass = try await original.dilated(by: shape, passes: 3, backend: backend)

        var iterated = original
        for _ in 0..<3 {
            iterated = try await iterated.dilated(by: shape, passes: 1, backend: backend)
        }
        #expect(multipass.words == iterated.words)
    }

    @Test func openedIsErodeThenDilate() async throws {
        let backend = ImProBackend()
        let original = try makeMono(rows: [
            0b1111,
            0b1101,
            0b1111,
            0b0001
        ])
        let shape = try Shape([
            [true, true, true],
            [true, true, true],
            [true, true, true]
        ])

        let opened = try await original.opened(by: shape, passes: 1, backend: backend)
        let manual = try await (try await original.eroded(by: shape, backend: backend))
            .dilated(by: shape, backend: backend)
        #expect(opened.words == manual.words)
    }

    @Test func passesMustBePositive() async {
        let backend = ImProBackend()
        let image = try? ImageMono(cols: 4, rows: 4, words: [0, 0, 0, 0])
        guard let image else { return }
        let shape = try? Shape([
            [true, true],
            [true, true]
        ])
        guard let shape else { return }
        await #expect(throws: AlgoCVError.self) {
            _ = try await image.eroded(by: shape, passes: 0, backend: backend)
        }
    }
}
