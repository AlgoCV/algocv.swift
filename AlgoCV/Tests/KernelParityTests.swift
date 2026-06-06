import Testing
import Foundation
import AlgoCVData
@testable import AlgoCV

// Parity tests: every kernel sample applied to every preview image must produce
// the same pixels under the Metal and ImPro backends. To stay independent of
// each backend's border policy we crop the half-kernel-wide border out before
// the comparison — only pixels whose entire kernel footprint lies inside the
// image are checked.
//
// Kernel samples and the four preview images are lifted from
// `cvexplorer.swiftui` so the tests exercise the same shapes the GUI shows.

private let unitSumKernelCases: [UnitSumKernelCase] = KernelSamples.unitSum
private let zeroSumKernelCases: [ZeroSumKernelCase] = KernelSamples.zeroSum

@Suite("Metal vs ImPro kernel parity",
       .enabled(if: AlgoCV.metalBackend != nil,
                "Metal backend unavailable on this host"))
struct KernelParityTests {

    @Test("Kernel catalogue has at least 64 samples")
    func enoughKernelSamples() {
        #expect(unitSumKernelCases.count + zeroSumKernelCases.count >= 64)
    }

    @Test("Unit-sum convolution parity",
          arguments: TestPreviewImage.allCases, unitSumKernelCases)
    func unitSumParity(image: TestPreviewImage, sample: UnitSumKernelCase) async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let kernel = try KernelUnitSum(validating: sample.values)
        let source = image.image
        let metalOut = try await metal.apply(kernel, to: source)
        let improOut = try await impro.apply(kernel, to: source)
        try expectInteriorMatches(
            metal: metalOut,
            impro: improOut,
            kernelCols: sample.values.first?.count ?? 0,
            kernelRows: sample.values.count,
            label: "\(image) / \(sample)"
        )
    }

    @Test("Zero-sum convolution parity",
          arguments: TestPreviewImage.allCases, zeroSumKernelCases)
    func zeroSumParity(image: TestPreviewImage, sample: ZeroSumKernelCase) async throws {
        guard let metal = AlgoCV.metalBackend else { return }
        let impro = AlgoCV.improBackend
        let kernel = try KernelZeroSum(validating: sample.values)
        let source = image.image
        let metalOut = try await metal.apply(kernel, to: source)
        let improOut = try await impro.apply(kernel, to: source)
        try expectInteriorMatches(
            metal: metalOut,
            impro: improOut,
            kernelCols: sample.values.first?.count ?? 0,
            kernelRows: sample.values.count,
            label: "\(image) / \(sample)"
        )
    }

    // MARK: - Comparison helper

    private func expectInteriorMatches(
        metal: Image8Bit,
        impro: Image8Bit,
        kernelCols: Int,
        kernelRows: Int,
        label: String
    ) throws {
        #expect(metal.cols == impro.cols, "\(label): cols mismatch")
        #expect(metal.rows == impro.rows, "\(label): rows mismatch")

        let cols = Int(metal.cols)
        let rows = Int(metal.rows)
        let borderX = kernelCols / 2
        let borderY = kernelRows / 2

        guard cols > 2 * borderX, rows > 2 * borderY else {
            return  // image too small to crop — would be empty.
        }

        var firstMismatch: (col: Int, row: Int, metal: UInt8, impro: UInt8)?
        var mismatches = 0
        for r in borderY..<(rows - borderY) {
            let rowOffset = r * cols
            for c in borderX..<(cols - borderX) {
                let m = metal.pixels[rowOffset + c]
                let i = impro.pixels[rowOffset + c]
                if m != i {
                    if firstMismatch == nil {
                        firstMismatch = (c, r, m, i)
                    }
                    mismatches += 1
                }
            }
        }

        if let fm = firstMismatch {
            Issue.record(
                """
                \(label): \(mismatches) interior pixels differ. \
                First mismatch at (col=\(fm.col), row=\(fm.row)) — \
                Metal=\(fm.metal) ImPro=\(fm.impro).
                """
            )
        }
    }
}

// MARK: - Kernel sample model

struct UnitSumKernelCase: Sendable, CustomStringConvertible {
    let name: String
    let side: Int
    let values: [[UInt8]]
    var description: String { "\(name) \(side)×\(side)" }
}

struct ZeroSumKernelCase: Sendable, CustomStringConvertible {
    let name: String
    let side: Int
    let values: [[Int8]]
    var description: String { "\(name) \(side)×\(side)" }
}

// MARK: - Preview images (cvexplorer.swiftui parity)

enum TestPreviewImage: String, CaseIterable, Sendable, CustomStringConvertible {
    case checkerboard, gradient, shapes, noise

    static let side: Int = 128

    var description: String { rawValue }

    var image: Image8Bit {
        switch self {
        case .checkerboard: return PreviewImageCache.checkerboard
        case .gradient:     return PreviewImageCache.gradient
        case .shapes:       return PreviewImageCache.shapes
        case .noise:        return PreviewImageCache.noise
        }
    }
}

private enum PreviewImageCache {
    static let checkerboard: Image8Bit = PreviewImageBuilder.checkerboard()
    static let gradient: Image8Bit = PreviewImageBuilder.gradient()
    static let shapes: Image8Bit = PreviewImageBuilder.shapes()
    static let noise: Image8Bit = PreviewImageBuilder.noise()
}

private enum PreviewImageBuilder {
    static let side: Int = TestPreviewImage.side

    // Alternating light / dark cells — matches the cvexplorer checkerboard
    // preset (light 0.95, dark 0.15, cell = max(8, side/16)).
    static func checkerboard() -> Image8Bit {
        let cell = max(8, side / 16)
        let light = UInt8((0.95 * 255).rounded())
        let dark  = UInt8((0.15 * 255).rounded())
        var pixels = [UInt8](repeating: light, count: side * side)
        for r in 0..<side {
            for c in 0..<side where ((r / cell) + (c / cell)).isMultiple(of: 2) {
                pixels[r * side + c] = dark
            }
        }
        return try! Image8Bit(cols: UInt16(side), rows: UInt16(side), pixels: pixels)
    }

    // Linear diagonal gradient from 0.02 to 0.98 — same endpoints as the
    // cvexplorer gradient preset.
    static func gradient() -> Image8Bit {
        var pixels = [UInt8](repeating: 0, count: side * side)
        let denom = Double(2 * (side - 1))
        for r in 0..<side {
            for c in 0..<side {
                let t = Double(r + c) / denom
                let v = 0.02 + (0.98 - 0.02) * t
                pixels[r * side + c] = UInt8((v * 255).rounded())
            }
        }
        return try! Image8Bit(cols: UInt16(side), rows: UInt16(side), pixels: pixels)
    }

    // Background, dark disk + dark square + mid-grey triangle. Geometry mirrors
    // the cvexplorer shapes preset; rasterised here in pure Swift so the test
    // does not depend on CoreGraphics.
    static func shapes() -> Image8Bit {
        let bg   = UInt8((0.85 * 255).rounded())
        let dark = UInt8((0.12 * 255).rounded())
        let mid  = UInt8((0.35 * 255).rounded())
        var pixels = [UInt8](repeating: bg, count: side * side)
        let s = Double(side)

        // Disk: inscribed in CG rect (0.55, 0.55, 0.35, 0.35).
        let diskCx = s * (0.55 + 0.35 / 2.0)
        let diskCy = s * (0.55 + 0.35 / 2.0)
        let diskR  = s * 0.35 / 2.0
        for r in 0..<side {
            let dy = Double(r) + 0.5 - diskCy
            for c in 0..<side {
                let dx = Double(c) + 0.5 - diskCx
                if dx * dx + dy * dy <= diskR * diskR {
                    pixels[r * side + c] = dark
                }
            }
        }

        // Square: CG rect (0.10, 0.55, 0.30, 0.30).
        let sqX0 = Int((s * 0.10).rounded())
        let sqY0 = Int((s * 0.55).rounded())
        let sqW  = Int((s * 0.30).rounded())
        let sqH  = Int((s * 0.30).rounded())
        for r in sqY0..<min(sqY0 + sqH, side) {
            for c in sqX0..<min(sqX0 + sqW, side) {
                pixels[r * side + c] = dark
            }
        }

        // Triangle with vertices at (0.50, 0.05), (0.90, 0.45), (0.10, 0.45).
        let a = (s * 0.50, s * 0.05)
        let b = (s * 0.90, s * 0.45)
        let cc = (s * 0.10, s * 0.45)
        for r in 0..<side {
            for c in 0..<side {
                let p = (Double(c) + 0.5, Double(r) + 0.5)
                if pointInTriangle(p, a, b, cc) {
                    pixels[r * side + c] = mid
                }
            }
        }

        return try! Image8Bit(cols: UInt16(side), rows: UInt16(side), pixels: pixels)
    }

    // Seeded LCG noise — keeps the test image reproducible across runs.
    static func noise() -> Image8Bit {
        var pixels = [UInt8](repeating: 0, count: side * side)
        var state: UInt64 = 0xC0FFEE_F00D_BA5E
        for i in 0..<pixels.count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            pixels[i] = UInt8((state >> 24) & 0xFF)
        }
        return try! Image8Bit(cols: UInt16(side), rows: UInt16(side), pixels: pixels)
    }

    private static func pointInTriangle(
        _ p: (Double, Double),
        _ a: (Double, Double),
        _ b: (Double, Double),
        _ c: (Double, Double)
    ) -> Bool {
        let d1 = edgeSign(p, a, b)
        let d2 = edgeSign(p, b, c)
        let d3 = edgeSign(p, c, a)
        let hasNeg = d1 < 0 || d2 < 0 || d3 < 0
        let hasPos = d1 > 0 || d2 > 0 || d3 > 0
        return !(hasNeg && hasPos)
    }

    private static func edgeSign(
        _ p: (Double, Double),
        _ q: (Double, Double),
        _ r: (Double, Double)
    ) -> Double {
        (p.0 - r.0) * (q.1 - r.1) - (q.0 - r.0) * (p.1 - r.1)
    }
}

// MARK: - Kernel sample catalogue (cvexplorer.swiftui parity)
//
// The generators below are lifted from
// `cvexplorer.swiftui/CVExplorerUI/Sources/KernelPresets.swift::PresetMath`.
// Kept here verbatim so the parity tests stay self-contained and survive
// changes to the GUI's preset list.

private enum KernelSamples {
    static let kernelSides: [Int] = [3, 5, 7, 9, 11]

    static var unitSum: [UnitSumKernelCase] {
        var cases: [UnitSumKernelCase] = []
        for side in kernelSides {
            cases.append(.init(name: "uniform",   side: side, values: SampleMath.uniform(side)))
            cases.append(.init(name: "gaussian",  side: side, values: SampleMath.gaussian(side)))
            cases.append(.init(name: "pyramid",   side: side, values: SampleMath.pyramidTent(side: side, maxValue: 8)))
            cases.append(.init(name: "cone",      side: side, values: SampleMath.radialCone(side: side, maxValue: 8)))
            cases.append(.init(name: "disc",      side: side, values: SampleMath.discMask(side: side).map { $0.map { $0 ? UInt8(1) : 0 } }))
            cases.append(.init(name: "cross",     side: side, values: SampleMath.crossMask(side: side).map { $0.map { $0 ? UInt8(1) : 0 } }))
        }
        return cases
    }

    static var zeroSum: [ZeroSumKernelCase] {
        var cases: [ZeroSumKernelCase] = []
        for side in kernelSides {
            cases.append(.init(name: "laplacian4", side: side, values: SampleMath.laplacian(side: side, includeDiagonals: false)))
            cases.append(.init(name: "laplacian8", side: side, values: SampleMath.laplacian(side: side, includeDiagonals: true)))
            cases.append(.init(name: "sobelX",     side: side, values: SampleMath.sobel(side: side, axis: .horizontal)))
            cases.append(.init(name: "sobelY",     side: side, values: SampleMath.sobel(side: side, axis: .vertical)))
            cases.append(.init(name: "prewittX",   side: side, values: SampleMath.prewitt(side: side, axis: .horizontal)))
            cases.append(.init(name: "prewittY",   side: side, values: SampleMath.prewitt(side: side, axis: .vertical)))
        }
        // DoG one-step: smaller Gaussian is N-2, requires N ≥ 5.
        for side in [5, 7, 9, 11] {
            cases.append(.init(
                name: "dogOneStep",
                side: side,
                values: SampleMath.differenceOfGaussians(outerSide: side, innerSide: side - 2)
            ))
        }
        // DoG two-step: smaller Gaussian is N-4, requires N ≥ 7.
        for side in [7, 9, 11] {
            cases.append(.init(
                name: "dogTwoStep",
                side: side,
                values: SampleMath.differenceOfGaussians(outerSide: side, innerSide: side - 4)
            ))
        }
        return cases
    }
}

enum SampleMath {
    enum Axis { case horizontal, vertical }

    static func uniform(_ side: Int) -> [[UInt8]] {
        Array(repeating: Array(repeating: UInt8(1), count: side), count: side)
    }

    static func gaussianRaw(side: Int) -> [[Double]] {
        let centre = Double(side - 1) / 2.0
        let sigma = max(1.0, Double(side - 1) / 4.0)
        var raw = Array(repeating: Array(repeating: 0.0, count: side), count: side)
        for r in 0..<side {
            for c in 0..<side {
                let dr = Double(r) - centre
                let dc = Double(c) - centre
                raw[r][c] = exp(-(dr * dr + dc * dc) / (2 * sigma * sigma))
            }
        }
        return raw
    }

    static func gaussian1D(size: Int) -> [UInt8] {
        let centre = Double(size - 1) / 2.0
        let sigma = max(1.0, Double(size - 1) / 4.0)
        var raw: [Double] = []
        var peak = 0.0
        for i in 0..<size {
            let d = Double(i) - centre
            let v = exp(-d * d / (2 * sigma * sigma))
            raw.append(v)
            peak = max(peak, v)
        }
        let scale = peak > 0 ? 8.0 / peak : 1.0
        return raw.map { UInt8(clamping: Int(($0 * scale).rounded())) }
    }

    static func gaussian(_ side: Int) -> [[UInt8]] {
        let g = gaussian1D(size: side)
        var result = Array(repeating: Array(repeating: UInt8(0), count: side), count: side)
        for r in 0..<side {
            for c in 0..<side {
                let product = Int(g[r]) * Int(g[c])
                result[r][c] = UInt8(clamping: product)
            }
        }
        return result
    }

    static func pyramidTent(side: Int, maxValue: Int) -> [[UInt8]] {
        let centre = Double(side - 1) / 2.0
        let extent = max(centre, 0.5)
        return (0..<side).map { r in
            (0..<side).map { c in
                let dr = abs(Double(r) - centre) / extent
                let dc = abs(Double(c) - centre) / extent
                let v = max(0.0, 1.0 - max(dr, dc))
                return UInt8(max(0, min(255, Int((v * Double(maxValue)).rounded()))))
            }
        }
    }

    static func radialCone(side: Int, maxValue: Int) -> [[UInt8]] {
        let centre = Double(side - 1) / 2.0
        let radius = max(centre, 0.5)
        return (0..<side).map { r in
            (0..<side).map { c in
                let dr = Double(r) - centre
                let dc = Double(c) - centre
                let dist = sqrt(dr * dr + dc * dc)
                let v = max(0.0, 1.0 - dist / radius)
                return UInt8(max(0, min(255, Int((v * Double(maxValue)).rounded()))))
            }
        }
    }

    static func discMask(side: Int) -> [[Bool]] {
        let centre = Double(side - 1) / 2.0
        let radius = centre + 0.4
        return (0..<side).map { r in
            (0..<side).map { c in
                let dr = Double(r) - centre
                let dc = Double(c) - centre
                return sqrt(dr * dr + dc * dc) <= radius
            }
        }
    }

    static func crossMask(side: Int) -> [[Bool]] {
        let centre = (side - 1) / 2
        return (0..<side).map { r in
            (0..<side).map { c in
                r == centre || c == centre
            }
        }
    }

    static func laplacian(side: Int, includeDiagonals: Bool) -> [[Int8]] {
        let centre = (side - 1) / 2
        var grid = Array(repeating: Array(repeating: Int8(0), count: side), count: side)
        let offsets: [(Int, Int)] = includeDiagonals
            ? [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
            : [(-1, 0), (0, -1), (0, 1), (1, 0)]
        var neighbourCount = 0
        for (dr, dc) in offsets {
            let r = centre + dr
            let c = centre + dc
            guard r >= 0, r < side, c >= 0, c < side else { continue }
            grid[r][c] = -1
            neighbourCount += 1
        }
        grid[centre][centre] = Int8(clamping: neighbourCount)
        return grid
    }

    static func sobel(side: Int, axis: Axis) -> [[Int8]] {
        let centre = Double(side - 1) / 2.0
        let sigma = max(0.85, Double(side) / 3.0)
        var raw: [[Double]] = []
        var peakAbs = 0.0
        for r in 0..<side {
            var row: [Double] = []
            for c in 0..<side {
                let dr = Double(r) - centre
                let dc = Double(c) - centre
                let value: Double
                switch axis {
                case .horizontal:
                    let smooth = exp(-dr * dr / (2 * sigma * sigma))
                    value = dc * smooth
                case .vertical:
                    let smooth = exp(-dc * dc / (2 * sigma * sigma))
                    value = dr * smooth
                }
                row.append(value)
                peakAbs = max(peakAbs, abs(value))
            }
            raw.append(row)
        }
        let target = max(2.0, Double(side - 1))
        let scale = peakAbs > 0 ? target / peakAbs : 1.0
        return raw.map { row in
            row.map { Int8(clamping: Int(($0 * scale).rounded())) }
        }
    }

    static func prewitt(side: Int, axis: Axis) -> [[Int8]] {
        let centre = Double(side - 1) / 2.0
        return (0..<side).map { r in
            (0..<side).map { c in
                let dr = Double(r) - centre
                let dc = Double(c) - centre
                let value: Double
                switch axis {
                case .horizontal: value = dc
                case .vertical:   value = dr
                }
                return Int8(clamping: Int(value.rounded()))
            }
        }
    }

    static func differenceOfGaussians(outerSide: Int, innerSide: Int) -> [[Int8]] {
        let n = max(outerSide, 1)
        let m = max(min(innerSide, n), 1)

        let outer = gaussianRaw(side: n)
        let inner = gaussianRaw(side: m)

        let padding = (n - m) / 2
        var innerEmbedded = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for r in 0..<m {
            for c in 0..<m {
                innerEmbedded[r + padding][c + padding] = inner[r][c]
            }
        }

        let sumOuter = outer.flatMap { $0 }.reduce(0, +)
        let sumInner = innerEmbedded.flatMap { $0 }.reduce(0, +)
        guard sumOuter > 0, sumInner > 0 else {
            return Array(repeating: Array(repeating: 0, count: n), count: n)
        }

        var dog = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        var peak = 0.0
        for r in 0..<n {
            for c in 0..<n {
                let normInner = innerEmbedded[r][c] / sumInner
                let normOuter = outer[r][c] / sumOuter
                let v = normInner - normOuter
                dog[r][c] = v
                peak = max(peak, abs(v))
            }
        }

        guard peak > 0 else {
            return Array(repeating: Array(repeating: 0, count: n), count: n)
        }
        let scale = 32.0 / peak
        return dog.map { row in
            row.map { Int8(clamping: Int(($0 * scale).rounded())) }
        }
    }
}
