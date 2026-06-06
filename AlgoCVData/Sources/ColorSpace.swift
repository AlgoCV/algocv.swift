/// Color spaces supported by `ImageRGB.split(into:)` /
/// `ImageRGB.recomposed(from:in:)`. All spaces produce 3 channels except
/// `.cmyk`, which produces 4.
public enum ColorSpace: String, Sendable, CaseIterable, Codable, Equatable {
    case rgb
    case hsv
    case hsl
    case lab
    case cmy
    case cmyk
    case yuv
    case yDbDr
    case yiq
    case yCbCr

    public var channelCount: Int {
        self == .cmyk ? 4 : 3
    }
}
