import AlgoCVData
import ImPro

extension Spectrum8Bit {
    func toImPro() throws -> ImPro.GraySpectrum {
        try ImPro.GraySpectrum(cols: cols, rows: rows, real: real, imag: imag)
    }

    init(_ source: ImPro.GraySpectrum) throws {
        try self.init(
            cols: source.cols,
            rows: source.rows,
            real: source.readReal(),
            imag: source.readImag()
        )
    }
}

extension Spectrum4Bit {
    init(_ source: ImPro.PaletteSpectrum) throws {
        try self.init(
            cols: source.cols,
            rows: source.rows,
            real: source.readReal(),
            imag: source.readImag()
        )
    }
}
