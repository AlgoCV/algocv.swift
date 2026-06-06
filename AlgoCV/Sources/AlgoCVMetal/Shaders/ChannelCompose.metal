#include <metal_stdlib>
using namespace metal;

struct ComposeParams {
    uint cols;
    uint rows;
    uint pixelCount;
    uint colorSpace;
    uint channelCount; // 3 or 4
};

inline float n8(uchar v)            { return float(v) / 255.0; }
inline uchar enc01(float v)         { return uchar(clamp(round(v * 255.0), 0.0, 255.0)); }
inline uchar encByte(float v)       { return uchar(clamp(round(v), 0.0, 255.0)); }
inline float decSigned(uchar v, float r) { return (n8(v) * 2.0 - 1.0) * r; }
inline float decAB(uchar v)         { return float(v) - 128.0; }

inline float linearToSRGB(float v) {
    float c = clamp(v, 0.0, 1.0);
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

inline float labFInv(float t) {
    float d = 6.0 / 29.0;
    return t > d ? t * t * t : 3.0 * d * d * (t - 4.0 / 29.0);
}

inline float3 hueSector(float hp, float c, float x) {
    if (hp < 1.0)      return float3(c, x, 0);
    else if (hp < 2.0) return float3(x, c, 0);
    else if (hp < 3.0) return float3(0, c, x);
    else if (hp < 4.0) return float3(0, x, c);
    else if (hp < 5.0) return float3(x, 0, c);
    else               return float3(c, 0, x);
}

kernel void channel_compose(
    device const uchar         *source  [[ buffer(0) ]],   // N×planar (channelCount * pixelCount)
    device       uchar         *dest    [[ buffer(1) ]],   // interleaved RGB
    constant ComposeParams     &params  [[ buffer(2) ]],
    uint                         gid    [[ thread_position_in_grid ]]
) {
    if (gid >= params.pixelCount) { return; }

    uchar c0 = source[0 * params.pixelCount + gid];
    uchar c1 = source[1 * params.pixelCount + gid];
    uchar c2 = source[2 * params.pixelCount + gid];
    uchar c3 = params.channelCount == 4 ? source[3 * params.pixelCount + gid] : 0;

    uchar r = 0, g = 0, b = 0;

    switch (params.colorSpace) {
    case 0: { r = c0; g = c1; b = c2; break; }
    case 1: { // hsv → rgb
        float h = n8(c0), s = n8(c1), v = n8(c2);
        float chroma = v * s;
        float hp = h * 6.0;
        float x = chroma * (1.0 - abs(fmod(hp, 2.0) - 1.0));
        float3 rgb = hueSector(hp, chroma, x);
        float m = v - chroma;
        r = enc01(rgb.x + m); g = enc01(rgb.y + m); b = enc01(rgb.z + m);
        break;
    }
    case 2: { // hsl → rgb
        float h = n8(c0), s = n8(c1), l = n8(c2);
        float chroma = (1.0 - abs(2.0 * l - 1.0)) * s;
        float hp = h * 6.0;
        float x = chroma * (1.0 - abs(fmod(hp, 2.0) - 1.0));
        float3 rgb = hueSector(hp, chroma, x);
        float m = l - chroma * 0.5;
        r = enc01(rgb.x + m); g = enc01(rgb.y + m); b = enc01(rgb.z + m);
        break;
    }
    case 3: { // lab → rgb
        float L = n8(c0) * 100.0;
        float A = decAB(c1), B = decAB(c2);
        float fy = (L + 16.0) / 116.0;
        float fx = A / 500.0 + fy;
        float fz = fy - B / 200.0;
        float x = 0.95047 * labFInv(fx);
        float y = 1.00000 * labFInv(fy);
        float z = 1.08883 * labFInv(fz);
        float rl =  3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
        float gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
        float bl =  0.0556434 * x - 0.2040259 * y + 1.0572252 * z;
        r = enc01(linearToSRGB(rl));
        g = enc01(linearToSRGB(gl));
        b = enc01(linearToSRGB(bl));
        break;
    }
    case 4: { // cmy → rgb
        r = 255 - c0; g = 255 - c1; b = 255 - c2; break;
    }
    case 5: { // cmyk → rgb
        float c = n8(c0), m = n8(c1), y = n8(c2), k = n8(c3);
        float omk = 1.0 - k;
        r = enc01((1.0 - c) * omk);
        g = enc01((1.0 - m) * omk);
        b = enc01((1.0 - y) * omk);
        break;
    }
    case 6: { // yuv → rgb
        float y = n8(c0);
        float u = decSigned(c1, 0.436);
        float v = decSigned(c2, 0.615);
        r = enc01(y + 1.13983 * v);
        g = enc01(y - 0.39465 * u - 0.58060 * v);
        b = enc01(y + 2.03211 * u);
        break;
    }
    case 7: { // yDbDr → rgb
        float y = n8(c0);
        float db = decSigned(c1, 1.333);
        float dr = decSigned(c2, 1.333);
        r = enc01(y + 0.000092 * db - 0.525913 * dr);
        g = enc01(y - 0.129132 * db + 0.267899 * dr);
        b = enc01(y + 0.664679 * db - 0.000079 * dr);
        break;
    }
    case 8: { // yiq → rgb
        float y = n8(c0);
        float i = decSigned(c1, 0.5957);
        float q = decSigned(c2, 0.5226);
        r = enc01(y + 0.956 * i + 0.619 * q);
        g = enc01(y - 0.272 * i - 0.647 * q);
        b = enc01(y - 1.106 * i + 1.703 * q);
        break;
    }
    case 9: { // yCbCr → rgb
        float y = float(c0);
        float cb = float(c1) - 128.0;
        float cr = float(c2) - 128.0;
        r = encByte(y + 1.402 * cr);
        g = encByte(y - 0.344136 * cb - 0.714136 * cr);
        b = encByte(y + 1.772 * cb);
        break;
    }
    }

    dest[gid * 3 + 0] = r;
    dest[gid * 3 + 1] = g;
    dest[gid * 3 + 2] = b;
}
