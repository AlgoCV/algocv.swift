import Foundation

/// Color-space formulas applied on top of the per-channel R/G/B planes produced
/// by `ImPro.ImgRgb.split()`. The formulas mirror those in
/// `ImageProModel/Sources/Operations/ImProOperationExecutor.swift` (around
/// lines 630–1131) byte-for-byte so AlgoCV output equals the current app's.
enum ImProColorFormulas {
    static func decompose(_ space: ColorSpace,
                          r: [UInt8],
                          g: [UInt8],
                          b: [UInt8]) -> [[UInt8]] {
        let count = r.count
        precondition(g.count == count && b.count == count)

        switch space {
        case .rgb:
            return [r, g, b]
        case .cmyk:
            var c = [UInt8](repeating: 0, count: count)
            var m = [UInt8](repeating: 0, count: count)
            var y = [UInt8](repeating: 0, count: count)
            var k = [UInt8](repeating: 0, count: count)
            for i in 0..<count {
                let (cv, mv, yv, kv) = rgbToCMYK(red: r[i], green: g[i], blue: b[i])
                c[i] = cv; m[i] = mv; y[i] = yv; k[i] = kv
            }
            return [c, m, y, k]
        default:
            let convert = decomposer3(for: space)
            var c0 = [UInt8](repeating: 0, count: count)
            var c1 = [UInt8](repeating: 0, count: count)
            var c2 = [UInt8](repeating: 0, count: count)
            for i in 0..<count {
                let (a, b, c) = convert(r[i], g[i], b[i])
                c0[i] = a; c1[i] = b; c2[i] = c
            }
            return [c0, c1, c2]
        }
    }

    static func compose(_ space: ColorSpace,
                        channels: [[UInt8]]) throws -> (r: [UInt8], g: [UInt8], b: [UInt8]) {
        guard channels.count == space.channelCount else {
            throw AlgoCVError.invalidChannelCount(expected: space.channelCount, actual: channels.count)
        }
        let count = channels[0].count
        for plane in channels where plane.count != count {
            throw AlgoCVError.mismatchedChannelDimensions
        }

        var r = [UInt8](repeating: 0, count: count)
        var g = [UInt8](repeating: 0, count: count)
        var b = [UInt8](repeating: 0, count: count)

        switch space {
        case .rgb:
            return (channels[0], channels[1], channels[2])
        case .cmyk:
            for i in 0..<count {
                let (rv, gv, bv) = cmykToRGB(cyan: channels[0][i],
                                             magenta: channels[1][i],
                                             yellow: channels[2][i],
                                             key: channels[3][i])
                r[i] = rv; g[i] = gv; b[i] = bv
            }
        default:
            let convert = composer3(for: space)
            for i in 0..<count {
                let (rv, gv, bv) = convert(channels[0][i], channels[1][i], channels[2][i])
                r[i] = rv; g[i] = gv; b[i] = bv
            }
        }
        return (r, g, b)
    }

    // MARK: - per-pixel decomposers (3-channel spaces)

    private static func decomposer3(for space: ColorSpace) -> (UInt8, UInt8, UInt8) -> (UInt8, UInt8, UInt8) {
        switch space {
        case .hsv:   return rgbToHSV
        case .hsl:   return rgbToHSL
        case .lab:   return rgbToLab
        case .cmy:   return rgbToCMY
        case .yuv:   return rgbToYUV
        case .yDbDr: return rgbToYDbDr
        case .yiq:   return rgbToYIQ
        case .yCbCr: return rgbToYCbCr
        case .rgb, .cmyk:
            preconditionFailure("decomposer3 called on \(space)")
        }
    }

    private static func composer3(for space: ColorSpace) -> (UInt8, UInt8, UInt8) -> (UInt8, UInt8, UInt8) {
        switch space {
        case .hsv:   return hsvToRGB
        case .hsl:   return hslToRGB
        case .lab:   return labToRGB
        case .cmy:   return cmyToRGB
        case .yuv:   return yuvToRGB
        case .yDbDr: return ydbdrToRGB
        case .yiq:   return yiqToRGB
        case .yCbCr: return ycbcrToRGB
        case .rgb, .cmyk:
            preconditionFailure("composer3 called on \(space)")
        }
    }

    // MARK: - helpers

    private static func normalized(_ value: UInt8) -> Double { Double(value) / 255 }

    private static func encodedChannel(_ value: Double) -> UInt8 {
        UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded()))
    }

    private static func encodedByte(_ value: Double) -> UInt8 {
        UInt8(clamping: Int(value.rounded()))
    }

    private static func encodedSigned(_ value: Double, range: Double) -> UInt8 {
        encodedChannel((value / range + 1) / 2)
    }

    private static func decodedSigned(_ encoded: UInt8, range: Double) -> Double {
        (Double(encoded) / 255 * 2 - 1) * range
    }

    private static func encodedAB(_ value: Double) -> UInt8 {
        UInt8(clamping: Int((value + 128).rounded()))
    }

    private static func decodedAB(_ encoded: UInt8) -> Double {
        Double(encoded) - 128
    }

    private static func srgbToLinear(_ v: Double) -> Double {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ v: Double) -> Double {
        let c = min(max(v, 0), 1)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }

    private static func labF(_ t: Double) -> Double {
        let delta = 6.0 / 29.0
        return t > delta * delta * delta
            ? pow(t, 1.0 / 3.0)
            : t / (3 * delta * delta) + 4.0 / 29.0
    }

    private static func labFInverse(_ t: Double) -> Double {
        let delta = 6.0 / 29.0
        return t > delta ? t * t * t : 3 * delta * delta * (t - 4.0 / 29.0)
    }

    private static func rgbHue(red r: Double, green g: Double, blue b: Double,
                               maxValue: Double, delta: Double) -> Double {
        guard delta != 0 else { return 0 }
        let hue: Double
        if maxValue == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == g {
            hue = ((b - r) / delta) + 2
        } else {
            hue = ((r - g) / delta) + 4
        }
        let n = hue / 6
        return n < 0 ? n + 1 : n
    }

    private static func hueSector(huePrime hp: Double, chroma c: Double, x: Double) -> (Double, Double, Double) {
        switch hp {
        case 0..<1: return (c, x, 0)
        case 1..<2: return (x, c, 0)
        case 2..<3: return (0, c, x)
        case 3..<4: return (0, x, c)
        case 4..<5: return (x, 0, c)
        default:    return (c, 0, x)
        }
    }

    // MARK: - HSV / HSL

    private static func rgbToHSV(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let r = normalized(red), g = normalized(green), b = normalized(blue)
        let mx = max(r, g, b), mn = min(r, g, b), delta = mx - mn
        let hue = rgbHue(red: r, green: g, blue: b, maxValue: mx, delta: delta)
        let sat = mx == 0 ? 0 : delta / mx
        return (encodedChannel(hue), encodedChannel(sat), encodedChannel(mx))
    }

    private static func rgbToHSL(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let r = normalized(red), g = normalized(green), b = normalized(blue)
        let mx = max(r, g, b), mn = min(r, g, b), delta = mx - mn
        let l = (mx + mn) / 2
        let hue = rgbHue(red: r, green: g, blue: b, maxValue: mx, delta: delta)
        let sat = delta == 0 ? 0 : delta / (1 - abs(2 * l - 1))
        return (encodedChannel(hue), encodedChannel(sat), encodedChannel(l))
    }

    private static func hsvToRGB(_ hue: UInt8, _ sat: UInt8, _ val: UInt8) -> (UInt8, UInt8, UInt8) {
        let h = normalized(hue), s = normalized(sat), v = normalized(val)
        let chroma = v * s, hp = h * 6
        let x = chroma * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let rgb = hueSector(huePrime: hp, chroma: chroma, x: x)
        let m = v - chroma
        return (encodedChannel(rgb.0 + m), encodedChannel(rgb.1 + m), encodedChannel(rgb.2 + m))
    }

    private static func hslToRGB(_ hue: UInt8, _ sat: UInt8, _ light: UInt8) -> (UInt8, UInt8, UInt8) {
        let h = normalized(hue), s = normalized(sat), l = normalized(light)
        let chroma = (1 - abs(2 * l - 1)) * s, hp = h * 6
        let x = chroma * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let rgb = hueSector(huePrime: hp, chroma: chroma, x: x)
        let m = l - chroma / 2
        return (encodedChannel(rgb.0 + m), encodedChannel(rgb.1 + m), encodedChannel(rgb.2 + m))
    }

    // MARK: - CMY / CMYK

    private static func rgbToCMY(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> (UInt8, UInt8, UInt8) {
        (255 &- r, 255 &- g, 255 &- b)
    }

    private static func cmyToRGB(_ c: UInt8, _ m: UInt8, _ y: UInt8) -> (UInt8, UInt8, UInt8) {
        (255 &- c, 255 &- m, 255 &- y)
    }

    private static func rgbToCMYK(red: UInt8, green: UInt8, blue: UInt8) -> (UInt8, UInt8, UInt8, UInt8) {
        let r = normalized(red), g = normalized(green), b = normalized(blue)
        let k = 1 - max(r, g, b)
        guard k < 1 else { return (0, 0, 0, 255) }
        let d = 1 - k
        return (
            encodedChannel((1 - r - k) / d),
            encodedChannel((1 - g - k) / d),
            encodedChannel((1 - b - k) / d),
            encodedChannel(k)
        )
    }

    private static func cmykToRGB(cyan: UInt8, magenta: UInt8, yellow: UInt8, key: UInt8) -> (UInt8, UInt8, UInt8) {
        let c = normalized(cyan), m = normalized(magenta), y = normalized(yellow), k = normalized(key)
        let omk = 1 - k
        return (encodedChannel((1 - c) * omk),
                encodedChannel((1 - m) * omk),
                encodedChannel((1 - y) * omk))
    }

    // MARK: - YUV / YDbDr / YIQ / YCbCr

    private static let yuvUMax = 0.436
    private static let yuvVMax = 0.615

    private static func rgbToYUV(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let r = normalized(red), g = normalized(green), b = normalized(blue)
        let y = 0.299 * r + 0.587 * g + 0.114 * b
        let u = 0.492 * (b - y)
        let v = 0.877 * (r - y)
        return (encodedChannel(y), encodedSigned(u, range: yuvUMax), encodedSigned(v, range: yuvVMax))
    }

    private static func yuvToRGB(_ yByte: UInt8, _ uByte: UInt8, _ vByte: UInt8) -> (UInt8, UInt8, UInt8) {
        let y = normalized(yByte)
        let u = decodedSigned(uByte, range: yuvUMax)
        let v = decodedSigned(vByte, range: yuvVMax)
        return (encodedChannel(y + 1.13983 * v),
                encodedChannel(y - 0.39465 * u - 0.58060 * v),
                encodedChannel(y + 2.03211 * u))
    }

    private static let ydbdrMax = 1.333

    private static func rgbToYDbDr(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let r = normalized(red), g = normalized(green), b = normalized(blue)
        let y  =  0.299 * r + 0.587 * g + 0.114 * b
        let db = -0.450 * r - 0.883 * g + 1.333 * b
        let dr = -1.333 * r + 1.116 * g + 0.217 * b
        return (encodedChannel(y), encodedSigned(db, range: ydbdrMax), encodedSigned(dr, range: ydbdrMax))
    }

    private static func ydbdrToRGB(_ yByte: UInt8, _ dbByte: UInt8, _ drByte: UInt8) -> (UInt8, UInt8, UInt8) {
        let y = normalized(yByte)
        let db = decodedSigned(dbByte, range: ydbdrMax)
        let dr = decodedSigned(drByte, range: ydbdrMax)
        return (encodedChannel(y + 0.000092 * db - 0.525913 * dr),
                encodedChannel(y - 0.129132 * db + 0.267899 * dr),
                encodedChannel(y + 0.664679 * db - 0.000079 * dr))
    }

    private static let yiqIMax = 0.5957
    private static let yiqQMax = 0.5226

    private static func rgbToYIQ(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let r = normalized(red), g = normalized(green), b = normalized(blue)
        let y = 0.299 * r + 0.587 * g + 0.114 * b
        let i = 0.5959 * r - 0.2746 * g - 0.3213 * b
        let q = 0.2115 * r - 0.5227 * g + 0.3112 * b
        return (encodedChannel(y), encodedSigned(i, range: yiqIMax), encodedSigned(q, range: yiqQMax))
    }

    private static func yiqToRGB(_ yByte: UInt8, _ iByte: UInt8, _ qByte: UInt8) -> (UInt8, UInt8, UInt8) {
        let y = normalized(yByte)
        let i = decodedSigned(iByte, range: yiqIMax)
        let q = decodedSigned(qByte, range: yiqQMax)
        return (encodedChannel(y + 0.956 * i + 0.619 * q),
                encodedChannel(y - 0.272 * i - 0.647 * q),
                encodedChannel(y - 1.106 * i + 1.703 * q))
    }

    private static func rgbToYCbCr(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let r = Double(red), g = Double(green), b = Double(blue)
        let y  = 0.299 * r + 0.587 * g + 0.114 * b
        let cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
        let cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
        return (encodedByte(y), encodedByte(cb), encodedByte(cr))
    }

    private static func ycbcrToRGB(_ yByte: UInt8, _ cbByte: UInt8, _ crByte: UInt8) -> (UInt8, UInt8, UInt8) {
        let y = Double(yByte), cb = Double(cbByte) - 128, cr = Double(crByte) - 128
        return (encodedByte(y + 1.402 * cr),
                encodedByte(y - 0.344136 * cb - 0.714136 * cr),
                encodedByte(y + 1.772 * cb))
    }

    // MARK: - CIE Lab (D65, sRGB primaries)

    private static let labXn = 0.95047
    private static let labYn = 1.00000
    private static let labZn = 1.08883

    private static func rgbToLab(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> (UInt8, UInt8, UInt8) {
        let r = srgbToLinear(normalized(red))
        let g = srgbToLinear(normalized(green))
        let b = srgbToLinear(normalized(blue))
        let x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
        let fx = labF(x / labXn), fy = labF(y / labYn), fz = labF(z / labZn)
        let lStar = 116 * fy - 16
        let aStar = 500 * (fx - fy)
        let bStar = 200 * (fy - fz)
        let lEnc = UInt8(clamping: Int((min(max(lStar / 100, 0), 1) * 255).rounded()))
        return (lEnc, encodedAB(aStar), encodedAB(bStar))
    }

    private static func labToRGB(_ lByte: UInt8, _ aByte: UInt8, _ bByte: UInt8) -> (UInt8, UInt8, UInt8) {
        let lStar = (Double(lByte) / 255) * 100
        let aStar = decodedAB(aByte), bStar = decodedAB(bByte)
        let fy = (lStar + 16) / 116
        let fx = aStar / 500 + fy
        let fz = fy - bStar / 200
        let x = labXn * labFInverse(fx)
        let y = labYn * labFInverse(fy)
        let z = labZn * labFInverse(fz)
        let r =  3.2404542 * x - 1.5371385 * y - 0.4985314 * z
        let g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
        let b =  0.0556434 * x - 0.2040259 * y + 1.0572252 * z
        return (encodedChannel(linearToSRGB(r)),
                encodedChannel(linearToSRGB(g)),
                encodedChannel(linearToSRGB(b)))
    }
}
