#include <metal_stdlib>
using namespace metal;

struct ConvolutionParams {
    uint   cols;
    uint   rows;
    uint   kCols;
    uint   kRows;
    uint   denominator;
};

// Zero-sum linear convolution. Signed weights are read as int8. Output is
// clamped to [0, 255]. Border policy: clamp-to-edge.
kernel void convolve_zero_sum(
    device const uchar       *source    [[ buffer(0) ]],
    device       uchar       *dest      [[ buffer(1) ]],
    device const char        *weights   [[ buffer(2) ]],
    constant ConvolutionParams &params  [[ buffer(3) ]],
    uint2                       gid     [[ thread_position_in_grid ]]
) {
    if (gid.x >= params.cols || gid.y >= params.rows) { return; }

    int halfKx = int(params.kCols) / 2;
    int halfKy = int(params.kRows) / 2;
    int acc = 0;

    for (uint ky = 0; ky < params.kRows; ++ky) {
        int sy = int(gid.y) + int(ky) - halfKy;
        sy = clamp(sy, 0, int(params.rows) - 1);
        for (uint kx = 0; kx < params.kCols; ++kx) {
            int sx = int(gid.x) + int(kx) - halfKx;
            sx = clamp(sx, 0, int(params.cols) - 1);
            int w = int(weights[ky * params.kCols + kx]);
            acc += w * int(source[sy * params.cols + sx]);
        }
    }

    acc = clamp(acc, 0, 255);
    dest[gid.y * params.cols + gid.x] = uchar(acc);
}

// Unit-sum linear convolution. Unsigned weights divided by denominator.
// Border policy: clamp-to-edge.
kernel void convolve_unit_sum(
    device const uchar       *source    [[ buffer(0) ]],
    device       uchar       *dest      [[ buffer(1) ]],
    device const uchar       *weights   [[ buffer(2) ]],
    constant ConvolutionParams &params  [[ buffer(3) ]],
    uint2                       gid     [[ thread_position_in_grid ]]
) {
    if (gid.x >= params.cols || gid.y >= params.rows) { return; }

    int halfKx = int(params.kCols) / 2;
    int halfKy = int(params.kRows) / 2;
    uint acc = 0;

    for (uint ky = 0; ky < params.kRows; ++ky) {
        int sy = int(gid.y) + int(ky) - halfKy;
        sy = clamp(sy, 0, int(params.rows) - 1);
        for (uint kx = 0; kx < params.kCols; ++kx) {
            int sx = int(gid.x) + int(kx) - halfKx;
            sx = clamp(sx, 0, int(params.cols) - 1);
            uint w = uint(weights[ky * params.kCols + kx]);
            acc += w * uint(source[sy * params.cols + sx]);
        }
    }

    uint denom = max(params.denominator, 1u);
    uint result = (acc + denom / 2) / denom;
    dest[gid.y * params.cols + gid.x] = uchar(min(result, 255u));
}
