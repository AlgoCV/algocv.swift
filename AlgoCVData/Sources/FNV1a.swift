public struct FNV1a: Hashable, Sendable {
    public static let offsetBasis: UInt64 = 0xcbf29ce484222325
    public static let seed: UInt64 = Self.offsetBasis
    public static let prime: UInt64 = 0x100000001b3

    public private(set) var digest: UInt64

    public var h: UInt64 {
        digest
    }

    public init(seed: UInt64 = Self.seed) {
        self.digest = seed
    }

    public mutating func mix(_ byte: UInt8) {
        digest = (digest ^ UInt64(byte)) &* Self.prime
    }

    public mutating func mix<Integer>(_ value: Integer) where Integer: FixedWidthInteger {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            mix(contentsOf: bytes)
        }
    }

    public mutating func mix<S>(contentsOf bytes: S) where S: Sequence, S.Element == UInt8 {
        for byte in bytes {
            mix(byte)
        }
    }

    public mutating func mix(_ string: String) {
        mix(contentsOf: string.utf8)
        mix(UInt8(0))
    }
}
