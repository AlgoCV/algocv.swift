import Metal
import AlgoCVData

extension Image8Bit {
    func toMetalBuffer(device: MTLDevice) throws -> MTLBuffer {
        guard let buffer = pixels.withUnsafeBufferPointer({ ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: pixels.count, options: [.storageModeShared])
        }) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate MTLBuffer for Image8Bit.")
        }
        return buffer
    }

    static func makeDestinationBuffer(cols: UInt16, rows: UInt16, device: MTLDevice) throws -> MTLBuffer {
        let count = Int(cols) * Int(rows)
        guard let buffer = device.makeBuffer(length: count, options: [.storageModeShared]) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate output MTLBuffer for Image8Bit.")
        }
        memset(buffer.contents(), 0, count)
        return buffer
    }

    init(_ buffer: MTLBuffer, cols: UInt16, rows: UInt16) throws {
        let count = Int(cols) * Int(rows)
        let ptr = buffer.contents().assumingMemoryBound(to: UInt8.self)
        let pixels = Array(UnsafeBufferPointer(start: ptr, count: count))
        try self.init(cols: cols, rows: rows, pixels: pixels)
    }
}

extension ImageRGB {
    func toMetalBuffer(device: MTLDevice) throws -> MTLBuffer {
        guard let buffer = pixels.withUnsafeBufferPointer({ ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: pixels.count, options: [.storageModeShared])
        }) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate MTLBuffer for ImageRGB.")
        }
        return buffer
    }

    static func makeDestinationBuffer(cols: UInt16, rows: UInt16, device: MTLDevice) throws -> MTLBuffer {
        let count = Int(cols) * Int(rows) * 3
        guard let buffer = device.makeBuffer(length: count, options: [.storageModeShared]) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate output MTLBuffer for ImageRGB.")
        }
        memset(buffer.contents(), 0, count)
        return buffer
    }

    init(_ buffer: MTLBuffer, cols: UInt16, rows: UInt16) throws {
        let count = Int(cols) * Int(rows) * 3
        let ptr = buffer.contents().assumingMemoryBound(to: UInt8.self)
        let pixels = Array(UnsafeBufferPointer(start: ptr, count: count))
        try self.init(cols: cols, rows: rows, pixels: pixels)
    }
}

extension ImageMono {
    func toMetalBuffer(device: MTLDevice) throws -> MTLBuffer {
        let bytes = words.count * MemoryLayout<UInt32>.size
        guard let buffer = words.withUnsafeBufferPointer({ ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: bytes, options: [.storageModeShared])
        }) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate MTLBuffer for ImageMono.")
        }
        return buffer
    }

    static func makeDestinationBuffer(cols: UInt16, rows: UInt16, device: MTLDevice) throws -> MTLBuffer {
        let stride = (Int(cols) + 31) / 32
        let bytes = stride * Int(rows) * MemoryLayout<UInt32>.size
        guard let buffer = device.makeBuffer(length: bytes, options: [.storageModeShared]) else {
            throw AlgoCVError.backendUnavailable("Failed to allocate output MTLBuffer for ImageMono.")
        }
        memset(buffer.contents(), 0, bytes)
        return buffer
    }

    init(_ buffer: MTLBuffer, cols: UInt16, rows: UInt16) throws {
        let stride = (Int(cols) + 31) / 32
        let count  = stride * Int(rows)
        let ptr    = buffer.contents().assumingMemoryBound(to: UInt32.self)
        let words  = Array(UnsafeBufferPointer(start: ptr, count: count))
        try self.init(cols: cols, rows: rows, words: words)
    }
}
