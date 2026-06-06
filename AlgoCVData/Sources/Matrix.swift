import Foundation

public protocol MatrixElement: Codable, Equatable, Sendable {
    func mix(into hasher: inout FNV1a)
    /// Real-number view of the element used by linear-algebra operations
    /// such as rank / separability detection.
    var doubleValue: Double { get }
}

extension Int8: MatrixElement {
    public func mix(into hasher: inout FNV1a) {
        hasher.mix(UInt8(bitPattern: self))
    }
    public var doubleValue: Double { Double(self) }
}

extension UInt8: MatrixElement {
    public func mix(into hasher: inout FNV1a) {
        hasher.mix(self)
    }
    public var doubleValue: Double { Double(self) }
}

extension Bool: MatrixElement {
    public func mix(into hasher: inout FNV1a) {
        hasher.mix(self ? UInt8(1) : UInt8(0))
    }
    public var doubleValue: Double { self ? 1.0 : 0.0 }
}

public enum MatrixValidationError: Error, Equatable, LocalizedError, Sendable {
    case empty
    case emptyRow(index: Int)
    case raggedRow(index: Int, expected: Int, actual: Int)
    case dimensionTooLarge(columns: Int, rows: Int)
    case zeroDenominator
    case denominatorTooLarge(UInt64)

    public var errorDescription: String? {
        switch self {
        case .empty:
            "Matrix must contain at least one row."
        case .emptyRow(let index):
            "Matrix row \(index) must contain at least one value."
        case .raggedRow(let index, let expected, let actual):
            "Matrix row \(index) has \(actual) values, expected \(expected)."
        case .dimensionTooLarge(let columns, let rows):
            "Matrix dimensions \(columns)x\(rows) exceed UInt8 storage."
        case .zeroDenominator:
            "Unit-sum kernel denominator must be greater than zero."
        case .denominatorTooLarge(let value):
            "Unit-sum kernel denominator \(value) exceeds UInt32 storage."
        }
    }
}

public protocol Matrix: Codable, Equatable, Sendable {
    associatedtype Element: MatrixElement

    var values: [[Element]] { get }
}

public extension Matrix {
    var id: UInt64 {
        matrixHasher().digest
    }

    var colCount: UInt8 {
        UInt8(values.first?.count ?? 0)
    }

    var rowCount: UInt8 {
        UInt8(values.count)
    }

    var cellCount: Int {
        Int(colCount) * Int(rowCount)
    }

    var flattenedValues: [Element] {
        values.flatMap { $0 }
    }

    @discardableResult
    static func validate(_ values: [[Element]]) throws -> (colCount: UInt8, rowCount: UInt8) {
        try validateMatrix(values)
    }

    /// Numerical rank over the reals. Zero matrices report rank 0.
    var rank: Int {
        matrixRank(values)
    }

    /// A kernel is **separable** iff it has rank 1 — i.e. it can be written as
    /// the outer product of a column vector and a row vector (Gaussian, Sobel,
    /// Prewitt, uniform). Laplacian and DoG report `false`.
    var isSeparable: Bool {
        rank == 1
    }

    /// Static variant that operates on raw values, useful while values are
    /// still being edited and may not be a valid `Matrix` instance.
    static func rank(of values: [[Element]], tolerance: Double = 1e-9) -> Int {
        matrixRank(values, tolerance: tolerance)
    }

    static func isSeparable(_ values: [[Element]]) -> Bool {
        rank(of: values) == 1
    }
}

/// Numerical rank of an arbitrary real matrix via Gaussian elimination with
/// partial pivoting. `tolerance` filters away floating-point noise on what
/// should be exact zeros.
public func matrixRank(_ matrix: [[Double]], tolerance: Double = 1e-9) -> Int {
    var m = matrix
    let rows = m.count
    guard rows > 0 else { return 0 }
    let cols = m.first?.count ?? 0
    guard cols > 0 else { return 0 }

    var rank = 0
    var pivotRow = 0
    for col in 0..<cols {
        if pivotRow >= rows { break }

        var maxRow = pivotRow
        for r in (pivotRow + 1)..<rows where abs(m[r][col]) > abs(m[maxRow][col]) {
            maxRow = r
        }
        if abs(m[maxRow][col]) < tolerance {
            continue
        }
        if maxRow != pivotRow {
            m.swapAt(pivotRow, maxRow)
        }
        for r in (pivotRow + 1)..<rows {
            let factor = m[r][col] / m[pivotRow][col]
            if factor == 0 { continue }
            for c in col..<cols {
                m[r][c] -= factor * m[pivotRow][c]
            }
        }
        pivotRow += 1
        rank += 1
    }
    return rank
}

/// Generic rank for any 2D matrix of `MatrixElement` values; converts to
/// `[[Double]]` and forwards to the real-valued kernel above.
public func matrixRank<T: MatrixElement>(_ values: [[T]], tolerance: Double = 1e-9) -> Int {
    let doubles = values.map { row in row.map { $0.doubleValue } }
    return matrixRank(doubles, tolerance: tolerance)
}

internal enum MatrixCodingKeys: String, CodingKey {
    case values
    case denominator
    case nonlinear
}

internal extension Matrix {
    func matrixHasher(kind: KernelKind? = nil) -> FNV1a {
        var hasher = FNV1a()
        if let kind {
            hasher.mix(kind.rawValue)
        }
        hasher.mix(colCount)
        hasher.mix(rowCount)
        for row in values {
            for value in row {
                value.mix(into: &hasher)
            }
        }
        return hasher
    }
}

private func validateMatrix<Element>(_ values: [[Element]]) throws -> (colCount: UInt8, rowCount: UInt8) {
    guard let firstRow = values.first else {
        throw MatrixValidationError.empty
    }
    guard !firstRow.isEmpty else {
        throw MatrixValidationError.emptyRow(index: 0)
    }

    let expectedColumnCount = firstRow.count
    for (index, row) in values.enumerated() {
        guard !row.isEmpty else {
            throw MatrixValidationError.emptyRow(index: index)
        }
        guard row.count == expectedColumnCount else {
            throw MatrixValidationError.raggedRow(
                index: index,
                expected: expectedColumnCount,
                actual: row.count
            )
        }
    }

    guard expectedColumnCount <= Int(UInt8.max), values.count <= Int(UInt8.max) else {
        throw MatrixValidationError.dimensionTooLarge(columns: expectedColumnCount, rows: values.count)
    }

    return (UInt8(expectedColumnCount), UInt8(values.count))
}

internal func preconditionValidMatrix<Element>(_ values: [[Element]]) {
    do {
        _ = try validateMatrix(values)
    } catch {
        preconditionFailure(error.localizedDescription)
    }
}
