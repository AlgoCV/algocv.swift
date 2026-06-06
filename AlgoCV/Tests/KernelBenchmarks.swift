import Testing
import Foundation
import AlgoCVData
@testable import AlgoCV

// Throughput benchmarks comparing the Metal GPU backend against the ImPro CPU
// (SIMD) backend on the public `apply` / `filter` entry points.
//
// Metal does NOT expose a CPU-only or single-thread execution mode, so a third
// "Metal on CPU" comparison is intentionally absent — Apple removed the
// software MTLDevice from macOS and there is no runtime knob to redirect a
// compute shader off the GPU.
//
// Each measurement: WARMUP discarded calls, then ITERATIONS measured calls
// using ContinuousClock. Results are printed; the suite is enabled only when
// a Metal device is available.

@Suite("Backend throughput benchmarks",
       .enabled(if: AlgoCV.metalBackend != nil,
                "Metal backend unavailable on this host"))
struct KernelBenchmarks {

    static let imageSide: Int = 1024
    static let warmup: Int = 3
    static let iterations: Int = 10
    static let kernelSides: [Int] = [3, 5, 7, 11]

    static let benchImage: Image8Bit = {
        var pixels = [UInt8](repeating: 0, count: imageSide * imageSide)
        var state: UInt64 = 0x1234_5678_9ABC_DEF0
        for i in 0..<pixels.count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            pixels[i] = UInt8((state >> 24) & 0xFF)
        }
        return try! Image8Bit(cols: UInt16(imageSide), rows: UInt16(imageSide), pixels: pixels)
    }()

    @Test("Unit-sum convolution throughput")
    func unitSumThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let image = Self.benchImage

        var rows: [BenchRow] = []
        for side in Self.kernelSides {
            let kernel = try KernelUnitSum(validating: SampleMath.gaussian(side))
            let metalMs = await measureAverageMs {
                _ = try? await metal.apply(kernel, to: image)
            }
            let improMs = await measureAverageMs {
                _ = try? await impro.apply(kernel, to: image)
            }
            rows.append(BenchRow(name: "gaussian \(side)×\(side)", metalMs: metalMs, improMs: improMs))
        }
        report(title: "Unit-sum convolution", rows: rows)
    }

    @Test("Zero-sum convolution throughput")
    func zeroSumThroughput() async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let image = Self.benchImage

        var rows: [BenchRow] = []
        for side in Self.kernelSides {
            let kernel = try KernelZeroSum(validating: SampleMath.sobel(side: side, axis: .horizontal))
            let metalMs = await measureAverageMs {
                _ = try? await metal.apply(kernel, to: image)
            }
            let improMs = await measureAverageMs {
                _ = try? await impro.apply(kernel, to: image)
            }
            rows.append(BenchRow(name: "sobelX \(side)×\(side)", metalMs: metalMs, improMs: improMs))
        }
        report(title: "Zero-sum convolution", rows: rows)
    }

    // MARK: - Helpers

    private struct BenchRow {
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

    private func report(title: String, rows: [BenchRow]) {
        let header = "=== \(title) on \(Self.imageSide)×\(Self.imageSide), \(Self.iterations) iterations (avg ms) ==="
        print("")
        print(header)
        print(formatRow(name: "kernel", metal: "Metal", impro: "ImPro", ratio: "ImPro/Metal"))
        for row in rows {
            let ratio = row.metalMs > 0 ? String(format: "%9.2fx", row.improMs / row.metalMs) : "       n/a"
            print(formatRow(
                name: row.name,
                metal: String(format: "%9.3f", row.metalMs),
                impro: String(format: "%9.3f", row.improMs),
                ratio: ratio
            ))
        }
    }

    private func formatRow(name: String, metal: String, impro: String, ratio: String) -> String {
        let paddedName = name.padding(toLength: 22, withPad: " ", startingAt: 0)
        return "  \(paddedName)  \(metal.leftPadded(to: 10))  \(impro.leftPadded(to: 10))  \(ratio.leftPadded(to: 11))"
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
