import Testing
import Foundation
import AlgoCVData
@testable import AlgoCV

// Throughput benchmarks comparing three backends:
//   - Metal      : GPU compute shaders.
//   - ImPro      : single-thread SIMD CPU library.
//   - vImage(1T) : Apple's vImage pinned to one thread via `kvImageDoNotTile`,
//                  serving as the deterministic single-core CPU reference that
//                  Metal itself cannot provide (Metal does not expose any way
//                  to redirect a compute shader off the GPU).
//
// Each measurement: WARMUP discarded calls, then ITERATIONS measured calls
// using ContinuousClock. Results are printed; the suite is enabled only when
// a Metal device is available.
//
// vImage only natively covers 8-bit grayvalue linear convolution, so the
// 4-bit grayvalue and binary morphology tables only compare Metal vs ImPro.

@Suite("Backend throughput benchmarks",
       .enabled(if: AlgoCV.metalBackend != nil,
                "Metal backend unavailable on this host"))
struct KernelBenchmarks {

    static let imageSide: Int = 1024
    static let warmup: Int = 2
    static let iterations: Int = 5

    // MARK: - Test data

    static let bench8Bit: Image8Bit = {
        var pixels = [UInt8](repeating: 0, count: imageSide * imageSide)
        var state: UInt64 = 0x1234_5678_9ABC_DEF0
        for i in 0..<pixels.count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            pixels[i] = UInt8((state >> 24) & 0xFF)
        }
        return try! Image8Bit(cols: UInt16(imageSide), rows: UInt16(imageSide), pixels: pixels)
    }()

    static let bench4Bit: Image4Bit = {
        let packedRow = (imageSide + 1) / 2
        var packed = [UInt8](repeating: 0, count: packedRow * imageSide)
        var state: UInt64 = 0xFEDC_BA98_7654_3210
        for i in 0..<packed.count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            packed[i] = UInt8((state >> 24) & 0xFF)
        }
        return try! Image4Bit(cols: UInt16(imageSide), rows: UInt16(imageSide), pixels: packed)
    }()

    static let benchMono: ImageMono = {
        let stride = (imageSide + 31) / 32
        var words = [UInt32](repeating: 0, count: stride * imageSide)
        var state: UInt64 = 0xABCD_EF12_3456_7890
        for i in 0..<words.count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            words[i] = UInt32((state >> 32) & 0xFFFF_FFFF)
        }
        return try! ImageMono(cols: UInt16(imageSide), rows: UInt16(imageSide), words: words)
    }()

    static let benchShapes: [(name: String, shape: Shape)] = {
        var cases: [(String, Shape)] = []
        for side in KernelSamples.kernelSides {
            let full = Array(repeating: Array(repeating: true, count: side), count: side)
            let disc = SampleMath.discMask(side: side)
            let cross = SampleMath.crossMask(side: side)
            if let s = try? Shape(full)  { cases.append(("full \(side)×\(side)",  s)) }
            if let s = try? Shape(disc)  { cases.append(("disc \(side)×\(side)",  s)) }
            if let s = try? Shape(cross) { cases.append(("cross \(side)×\(side)", s)) }
        }
        return cases
    }()

    // MARK: - 8-bit grayvalue: Metal / ImPro / vImage(1T)

    @Test("Unit-sum convolution on Image8Bit (Metal, ImPro, vImage)")
    func unitSum8BitThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let vimage = AlgoCV.vImageBackend
        let image = Self.bench8Bit

        var rows: [Bench3Row] = []
        for sample in KernelSamples.unitSum {
            let kernel = try KernelUnitSum(validating: sample.values)
            let mMs = await measureAverageMs { _ = try? await metal.apply(kernel,  to: image) }
            let iMs = await measureAverageMs { _ = try? await impro.apply(kernel,  to: image) }
            let vMs = await measureAverageMs { _ = try? await vimage.apply(kernel, to: image) }
            rows.append(.init(name: "\(sample)", metalMs: mMs, improMs: iMs, vimageMs: vMs))
        }
        report3(title: "Unit-sum convolution on Image8Bit", rows: rows)
    }

    @Test("Zero-sum convolution on Image8Bit (Metal, ImPro, vImage)")
    func zeroSum8BitThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let vimage = AlgoCV.vImageBackend
        let image = Self.bench8Bit

        var rows: [Bench3Row] = []
        for sample in KernelSamples.zeroSum {
            let kernel = try KernelZeroSum(validating: sample.values)
            let mMs = await measureAverageMs { _ = try? await metal.apply(kernel,  to: image) }
            let iMs = await measureAverageMs { _ = try? await impro.apply(kernel,  to: image) }
            let vMs = await measureAverageMs { _ = try? await vimage.apply(kernel, to: image) }
            rows.append(.init(name: "\(sample)", metalMs: mMs, improMs: iMs, vimageMs: vMs))
        }
        report3(title: "Zero-sum convolution on Image8Bit", rows: rows)
    }

    // MARK: - 4-bit grayvalue: Metal vs ImPro (vImage does not support 4-bit)

    @Test("Unit-sum convolution on Image4Bit (Metal, ImPro)")
    func unitSum4BitThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let image = Self.bench4Bit

        var rows: [Bench2Row] = []
        for sample in KernelSamples.unitSum {
            let kernel = try KernelUnitSum(validating: sample.values)
            let mMs = await measureAverageMs { _ = try? await metal.apply(kernel, to: image) }
            let iMs = await measureAverageMs { _ = try? await impro.apply(kernel, to: image) }
            rows.append(.init(name: "\(sample)", metalMs: mMs, improMs: iMs))
        }
        report2(title: "Unit-sum convolution on Image4Bit", rows: rows)
    }

    @Test("Zero-sum convolution on Image4Bit (Metal, ImPro)")
    func zeroSum4BitThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let image = Self.bench4Bit

        var rows: [Bench2Row] = []
        for sample in KernelSamples.zeroSum {
            let kernel = try KernelZeroSum(validating: sample.values)
            let mMs = await measureAverageMs { _ = try? await metal.apply(kernel, to: image) }
            let iMs = await measureAverageMs { _ = try? await impro.apply(kernel, to: image) }
            rows.append(.init(name: "\(sample)", metalMs: mMs, improMs: iMs))
        }
        report2(title: "Zero-sum convolution on Image4Bit", rows: rows)
    }

    // MARK: - Binary morphology: Metal vs ImPro

    @Test("Binary erode on ImageMono (Metal, ImPro)")
    func erodeBinaryThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let image = Self.benchMono

        var rows: [Bench2Row] = []
        for (name, shape) in Self.benchShapes {
            let mMs = await measureAverageMs { _ = try? await metal.erode(image, by: shape, passes: 1) }
            let iMs = await measureAverageMs { _ = try? await impro.erode(image, by: shape, passes: 1) }
            rows.append(.init(name: name, metalMs: mMs, improMs: iMs))
        }
        report2(title: "Binary erode on ImageMono (passes=1)", rows: rows)
    }

    @Test("Binary dilate on ImageMono (Metal, ImPro)")
    func dilateBinaryThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let image = Self.benchMono

        var rows: [Bench2Row] = []
        for (name, shape) in Self.benchShapes {
            let mMs = await measureAverageMs { _ = try? await metal.dilate(image, by: shape, passes: 1) }
            let iMs = await measureAverageMs { _ = try? await impro.dilate(image, by: shape, passes: 1) }
            rows.append(.init(name: name, metalMs: mMs, improMs: iMs))
        }
        report2(title: "Binary dilate on ImageMono (passes=1)", rows: rows)
    }

    // MARK: - Helpers

    private struct Bench3Row {
        let name: String
        let metalMs: Double
        let improMs: Double
        let vimageMs: Double
    }

    private struct Bench2Row {
        let name: String
        let metalMs: Double
        let improMs: Double
    }

    private func measureAverageMs(_ block: () async -> Void) async -> Double {
        for _ in 0..<Self.warmup { await block() }
        let clock = ContinuousClock()
        let start = clock.now
        for _ in 0..<Self.iterations { await block() }
        let elapsed = clock.now - start
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        return (seconds * 1000.0) / Double(Self.iterations)
    }

    private func report3(title: String, rows: [Bench3Row]) {
        print("")
        print("=== \(title) on \(Self.imageSide)×\(Self.imageSide), \(Self.iterations) iterations (avg ms) ===")
        print(format3(name: "kernel",
                      metal: "Metal", impro: "ImPro", vimage: "vImage(1T)",
                      improRatio: "ImPro/Metal", improVsVimage: "ImPro/vImage"))
        for row in rows {
            let improRatio = row.metalMs > 0
                ? String(format: "%10.2fx", row.improMs / row.metalMs)
                : "       n/a"
            let improVsVimage = row.vimageMs > 0
                ? String(format: "%10.2fx", row.improMs / row.vimageMs)
                : "       n/a"
            print(format3(
                name: row.name,
                metal: String(format: "%9.3f", row.metalMs),
                impro: String(format: "%9.3f", row.improMs),
                vimage: String(format: "%9.3f", row.vimageMs),
                improRatio: improRatio,
                improVsVimage: improVsVimage
            ))
        }
    }

    private func report2(title: String, rows: [Bench2Row]) {
        print("")
        print("=== \(title) on \(Self.imageSide)×\(Self.imageSide), \(Self.iterations) iterations (avg ms) ===")
        print(format2(name: "case",
                      metal: "Metal", impro: "ImPro",
                      improRatio: "ImPro/Metal"))
        for row in rows {
            let improRatio = row.metalMs > 0
                ? String(format: "%10.2fx", row.improMs / row.metalMs)
                : "       n/a"
            print(format2(
                name: row.name,
                metal: String(format: "%9.3f", row.metalMs),
                impro: String(format: "%9.3f", row.improMs),
                improRatio: improRatio
            ))
        }
    }

    private func format3(name: String, metal: String, impro: String, vimage: String,
                         improRatio: String, improVsVimage: String) -> String {
        let paddedName = name.padding(toLength: 22, withPad: " ", startingAt: 0)
        return "  \(paddedName)"
            + "  \(metal.leftPadded(to: 10))"
            + "  \(impro.leftPadded(to: 10))"
            + "  \(vimage.leftPadded(to: 10))"
            + "  \(improRatio.leftPadded(to: 12))"
            + "  \(improVsVimage.leftPadded(to: 12))"
    }

    private func format2(name: String, metal: String, impro: String, improRatio: String) -> String {
        let paddedName = name.padding(toLength: 22, withPad: " ", startingAt: 0)
        return "  \(paddedName)"
            + "  \(metal.leftPadded(to: 10))"
            + "  \(impro.leftPadded(to: 10))"
            + "  \(improRatio.leftPadded(to: 12))"
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
