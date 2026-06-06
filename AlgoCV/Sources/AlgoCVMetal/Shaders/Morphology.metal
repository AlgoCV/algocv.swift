#include <metal_stdlib>
using namespace metal;

struct MorphologyParams {
    uint cols;        // source/dest pixel cols
    uint rows;
    uint stride;      // 32-bit words per row
    uint kCols;
    uint kRows;
};

inline bool read_bit(device const uint *src, uint stride, int x, int y, int cols, int rows) {
    x = clamp(x, 0, cols - 1);
    y = clamp(y, 0, rows - 1);
    uint w = src[uint(y) * stride + uint(x) / 32u];
    return ((w >> (uint(x) % 32u)) & 1u) != 0u;
}

kernel void morph_erode(
    device const uint            *source  [[ buffer(0) ]],
    device       uint            *dest    [[ buffer(1) ]],
    device const uchar           *mask    [[ buffer(2) ]],
    constant MorphologyParams    &params  [[ buffer(3) ]],
    uint2                          gid    [[ thread_position_in_grid ]]
) {
    if (gid.x >= params.cols || gid.y >= params.rows) { return; }

    int halfKx = int(params.kCols) / 2;
    int halfKy = int(params.kRows) / 2;
    bool keep = true;

    for (uint ky = 0; ky < params.kRows && keep; ++ky) {
        for (uint kx = 0; kx < params.kCols && keep; ++kx) {
            if (mask[ky * params.kCols + kx] == 0) { continue; }
            int sx = int(gid.x) + int(kx) - halfKx;
            int sy = int(gid.y) + int(ky) - halfKy;
            if (!read_bit(source, params.stride, sx, sy, int(params.cols), int(params.rows))) {
                keep = false;
            }
        }
    }

    if (keep) {
        uint wIdx = gid.y * params.stride + gid.x / 32u;
        uint bit  = 1u << (gid.x % 32u);
        atomic_fetch_or_explicit(
            (device atomic_uint *)&dest[wIdx],
            bit,
            memory_order_relaxed
        );
    }
}

kernel void morph_dilate(
    device const uint            *source  [[ buffer(0) ]],
    device       uint            *dest    [[ buffer(1) ]],
    device const uchar           *mask    [[ buffer(2) ]],
    constant MorphologyParams    &params  [[ buffer(3) ]],
    uint2                          gid    [[ thread_position_in_grid ]]
) {
    if (gid.x >= params.cols || gid.y >= params.rows) { return; }

    int halfKx = int(params.kCols) / 2;
    int halfKy = int(params.kRows) / 2;
    bool hit = false;

    for (uint ky = 0; ky < params.kRows && !hit; ++ky) {
        for (uint kx = 0; kx < params.kCols && !hit; ++kx) {
            if (mask[ky * params.kCols + kx] == 0) { continue; }
            int sx = int(gid.x) + int(kx) - halfKx;
            int sy = int(gid.y) + int(ky) - halfKy;
            if (read_bit(source, params.stride, sx, sy, int(params.cols), int(params.rows))) {
                hit = true;
            }
        }
    }

    if (hit) {
        uint wIdx = gid.y * params.stride + gid.x / 32u;
        uint bit  = 1u << (gid.x % 32u);
        atomic_fetch_or_explicit(
            (device atomic_uint *)&dest[wIdx],
            bit,
            memory_order_relaxed
        );
    }
}
