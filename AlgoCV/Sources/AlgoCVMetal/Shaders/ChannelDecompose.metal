#include <metal_stdlib>
using namespace metal;

struct DecomposeParams {
    uint cols;
    uint rows;
    uint pixelCount;
    uint colorSpace;   // see ColorSpace codes below
    uint channelCount; // 3 or 4
};

// ColorSpace codes (kept in sync with the Swift enum order):
// 0 rgb, 1 hsv, 2 hsl, 3 lab, 4 cmy, 5 cmyk,
// 6 yuv, 7 yDbDr, 8 yiq, 9 yCbCr

// All conversions follow the formulas in
// ImageProModel/Sources/Operations/ImProOperationExecutor.swift:630..1131.

inline float n8(uchar v)            { return float(v) / 255.0; }
inline uchar enc01(float v)         { return uchar(clamp(round(v * 255.0), 0.0, 255.0)); }
inline uchar encByte(float v)       { return uchar(clamp(round(v), 0.0, 255.0)); }
inline uchar encSigned(float v, float r) { return enc01((v / r + 1.0) * 0.5); }
inline uchar encAB(float v)         { return uchar(clamp(round(v + 128.0), 0.0, 255.0)); }

inline float rgbHue(float r, float g, float b, float mx, float delta) {
    if (delta == 0.0) { return 0.0; }
    float h;
    if (mx == r)      { h = fmod((g - b) / delta, 6.0); }
    else if (mx == g) { h = ((b - r) / delta) + 2.0; }
    else              { h = ((r - g) / delta) + 4.0; }
    float n = h / 6.0;
    return n < 0.0 ? n + 1.0 : n;
}

inline float labF(float t) {
    float d = 6.0 / 29.0;
    return t > d * d * d ? pow(t, 1.0 / 3.0) : t / (3.0 * d * d) + 4.0 / 29.0;
}

inline float srgbToLinear(float v) {
    return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
}

inline void writeDest(device uchar *dest,
                      uint channelCount,
                      uint pixelCount,
                      uint pixel,
                      uchar c0, uchar c1, uchar c2, uchar c3) {
    dest[0 * pixelCount + pixel] = c0;
    dest[1 * pixelCount + pixel] = c1;
    dest[2 * pixelCount + pixel] = c2;
    if (channelCount == 4) {
        dest[3 * pixelCount + pixel] = c3;
    }
}

kernel void channel_decompose(
    device const uchar         *source  [[ buffer(0) ]],   // interleaved RGB
    device       uchar         *dest    [[ buffer(1) ]],   // N×planar (channelCount * pixelCount)
    constant DecomposeParams   &params  [[ buffer(2) ]],
    uint                         gid    [[ thread_position_in_grid ]]
) {
    if (gid >= params.pixelCount) { return; }

    uchar r = source[gid * 3 + 0];
    uchar g = source[gid * 3 + 1];
    uchar b = source[gid * 3 + 2];

    switch (params.colorSpace) {
    case 0: { // rgb
        writeDest(dest, params.channelCount, params.pixelCount, gid, r, g, b, 0);
        break;
    }
    case 1: { // hsv
        float rf = n8(r), gf = n8(g), bf = n8(b);
        float mx = max(rf, max(gf, bf)), mn = min(rf, min(gf, bf)), delta = mx - mn;
        float hue = rgbHue(rf, gf, bf, mx, delta);
        float sat = mx == 0.0 ? 0.0 : delta / mx;
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  enc01(hue), enc01(sat), enc01(mx), 0);
        break;
    }
    case 2: { // hsl
        float rf = n8(r), gf = n8(g), bf = n8(b);
        float mx = max(rf, max(gf, bf)), mn = min(rf, min(gf, bf)), delta = mx - mn;
        float l = (mx + mn) * 0.5;
        float hue = rgbHue(rf, gf, bf, mx, delta);
        float sat = delta == 0.0 ? 0.0 : delta / (1.0 - abs(2.0 * l - 1.0));
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  enc01(hue), enc01(sat), enc01(l), 0);
        break;
    }
    case 3: { // lab
        float rl = srgbToLinear(n8(r));
        float gl = srgbToLinear(n8(g));
        float bl = srgbToLinear(n8(b));
        float x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl;
        float y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl;
        float z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl;
        float fx = labF(x / 0.95047);
        float fy = labF(y / 1.00000);
        float fz = labF(z / 1.08883);
        float L = 116.0 * fy - 16.0;
        float A = 500.0 * (fx - fy);
        float B = 200.0 * (fy - fz);
        uchar lEnc = uchar(clamp(round(L / 100.0 * 255.0), 0.0, 255.0));
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  lEnc, encAB(A), encAB(B), 0);
        break;
    }
    case 4: { // cmy
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  255 - r, 255 - g, 255 - b, 0);
        break;
    }
    case 5: { // cmyk
        float rf = n8(r), gf = n8(g), bf = n8(b);
        float k = 1.0 - max(rf, max(gf, bf));
        uchar c0, c1, c2, c3;
        if (k >= 1.0) {
            c0 = 0; c1 = 0; c2 = 0; c3 = 255;
        } else {
            float d = 1.0 - k;
            c0 = enc01((1.0 - rf - k) / d);
            c1 = enc01((1.0 - gf - k) / d);
            c2 = enc01((1.0 - bf - k) / d);
            c3 = enc01(k);
        }
        writeDest(dest, params.channelCount, params.pixelCount, gid, c0, c1, c2, c3);
        break;
    }
    case 6: { // yuv
        float rf = n8(r), gf = n8(g), bf = n8(b);
        float y = 0.299 * rf + 0.587 * gf + 0.114 * bf;
        float u = 0.492 * (bf - y);
        float v = 0.877 * (rf - y);
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  enc01(y), encSigned(u, 0.436), encSigned(v, 0.615), 0);
        break;
    }
    case 7: { // yDbDr
        float rf = n8(r), gf = n8(g), bf = n8(b);
        float y  =  0.299 * rf + 0.587 * gf + 0.114 * bf;
        float db = -0.450 * rf - 0.883 * gf + 1.333 * bf;
        float dr = -1.333 * rf + 1.116 * gf + 0.217 * bf;
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  enc01(y), encSigned(db, 1.333), encSigned(dr, 1.333), 0);
        break;
    }
    case 8: { // yiq
        float rf = n8(r), gf = n8(g), bf = n8(b);
        float y = 0.299 * rf + 0.587 * gf + 0.114 * bf;
        float i = 0.5959 * rf - 0.2746 * gf - 0.3213 * bf;
        float q = 0.2115 * rf - 0.5227 * gf + 0.3112 * bf;
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  enc01(y), encSigned(i, 0.5957), encSigned(q, 0.5226), 0);
        break;
    }
    case 9: { // yCbCr
        float rf = float(r), gf = float(g), bf = float(b);
        float y  = 0.299 * rf + 0.587 * gf + 0.114 * bf;
        float cb = 128.0 - 0.168736 * rf - 0.331264 * gf + 0.5 * bf;
        float cr = 128.0 + 0.5 * rf - 0.418688 * gf - 0.081312 * bf;
        writeDest(dest, params.channelCount, params.pixelCount, gid,
                  encByte(y), encByte(cb), encByte(cr), 0);
        break;
    }
    default:
        writeDest(dest, params.channelCount, params.pixelCount, gid, 0, 0, 0, 0);
    }
}
