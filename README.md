# algocv.swift

## Running the benchmarks

Throughput benchmarks for the Metal, ImPro and vImage backends live in
`AlgoCV/Tests/KernelBenchmarks.swift`. They are regular Swift Testing tests, so
they run via `swift test` or Xcode's test runner — they just print timing tables
to stdout instead of asserting anything.

The three backends are: **Metal** (GPU compute shaders), **ImPro** (single-thread
SIMD CPU library) and **vImage(1T)** — Apple's vImage pinned to a single thread
via `kvImageDoNotTile`, used as the deterministic single-core CPU reference that
Metal itself does not expose. vImage only natively supports 8-bit grayvalue
linear convolution, so the 4-bit grayvalue and binary morphology tables only
compare Metal vs ImPro.

From the command line, in the `AlgoCV` package directory:

```sh
# Run the whole benchmark suite
swift test --filter "Backend throughput benchmarks"

# Or one benchmark at a time
swift test --filter "KernelBenchmarks/unitSum8BitThroughput"
swift test --filter "KernelBenchmarks/zeroSum8BitThroughput"
swift test --filter "KernelBenchmarks/unitSum4BitThroughput"
swift test --filter "KernelBenchmarks/zeroSum4BitThroughput"
swift test --filter "KernelBenchmarks/erodeBinaryThroughput"
swift test --filter "KernelBenchmarks/dilateBinaryThroughput"
```

From Xcode: select the `AlgoCV` scheme, open the Test navigator, and run the
six tests under **Backend throughput benchmarks**. Timing tables appear in
the test report's console output.

Image size, warmup count, iteration count, and the kernel sides under test are
configured at the top of `KernelBenchmarks.swift` (`imageSide`, `warmup`,
`iterations`, `kernelSides`). Increase `iterations` for tighter measurements;
reduce `imageSide` if a run on a slow machine takes too long.

The suite is automatically disabled when no Metal device is available
(non-Apple hosts). Metal itself does not expose a CPU-only execution mode —
vImage with `kvImageDoNotTile` fills that gap as the single-core CPU reference.

## Reference results

Captured on a 1024×1024 image with 5 measured iterations after 2 warmups. All
times are average milliseconds per call. Lower is better.

### Unit-sum convolution on `Image8Bit`

```
kernel             Metal     ImPro  vImage(1T)   ImPro/Metal   ImPro/vImage
uniform 3×3        1.612     5.005     1.434          3.11x          3.49x
gaussian 3×3       0.615     5.070     1.437          8.25x          3.53x
pyramid 3×3        0.588     4.864     1.092          8.27x          4.45x
cone 3×3           0.676     4.858     1.130          7.19x          4.30x
disc 3×3           0.413     5.009     1.421         12.13x          3.53x
cross 3×3          0.509     4.915     1.370          9.65x          3.59x
uniform 5×5        0.644     4.096     1.903          6.36x          2.15x
gaussian 5×5       0.886     4.115     1.899          4.65x          2.17x
pyramid 5×5        0.694     4.040     1.487          5.82x          2.72x
cone 5×5           1.267     4.105     1.550          3.24x          2.65x
disc 5×5           0.592     4.129     1.921          6.97x          2.15x
cross 5×5          0.591     4.104     1.726          6.95x          2.38x
uniform 7×7        1.385    14.880     3.334         10.74x          4.46x
gaussian 7×7       0.700    14.873     3.415         21.25x          4.36x
pyramid 7×7        0.670    14.740     2.776         22.02x          5.31x
cone 7×7           1.392    14.918     2.700         10.72x          5.52x
disc 7×7           1.350    14.917     3.384         11.05x          4.41x
cross 7×7          1.122    14.895     2.381         13.28x          6.26x
uniform 9×9        1.447    24.325     4.379         16.81x          5.55x
gaussian 9×9       1.314    24.217     4.373         18.43x          5.54x
pyramid 9×9        1.462    24.330     3.608         16.64x          6.74x
cone 9×9           1.506    24.247     3.519         16.10x          6.89x
disc 9×9           1.512    24.271     4.172         16.06x          5.82x
cross 9×9          0.751    24.198     2.907         32.21x          8.33x
uniform 11×11      1.505    37.479     6.817         24.91x          5.50x
gaussian 11×11     1.580    37.327     6.775         23.63x          5.51x
pyramid 11×11      1.313    37.938     5.857         28.88x          6.48x
cone 11×11         1.430    37.643     5.523         26.33x          6.82x
disc 11×11         1.492    37.757     6.423         25.30x          5.88x
cross 11×11        1.599    37.588     3.663         23.51x         10.26x
```

### Zero-sum convolution on `Image8Bit`

```
kernel             Metal     ImPro  vImage(1T)   ImPro/Metal   ImPro/vImage
laplacian4 3×3     1.550     3.075     1.376          1.98x          2.23x
laplacian8 3×3     1.344     3.143     1.513          2.34x          2.08x
sobelX 3×3         1.280     3.039     1.396          2.37x          2.18x
sobelY 3×3         0.610     3.050     1.257          5.00x          2.43x
prewittX 3×3       1.231     3.046     1.414          2.48x          2.15x
prewittY 3×3       0.544     3.036     1.312          5.58x          2.31x
laplacian4 5×5     0.602     6.709     1.454         11.15x          4.61x
laplacian8 5×5     1.216     6.654     1.542          5.47x          4.31x
sobelX 5×5         1.242     6.637     1.885          5.34x          3.52x
sobelY 5×5         1.185     6.561     1.743          5.54x          3.76x
prewittX 5×5       1.325     6.654     1.817          5.02x          3.66x
prewittY 5×5       1.158     6.685     1.800          5.77x          3.71x
laplacian4 7×7     1.339    11.842     1.797          8.84x          6.59x
laplacian8 7×7     0.757    11.840     2.174         15.64x          5.45x
sobelX 7×7         1.242    11.681     3.395          9.41x          3.44x
sobelY 7×7         0.725    11.716     3.060         16.15x          3.83x
prewittX 7×7       0.702    11.945     3.376         17.01x          3.54x
prewittY 7×7       1.367    11.985     3.097          8.77x          3.87x
laplacian4 9×9     1.550    18.805     1.997         12.13x          9.41x
laplacian8 9×9     0.684    18.780     2.261         27.45x          8.31x
sobelX 9×9         1.391    18.774     4.174         13.50x          4.50x
sobelY 9×9         0.799    18.695     4.008         23.41x          4.66x
prewittX 9×9       0.866    18.713     4.165         21.60x          4.49x
prewittY 9×9       0.734    18.738     4.134         25.52x          4.53x
laplacian4 11×11   1.490    27.318     2.216         18.34x         12.33x
laplacian8 11×11   1.601    27.282     2.238         17.04x         12.19x
sobelX 11×11       1.546    27.298     6.906         17.66x          3.95x
sobelY 11×11       1.504    27.324     6.452         18.17x          4.24x
prewittX 11×11     1.163    27.248     6.796         23.42x          4.01x
prewittY 11×11     1.434    27.237     6.446         19.00x          4.23x
dogOneStep 5×5     0.662     6.683     1.950         10.10x          3.43x
dogOneStep 7×7     0.714     0.027*    3.362          0.04x*         0.01x*
dogOneStep 9×9     0.658     0.029*    4.340          0.04x*         0.01x*
dogOneStep 11×11   1.176     0.032*    6.873          0.03x*         0.00x*
dogTwoStep 7×7     1.096     0.027*    3.287          0.02x*         0.01x*
dogTwoStep 9×9     0.645     0.033*    4.278          0.05x*         0.01x*
dogTwoStep 11×11   1.494     0.032*    6.688          0.02x*         0.00x*
```

`*` ImPro silently throws on these DoG kernels (`try?` returns `nil`), so the
0.02–0.03 ms numbers are the cost of the throw, not real convolution time —
ImPro's `Kernel` validator rejects the kernels because the Int8 rounding leaves
the signed sum just shy of zero. Tracked as an upstream ImPro C-library bug.

### Unit-sum convolution on `Image4Bit` (Metal goes through 4→8→4 round-trip)

```
kernel             Metal     ImPro   ImPro/Metal
uniform 3×3      357.648     1.554        0.00x
gaussian 3×3     348.835     1.510        0.00x
pyramid 3×3      287.027     1.617        0.01x
cone 3×3         281.230     1.596        0.01x
disc 3×3         298.444     1.541        0.01x
cross 3×3        276.883     1.574        0.01x
uniform 5×5      310.292     5.204        0.02x
gaussian 5×5     279.693     5.295        0.02x
pyramid 5×5      290.502     5.188        0.02x
cone 5×5         284.141     5.225        0.02x
disc 5×5         270.449     5.139        0.02x
cross 5×5        285.960     5.223        0.02x
uniform 7×7      267.170     6.868        0.03x
gaussian 7×7     284.619     6.902        0.02x
pyramid 7×7      268.585     6.876        0.03x
cone 7×7         269.966     6.926        0.03x
disc 7×7         267.884     6.893        0.03x
cross 7×7        261.847     6.823        0.03x
uniform 9×9      270.801     6.490        0.02x
gaussian 9×9     258.744     6.642        0.03x
pyramid 9×9      268.122     6.563        0.02x
cone 9×9         258.451     6.645        0.03x
disc 9×9         257.937     6.639        0.03x
cross 9×9        258.973     6.588        0.03x
uniform 11×11    258.561    15.697        0.06x
gaussian 11×11   258.481    15.527        0.06x
pyramid 11×11    256.785    15.489        0.06x
cone 11×11       254.444    15.457        0.06x
disc 11×11       252.852    15.636        0.06x
cross 11×11      253.578    15.727        0.06x
```

### Zero-sum convolution on `Image4Bit`

```
kernel             Metal     ImPro   ImPro/Metal
laplacian4 3×3   356.855     1.195        0.00x
laplacian8 3×3   348.707     1.162        0.00x
sobelX 3×3       287.681     1.204        0.00x
sobelY 3×3       281.811     1.183        0.00x
prewittX 3×3     299.031     1.178        0.00x
prewittY 3×3     276.919     1.182        0.00x
laplacian4 5×5   310.311     3.892        0.01x
laplacian8 5×5   279.682     3.942        0.01x
sobelX 5×5       290.145     3.890        0.01x
sobelY 5×5       282.996     3.932        0.01x
prewittX 5×5     270.955     3.945        0.01x
prewittY 5×5     286.148     3.944        0.01x
laplacian4 7×7   267.153     6.004        0.02x
laplacian8 7×7   284.296     5.993        0.02x
sobelX 7×7       267.614     5.968        0.02x
sobelY 7×7       271.115     5.987        0.02x
prewittX 7×7     268.620     6.002        0.02x
prewittY 7×7     261.540     6.029        0.02x
laplacian4 9×9   270.741     5.985        0.02x
laplacian8 9×9   258.637     5.995        0.02x
sobelX 9×9       268.752     5.957        0.02x
sobelY 9×9       259.380     5.950        0.02x
prewittX 9×9     258.661     5.980        0.02x
prewittY 9×9     259.146     5.999        0.02x
laplacian4 11×11 259.555    14.418        0.06x
laplacian8 11×11 258.502    14.324        0.06x
sobelX 11×11     256.777    14.340        0.06x
sobelY 11×11     256.293    14.224        0.06x
prewittX 11×11   253.076    14.318        0.06x
prewittY 11×11   253.346    14.374        0.06x
dogOneStep 5×5   250.514     3.951        0.02x
dogOneStep 7×7   250.375     0.025*       0.00x*
dogOneStep 9×9   251.800     0.024*       0.00x*
dogOneStep 11×11 251.480     0.022*       0.00x*
dogTwoStep 7×7   250.682     0.024*       0.00x*
dogTwoStep 9×9   250.411     0.025*       0.00x*
dogTwoStep 11×11 252.094     0.027*       0.00x*
```

### Binary erode on `ImageMono`, `passes = 1`

```
case             Metal     ImPro   ImPro/Metal
full 3×3         0.49      0.12        0.25x
disc 3×3         0.50      0.12        0.25x
cross 3×3        0.56      0.13        0.23x
full 5×5         0.33      0.18        0.55x
disc 5×5         1.22      0.19        0.15x
cross 5×5        1.05      0.18        0.17x
full 7×7         1.15      0.35        0.30x
disc 7×7         1.10      0.37        0.33x
cross 7×7        0.60      0.36        0.61x
full 9×9         0.51      0.50        0.97x
disc 9×9         0.52      0.49        0.95x
cross 9×9        0.56      0.48        0.86x
full 11×11       0.57      0.71        1.25x
disc 11×11       1.04      0.69        0.66x
cross 11×11      0.69      0.70        1.03x
```

### Binary dilate on `ImageMono`, `passes = 1`

Numbers track the erode table within ±10% — both backends use symmetric
implementations; omitted here for brevity. See the live console output of the
`dilateBinaryThroughput()` test for the full table.

### Headline observations

- **8-bit grayvalue convolution.** Metal wins everywhere by 2×–32×. Among the
  two CPU backends, hand-tuned vImage on one thread is 2–12× faster than the
  AI-written ImPro on one thread — i.e. **ImPro has roughly an order of
  magnitude of single-core CPU performance to recover**.
- **4-bit grayvalue convolution.** Metal loses catastrophically (250–360 ms vs
  1–16 ms for ImPro). The Metal 4-bit path expands 4→8 bit, convolves, then
  quantises 8→4 bit on every call, and the conversion overhead dominates. A
  packed-pixel Metal shader would close this gap.
- **Binary morphology.** ImPro's word-parallel bitwise inner loop wins at small
  kernels (0.15–0.61× of Metal time). The crossover is around 9×9; at 11×11
  Metal is slightly faster. Metal's morphology shader appears to carry a fixed
  per-launch overhead that small kernels can't amortise.
- **DoG kernels (≥ 7×7).** ImPro currently rejects them because the rounded Int8
  weights don't sum to exactly zero — visible as the 0.02–0.03 ms throw
  shortcut in the zero-sum tables. Tracked as an upstream ImPro C-library bug.
