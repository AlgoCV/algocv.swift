import Testing
@testable import AlgoCV

@Suite struct ChannelRoundTripTests {

    /// A 4×4 patch with a deterministic mix of colors.
    private func samplePatch() throws -> ImageRGB {
        var pixels: [UInt8] = []
        pixels.reserveCapacity(48)
        for i in 0..<16 {
            pixels.append(UInt8((i * 16) % 256))
            pixels.append(UInt8((i * 32 + 7) % 256))
            pixels.append(UInt8((i * 48 + 11) % 256))
        }
        return try ImageRGB(cols: 4, rows: 4, pixels: pixels)
    }

    @Test func rgbSplitRecomposeIsExact() async throws {
        let backend = ImProBackend()
        let original = try samplePatch()
        let channels = try await original.split(into: .rgb, backend: backend)
        #expect(channels.count == 3)
        let recovered = try await ImageRGB.recomposed(from: channels, in: .rgb, backend: backend)
        #expect(recovered.pixels == original.pixels)
    }

    @Test func splitCountsMatchChannelCount() async throws {
        let backend = ImProBackend()
        let original = try samplePatch()
        for space in ColorSpace.allCases {
            let channels = try await original.split(into: space, backend: backend)
            #expect(channels.count == space.channelCount,
                    "\(space) should produce \(space.channelCount) channels, got \(channels.count)")
        }
    }

    @Test func cmySplitRecomposeIsExact() async throws {
        let backend = ImProBackend()
        let original = try samplePatch()
        let channels = try await original.split(into: .cmy, backend: backend)
        let recovered = try await ImageRGB.recomposed(from: channels, in: .cmy, backend: backend)
        #expect(recovered.pixels == original.pixels)
    }

    @Test func composeRejectsMismatchedChannelCount() async {
        let backend = ImProBackend()
        let empty = try? Image8Bit(cols: 1, rows: 1, pixels: [0])
        guard let empty else { return }
        await #expect(throws: AlgoCVError.self) {
            _ = try await ImageRGB.recomposed(from: [empty, empty], in: .rgb, backend: backend)
        }
    }
}
