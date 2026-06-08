import AlgoCVData
import ImPro

extension Histogram {
    init(_ source: ImPro.GrayHistogram) throws {
        try self.init(counts: source.readCounts(), size: source.size)
    }
}
