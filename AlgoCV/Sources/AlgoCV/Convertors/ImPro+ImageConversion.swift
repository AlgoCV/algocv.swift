import ImPro

extension Image8Bit {
    func toImPro() throws -> ImPro.GrayImage {
        try ImPro.GrayImage(cols: cols, rows: rows, pixels: pixels)
    }

    init(_ source: ImPro.GrayImage) throws {
        try self.init(cols: source.cols, rows: source.rows, pixels: source.readPixels())
    }
}

extension Image4Bit {
    func toImPro() throws -> ImPro.PaletteImage {
        let destination = try ImPro.PaletteImage(cols: cols, rows: rows)
        destination.withUnsafeMutablePackedPixels { dst in
            pixels.withUnsafeBufferPointer { src in
                if let dstBase = dst.baseAddress, let srcBase = src.baseAddress {
                    dstBase.update(from: srcBase, count: min(dst.count, src.count))
                }
            }
        }
        return destination
    }

    init(_ source: ImPro.PaletteImage) throws {
        try self.init(cols: source.cols, rows: source.rows, pixels: source.readPackedPixels())
    }
}

extension ImageMono {
    func toImPro() throws -> ImPro.BinaryImage {
        let destination = try ImPro.BinaryImage(cols: cols, rows: rows)
        try destination.replaceWords(words)
        return destination
    }

    init(_ source: ImPro.BinaryImage) throws {
        try self.init(cols: source.cols, rows: source.rows, words: source.readWords())
    }
}

extension ImageRGB {
    func toImPro() throws -> ImPro.ImgRgb {
        try ImPro.ImgRgb(cols: cols, rows: rows, bytes: pixels)
    }

    init(_ source: ImPro.ImgRgb) throws {
        try self.init(cols: source.cols, rows: source.rows, pixels: source.readBytes())
    }
}
