#include <metal_stdlib>
using namespace metal;

struct ShapeFilterParams {
    uint cols;
    uint rows;
    uint kCols;
    uint kRows;
    uint op;        // 0:max 1:min 2:avg 3:hAvg 4:gAvg 5:median 6:and 7:or 8:xor
};

constant uint MAX_TAPS = 256;

kernel void shape_filter_gray(
    device const uchar        *source   [[ buffer(0) ]],
    device       uchar        *dest     [[ buffer(1) ]],
    device const uchar        *mask     [[ buffer(2) ]],   // 0 or 1 per cell
    constant ShapeFilterParams &params  [[ buffer(3) ]],
    uint2                        gid    [[ thread_position_in_grid ]]
) {
    if (gid.x >= params.cols || gid.y >= params.rows) { return; }

    int halfKx = int(params.kCols) / 2;
    int halfKy = int(params.kRows) / 2;

    uchar values[MAX_TAPS];
    uint  count = 0;

    for (uint ky = 0; ky < params.kRows; ++ky) {
        int sy = int(gid.y) + int(ky) - halfKy;
        sy = clamp(sy, 0, int(params.rows) - 1);
        for (uint kx = 0; kx < params.kCols; ++kx) {
            int idx = int(ky * params.kCols + kx);
            if (mask[idx] == 0) { continue; }
            int sx = int(gid.x) + int(kx) - halfKx;
            sx = clamp(sx, 0, int(params.cols) - 1);
            uchar v = source[sy * params.cols + sx];
            if (count < MAX_TAPS) { values[count++] = v; }
        }
    }

    uchar result = 0;
    if (count > 0) {
        switch (params.op) {
            case 0: { // max
                uchar m = 0;
                for (uint i = 0; i < count; ++i) { m = max(m, values[i]); }
                result = m;
                break;
            }
            case 1: { // min
                uchar m = 255;
                for (uint i = 0; i < count; ++i) { m = min(m, values[i]); }
                result = m;
                break;
            }
            case 2: { // avg
                uint s = 0;
                for (uint i = 0; i < count; ++i) { s += uint(values[i]); }
                result = uchar((s + count / 2) / count);
                break;
            }
            case 3: { // hAvg
                float s = 0.0;
                for (uint i = 0; i < count; ++i) {
                    float v = float(values[i]);
                    if (v <= 0.0) { v = 1.0; }
                    s += 1.0 / v;
                }
                float h = float(count) / s;
                result = uchar(clamp(round(h), 0.0, 255.0));
                break;
            }
            case 4: { // gAvg
                float s = 0.0;
                for (uint i = 0; i < count; ++i) {
                    float v = float(values[i]);
                    if (v <= 0.0) { v = 1.0; }
                    s += log(v);
                }
                float g = exp(s / float(count));
                result = uchar(clamp(round(g), 0.0, 255.0));
                break;
            }
            case 5: { // median — selection sort over `count` taps
                uchar buf[MAX_TAPS];
                for (uint i = 0; i < count; ++i) { buf[i] = values[i]; }
                for (uint i = 0; i < count; ++i) {
                    uint minIdx = i;
                    for (uint j = i + 1; j < count; ++j) {
                        if (buf[j] < buf[minIdx]) { minIdx = j; }
                    }
                    uchar tmp = buf[i];
                    buf[i] = buf[minIdx];
                    buf[minIdx] = tmp;
                }
                result = buf[count / 2];
                break;
            }
            case 6: { // and
                uchar r = 0xff;
                for (uint i = 0; i < count; ++i) { r &= values[i]; }
                result = r;
                break;
            }
            case 7: { // or
                uchar r = 0;
                for (uint i = 0; i < count; ++i) { r |= values[i]; }
                result = r;
                break;
            }
            case 8: { // xor
                uchar r = 0;
                for (uint i = 0; i < count; ++i) { r ^= values[i]; }
                result = r;
                break;
            }
            default: result = 0;
        }
    }

    dest[gid.y * params.cols + gid.x] = result;
}
