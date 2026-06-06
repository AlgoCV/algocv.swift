/// Nonlinear reduction selector for the shape-masked grayvalue filter and
/// convenience overloads built on top of `KernelNonlinear`.
public typealias NonlinearTransformation = KernelNonlinear.Transformation

/// A binary mask defining the neighbourhood used by:
///  - the grayvalue shape filter (`Image8Bit.filtered(through:by:)`),
///  - the binary morphology operations (`ImageMono.eroded(by:)` / `dilated(by:)`).
///
/// The mask is independent from the reduction operation — for grayvalue filters
/// the transformation is passed separately; for morphology there is no
/// transformation.
public struct Shape: Sendable, Equatable {
    public let cols: UInt8
    public let rows: UInt8
    public let mask: [[Bool]]

    public init(_ mask: [[Bool]]) throws {
        guard let firstRow = mask.first, !firstRow.isEmpty else {
            throw AlgoCVError.emptyShape
        }
        let cols = firstRow.count
        for row in mask where row.count != cols {
            throw AlgoCVError.emptyShape
        }
        guard mask.contains(where: { $0.contains(true) }) else {
            throw AlgoCVError.emptyShape
        }
        guard cols <= Int(UInt8.max), mask.count <= Int(UInt8.max) else {
            throw AlgoCVError.emptyShape
        }
        self.cols = UInt8(cols)
        self.rows = UInt8(mask.count)
        self.mask = mask
    }

    /// Lifts an existing nonlinear kernel into a `Shape`, discarding its
    /// `Transformation` (which is passed separately for grayvalue filters).
    public init(_ kernel: KernelNonlinear) {
        self.cols = kernel.colCount
        self.rows = kernel.rowCount
        self.mask = kernel.values
    }

    public var activeCount: Int {
        mask.reduce(0) { $0 + $1.lazy.filter { $0 }.count }
    }
}
