import Foundation
import Testing

@testable import AlgoCVData

@Suite("Kernel ID collision tests")
struct KernelIDCollisionTests {
    @Test
    func classicalComputerVisionKernelsHaveUniqueIDs() {
        let fixtures = KernelFixture.classicalComputerVisionFixtures()
        let collisions = Dictionary(grouping: fixtures, by: \.id).filter { $0.value.count > 1 }

        if !collisions.isEmpty {
            let report = collisions
                .sorted { $0.key < $1.key }
                .map { entry in
                    let id = String(entry.key, radix: 16, uppercase: true)
                    let names = entry.value
                        .map(\.description)
                        .sorted()
                        .joined(separator: "\n  ")
                    return "0x\(id):\n  \(names)"
                }
                .joined(separator: "\n\n")
            Issue.record("Kernel ID collisions found:\n\(report)")
        }

        #expect(fixtures.count == 979)
        #expect(collisions.isEmpty)
    }
}

private struct KernelFixture: CustomStringConvertible {
    let name: String
    let kind: String
    let dimensions: String
    let id: UInt64

    var description: String {
        "\(kind) \(name) \(dimensions)"
    }
}

private extension KernelFixture {
    static func classicalComputerVisionFixtures() -> [KernelFixture] {
        oddSquareSizes.flatMap { size in
            unitSumFixtures(size: size) + zeroSumFixtures(size: size) + nonlinearFixtures(size: size)
        }
    }

    static func unitSumFixtures(size: Int) -> [KernelFixture] {
        var fixtures: [KernelFixture] = [
            unitSum("box \(size)x\(size)", square(size: size) { _, _ in 1 }),
            unitSum("box row \(size)", [Array(repeating: 1, count: size)]),
            unitSum("box column \(size)", column(Array(repeating: 1, count: size))),
            unitSum("gaussian \(size)x\(size)", sampledGaussian2D(size: size, sigma: Double(size) / 5.0)),
            unitSum("gaussian row \(size)", [sampledGaussian1D(size: size, sigma: Double(size) / 5.0)]),
            unitSum("gaussian column \(size)", column(sampledGaussian1D(size: size, sigma: Double(size) / 5.0))),
            unitSum("triangular \(size)x\(size)", outer(triangularVector(size: size), triangularVector(size: size))),
            unitSum("cross \(size)x\(size)", maskToInt(crossMask(size: size))),
            unitSum("motion horizontal \(size)x\(size)", square(size: size) { row, _ in row == size / 2 ? 1 : 0 }),
            unitSum("motion vertical \(size)x\(size)", square(size: size) { _, column in column == size / 2 ? 1 : 0 }),
            unitSum("motion diagonal \(size)x\(size)", square(size: size) { row, column in row == column ? 1 : 0 }),
            unitSum("motion anti-diagonal \(size)x\(size)", square(size: size) { row, column in row + column == size - 1 ? 1 : 0 }),
            unitSum("sobel smoothing row \(size)", [sobelSmoothingVector(size: size)]),
            unitSum("sobel smoothing column \(size)", column(sobelSmoothingVector(size: size))),
            unitSum("scharr smoothing row \(size)", [scharrSmoothingVector(size: size)]),
            unitSum("scharr smoothing column \(size)", column(scharrSmoothingVector(size: size))),
        ]

        if size > 3 {
            fixtures.append(unitSum("diamond average \(size)x\(size)", maskToInt(diamondMask(size: size))))
        }
        if size > 5 {
            fixtures.append(unitSum("disk average \(size)x\(size)", maskToInt(diskMask(size: size))))
            fixtures.append(unitSum("annulus average \(size)x\(size)", maskToInt(annulusMask(size: size))))
        }

        return fixtures
    }

    static func zeroSumFixtures(size: Int) -> [KernelFixture] {
        let prewittSmoothing = Array(repeating: 1, count: size)
        let derivative = centralDerivativeVector(size: size)
        let sobelSmoothing = sobelSmoothingVector(size: size)
        let scharrSmoothing = scharrSmoothingVector(size: size)
        let scharrDerivative = scharrDerivativeVector(size: size)

        var fixtures: [KernelFixture] = [
            zeroSum("laplacian 4-neighbor \(size)x\(size)", laplacian4(size: size)),
            zeroSum("laplacian 8-neighbor \(size)x\(size)", laplacian8(size: size)),
            zeroSum("laplacian of gaussian \(size)x\(size)", laplacianOfGaussian(size: size)),
            zeroSum("difference of gaussians \(size)x\(size)", differenceOfGaussians(size: size)),
            zeroSum("central derivative row \(size)", [derivative]),
            zeroSum("central derivative column \(size)", column(derivative)),
            zeroSum("central difference x \(size)x\(size)", centralDifferenceX(size: size)),
            zeroSum("central difference y \(size)x\(size)", centralDifferenceY(size: size)),
            zeroSum("prewitt x \(size)x\(size)", outer(prewittSmoothing, derivative)),
            zeroSum("prewitt y \(size)x\(size)", outer(derivative, prewittSmoothing)),
            zeroSum("sobel x \(size)x\(size)", outer(sobelSmoothing, derivative)),
            zeroSum("sobel y \(size)x\(size)", outer(derivative, sobelSmoothing)),
            zeroSum("scharr derivative row \(size)", [scharrDerivative]),
            zeroSum("scharr derivative column \(size)", column(scharrDerivative)),
            zeroSum("scharr x \(size)x\(size)", outer(scharrSmoothing, scharrDerivative)),
            zeroSum("scharr y \(size)x\(size)", outer(scharrDerivative, scharrSmoothing)),
            zeroSum("hessian xx \(size)x\(size)", hessianXX(size: size)),
            zeroSum("hessian yy \(size)x\(size)", hessianYY(size: size)),
            zeroSum("hessian xy \(size)x\(size)", hessianXY(size: size)),
            zeroSum("roberts x embedded \(size)x\(size)", robertsX(size: size)),
            zeroSum("roberts y embedded \(size)x\(size)", robertsY(size: size)),
            zeroSum("line detector horizontal \(size)x\(size)", lineDetectorHorizontal(size: size)),
            zeroSum("line detector vertical \(size)x\(size)", lineDetectorVertical(size: size)),
            zeroSum("line detector diagonal \(size)x\(size)", lineDetectorDiagonal(size: size)),
            zeroSum("line detector anti-diagonal \(size)x\(size)", lineDetectorAntiDiagonal(size: size)),
        ]

        fixtures.append(contentsOf: compassKernels(size: size))
        return fixtures
    }

    static func nonlinearFixtures(size: Int) -> [KernelFixture] {
        var masks: [(name: String, values: [[Bool]])] = [
            ("box", square(size: size) { _, _ in true }),
            ("cross", crossMask(size: size)),
            ("horizontal line", square(size: size) { row, _ in row == size / 2 }),
            ("vertical line", square(size: size) { _, column in column == size / 2 }),
            ("main diagonal", square(size: size) { row, column in row == column }),
            ("anti diagonal", square(size: size) { row, column in row + column == size - 1 }),
            ("x diagonal", square(size: size) { row, column in row == column || row + column == size - 1 }),
            ("border", square(size: size) { row, column in
                row == 0 || column == 0 || row == size - 1 || column == size - 1
            }),
            ("corners", square(size: size) { row, column in
                (row == 0 || row == size - 1) && (column == 0 || column == size - 1)
            }),
        ]

        if size > 3 {
            masks.append(("diamond", diamondMask(size: size)))
            masks.append(("checkerboard", square(size: size) { row, column in (row + column).isMultiple(of: 2) }))
        }
        if size > 5 {
            masks.append(("disk", diskMask(size: size)))
            masks.append(("annulus", annulusMask(size: size)))
        }

        return masks.flatMap { mask in
            KernelNonlinear.Transformation.allCases.map { transformation in
                nonlinear("\(transformation.rawValue) \(mask.name) \(size)x\(size)", mask.values, transformation: transformation)
            }
        }
    }

    static func unitSum(_ name: String, _ values: [[Int]]) -> KernelFixture {
        let uintValues = values.map { row in
            row.map { value -> UInt8 in
                precondition(value >= UInt8.min && value <= UInt8.max, "\(name) contains \(value), outside UInt8")
                return UInt8(value)
            }
        }
        let kernel = KernelUnitSum(values: uintValues)
        precondition(kernel.sum > 0, "\(name) is empty")
        precondition(UInt64(kernel.denominator) == kernel.sum, "\(name) has a non-default denominator")
        return KernelFixture(
            name: name,
            kind: "unit",
            dimensions: "\(kernel.colCount)x\(kernel.rowCount)",
            id: kernel.id
        )
    }

    static func zeroSum(_ name: String, _ values: [[Int]]) -> KernelFixture {
        let intValues = values.map { row in
            row.map { value -> Int8 in
                precondition(value >= Int(Int8.min) && value <= Int(Int8.max), "\(name) contains \(value), outside Int8")
                return Int8(value)
            }
        }
        let kernel = KernelZeroSum(values: intValues)
        precondition(kernel.sum == 0, "\(name) sum is \(kernel.sum), not zero")
        return KernelFixture(
            name: name,
            kind: "zero",
            dimensions: "\(kernel.colCount)x\(kernel.rowCount)",
            id: kernel.id
        )
    }

    static func nonlinear(
        _ name: String,
        _ values: [[Bool]],
        transformation: KernelNonlinear.Transformation
    ) -> KernelFixture {
        let kernel = KernelNonlinear(values: values, nonlinear: transformation)
        precondition(kernel.activeCount > 0, "\(name) has no active cells")
        return KernelFixture(
            name: name,
            kind: "boolean",
            dimensions: "\(kernel.colCount)x\(kernel.rowCount)",
            id: kernel.id
        )
    }

    static var oddSquareSizes: [Int] {
        Array(stride(from: 3, through: 13, by: 2))
    }
}

private func square<T>(size: Int, value: (Int, Int) -> T) -> [[T]] {
    (0..<size).map { row in
        (0..<size).map { column in
            value(row, column)
        }
    }
}

private func column(_ values: [Int]) -> [[Int]] {
    values.map { [$0] }
}

private func outer(_ column: [Int], _ row: [Int]) -> [[Int]] {
    column.map { columnValue in
        row.map { rowValue in
            columnValue * rowValue
        }
    }
}

private func maskToInt(_ values: [[Bool]]) -> [[Int]] {
    values.map { row in
        row.map { $0 ? 1 : 0 }
    }
}

private func triangularVector(size: Int) -> [Int] {
    let center = size / 2
    return (0..<size).map { index in
        center + 1 - abs(index - center)
    }
}

private func centralDerivativeVector(size: Int) -> [Int] {
    let center = size / 2
    return (0..<size).map { $0 - center }
}

private func sobelSmoothingVector(size: Int) -> [Int] {
    scaledPositiveVector(binomialCoefficients(order: size - 1), maxValue: 12)
}

private func scharrSmoothingVector(size: Int) -> [Int] {
    if size == 3 {
        return [3, 10, 3]
    }

    return sampledGaussian1D(size: size, sigma: Double(size) / 6.0, maxValue: 7)
}

private func scharrDerivativeVector(size: Int) -> [Int] {
    centralDerivativeVector(size: size).map { $0 * 3 }
}

private func binomialCoefficients(order: Int) -> [Int] {
    var coefficients = [1]
    guard order > 0 else { return coefficients }

    for _ in 0..<order {
        coefficients = zip([0] + coefficients, coefficients + [0]).map(+)
    }
    return coefficients
}

private func scaledPositiveVector(_ values: [Int], maxValue: Int) -> [Int] {
    let maximum = values.max() ?? 1
    return values.map { value in
        max(1, Int(round(Double(value) / Double(maximum) * Double(maxValue))))
    }
}

private func sampledGaussian1D(size: Int, sigma: Double, maxValue: Int = 255) -> [Int] {
    let center = size / 2
    return (0..<size).map { index in
        let x = Double(index - center)
        let value = exp(-(x * x) / (2.0 * sigma * sigma))
        return max(1, Int(round(value * Double(maxValue))))
    }
}

private func sampledGaussian2D(size: Int, sigma: Double, maxValue: Int = 255) -> [[Int]] {
    let center = size / 2
    return square(size: size) { row, column in
        let x = Double(column - center)
        let y = Double(row - center)
        let value = exp(-((x * x) + (y * y)) / (2.0 * sigma * sigma))
        return max(1, Int(round(value * Double(maxValue))))
    }
}

private func crossMask(size: Int) -> [[Bool]] {
    square(size: size) { row, column in
        row == size / 2 || column == size / 2
    }
}

private func diamondMask(size: Int) -> [[Bool]] {
    let center = size / 2
    return square(size: size) { row, column in
        abs(row - center) + abs(column - center) <= center
    }
}

private func diskMask(size: Int) -> [[Bool]] {
    let center = size / 2
    let radius = Double(center)
    return square(size: size) { row, column in
        let x = Double(column - center)
        let y = Double(row - center)
        return sqrt((x * x) + (y * y)) <= radius
    }
}

private func annulusMask(size: Int) -> [[Bool]] {
    let center = size / 2
    let outerRadius = Double(center)
    let innerRadius = max(0.0, outerRadius - 1.5)
    return square(size: size) { row, column in
        let x = Double(column - center)
        let y = Double(row - center)
        let distance = sqrt((x * x) + (y * y))
        return distance <= outerRadius && distance >= innerRadius
    }
}

private func laplacian4(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center][center] = -4
        matrix[center - 1][center] = 1
        matrix[center + 1][center] = 1
        matrix[center][center - 1] = 1
        matrix[center][center + 1] = 1
    }
}

private func laplacian8(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        for row in (center - 1)...(center + 1) {
            for column in (center - 1)...(center + 1) {
                matrix[row][column] = 1
            }
        }
        matrix[center][center] = -8
    }
}

private func laplacianOfGaussian(size: Int) -> [[Int]] {
    let center = size / 2
    let sigma = Double(size) / 5.0
    let sigmaSquared = sigma * sigma
    let values = square(size: size) { row, column in
        let x = Double(column - center)
        let y = Double(row - center)
        let radiusSquared = (x * x) + (y * y)
        return ((radiusSquared - (2.0 * sigmaSquared)) / (sigmaSquared * sigmaSquared))
            * exp(-radiusSquared / (2.0 * sigmaSquared))
    }
    return scaledZeroSumMatrix(values)
}

private func differenceOfGaussians(size: Int) -> [[Int]] {
    let center = size / 2
    let narrowSigma = Double(size) / 6.0
    let wideSigma = narrowSigma * 1.6
    let values = square(size: size) { row, column in
        let x = Double(column - center)
        let y = Double(row - center)
        let radiusSquared = (x * x) + (y * y)
        let narrow = exp(-radiusSquared / (2.0 * narrowSigma * narrowSigma)) / (narrowSigma * narrowSigma)
        let wide = exp(-radiusSquared / (2.0 * wideSigma * wideSigma)) / (wideSigma * wideSigma)
        return narrow - wide
    }
    return scaledZeroSumMatrix(values)
}

private func scaledZeroSumMatrix(_ values: [[Double]], maxAbsoluteValue: Int = 32) -> [[Int]] {
    let flattened = values.flatMap { $0 }
    let mean = flattened.reduce(0.0, +) / Double(flattened.count)
    let centered = values.map { row in
        row.map { $0 - mean }
    }
    let maximumMagnitude = centered.flatMap { $0 }.map(abs).max() ?? 0.0
    precondition(maximumMagnitude > 0.0)

    var result = centered.map { row in
        row.map { value in
            Int(round(value / maximumMagnitude * Double(maxAbsoluteValue)))
        }
    }
    let sum = result.flatMap { $0 }.reduce(0, +)
    let center = result.count / 2
    result[center][center] -= sum
    precondition(result.flatMap { $0 }.allSatisfy { $0 >= Int(Int8.min) && $0 <= Int(Int8.max) })
    return result
}

private func centralDifferenceX(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center][center - 1] = -1
        matrix[center][center + 1] = 1
    }
}

private func centralDifferenceY(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center - 1][center] = -1
        matrix[center + 1][center] = 1
    }
}

private func hessianXX(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center][center - 1] = 1
        matrix[center][center] = -2
        matrix[center][center + 1] = 1
    }
}

private func hessianYY(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center - 1][center] = 1
        matrix[center][center] = -2
        matrix[center + 1][center] = 1
    }
}

private func hessianXY(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center - 1][center - 1] = 1
        matrix[center - 1][center + 1] = -1
        matrix[center + 1][center - 1] = -1
        matrix[center + 1][center + 1] = 1
    }
}

private func robertsX(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center][center] = 1
        matrix[center + 1][center + 1] = -1
    }
}

private func robertsY(size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        matrix[center][center + 1] = 1
        matrix[center + 1][center] = -1
    }
}

private func lineDetectorHorizontal(size: Int) -> [[Int]] {
    let center = size / 2
    return square(size: size) { row, _ in
        row == center ? size - 1 : -1
    }
}

private func lineDetectorVertical(size: Int) -> [[Int]] {
    let center = size / 2
    return square(size: size) { _, column in
        column == center ? size - 1 : -1
    }
}

private func lineDetectorDiagonal(size: Int) -> [[Int]] {
    square(size: size) { row, column in
        row == column ? size - 1 : -1
    }
}

private func lineDetectorAntiDiagonal(size: Int) -> [[Int]] {
    square(size: size) { row, column in
        row + column == size - 1 ? size - 1 : -1
    }
}

private func compassKernels(size: Int) -> [KernelFixture] {
    let kirsch: [(String, [[Int]])] = [
        ("kirsch north", [[5, 5, 5], [-3, 0, -3], [-3, -3, -3]]),
        ("kirsch northeast", [[5, 5, -3], [5, 0, -3], [-3, -3, -3]]),
        ("kirsch east", [[5, -3, -3], [5, 0, -3], [5, -3, -3]]),
        ("kirsch southeast", [[-3, -3, -3], [5, 0, -3], [5, 5, -3]]),
        ("kirsch south", [[-3, -3, -3], [-3, 0, -3], [5, 5, 5]]),
        ("kirsch southwest", [[-3, -3, -3], [-3, 0, 5], [-3, 5, 5]]),
        ("kirsch west", [[-3, -3, 5], [-3, 0, 5], [-3, -3, 5]]),
        ("kirsch northwest", [[-3, 5, 5], [-3, 0, 5], [-3, -3, -3]]),
    ]

    let robinson: [(String, [[Int]])] = [
        ("robinson north", [[1, 1, 1], [1, -2, 1], [-1, -1, -1]]),
        ("robinson east", [[1, 1, -1], [1, -2, -1], [1, 1, -1]]),
        ("robinson south", [[-1, -1, -1], [1, -2, 1], [1, 1, 1]]),
        ("robinson west", [[-1, 1, 1], [-1, -2, 1], [-1, 1, 1]]),
    ]

    return (kirsch + robinson).map { name, values in
        KernelFixture.zeroSum("\(name) embedded \(size)x\(size)", embed3x3(values, size: size))
    }
}

private func embed3x3(_ values: [[Int]], size: Int) -> [[Int]] {
    sparse(size: size) { matrix, center in
        for row in 0..<3 {
            for column in 0..<3 {
                matrix[center + row - 1][center + column - 1] = values[row][column]
            }
        }
    }
}

private func sparse(size: Int, fill: (inout [[Int]], Int) -> Void) -> [[Int]] {
    var matrix = Array(repeating: Array(repeating: 0, count: size), count: size)
    fill(&matrix, size / 2)
    return matrix
}
