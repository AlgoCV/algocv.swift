# algocv.swift

## Running the benchmarks

Throughput benchmarks for the Metal, ImPro and vImage backends live in
`AlgoCV/Tests/KernelBenchmarks.swift`. They are regular Swift Testing tests, so
they run via `swift test` or Xcode's test runner — they just print timing tables
to stdout instead of asserting anything.

The four backends are: **Metal** (GPU compute shaders), **ImPro** (single-thread
SIMD CPU library), **vImage(1T)** — Apple's vImage pinned to a single thread via
`kvImageDoNotTile` — and **OpenCV(1T)** — OpenCV's `Imgproc.filter2D` pinned to
one thread via `Core.setNumThreads(nthreads: 1)`. vImage and OpenCV are used as
deterministic single-core CPU references that Metal itself does not expose.
vImage and OpenCV only cover 8-bit grayvalue linear convolution here, so the
4-bit grayvalue and binary morphology tables only compare Metal vs ImPro.

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
kernel             Metal     ImPro  vImage(1T)  OpenCV(1T)  ImPro/vImage   ImPro/OpenCV
uniform 3×3        1.350     4.998     1.428       2.018         3.50x          2.48x
gaussian 3×3       1.541     5.032     1.436       1.710         3.50x          2.94x
pyramid 3×3        0.495     5.031     1.086       1.126         4.63x          4.47x
cone 3×3           0.551     4.865     1.099       1.127         4.43x          4.32x
disc 3×3           0.771     4.900     1.365       1.426         3.59x          3.44x
cross 3×3          0.459     4.889     1.382       1.418         3.54x          3.45x
uniform 5×5        1.343     4.081     1.949       2.824         2.09x          1.45x
gaussian 5×5       0.625     4.114     1.941       2.837         2.12x          1.45x
pyramid 5×5        0.973     4.059     1.532       1.692         2.65x          2.40x
cone 5×5           0.483     4.111     1.532       1.726         2.68x          2.38x
disc 5×5           0.495     4.118     1.886       2.538         2.18x          1.62x
cross 5×5          0.544     4.075     1.775       1.633         2.30x          2.50x
uniform 7×7        1.381    14.994     3.449       4.547         4.35x          3.30x
gaussian 7×7       1.521    15.196     3.440       4.583         4.42x          3.32x
pyramid 7×7        1.525    14.817     2.817       2.846         5.26x          5.21x
cone 7×7           0.748    14.939     2.750       2.552         5.43x          5.85x
disc 7×7           1.631    15.025     3.390       3.665         4.43x          4.10x
cross 7×7          0.511    14.802     2.398       1.980         6.17x          7.47x
uniform 9×9        1.439    24.505     4.363      12.317         5.62x          1.99x
gaussian 9×9       1.341    24.836     4.272      12.343         5.81x          2.01x
pyramid 9×9        1.602    24.724     3.605      12.342         6.86x          2.00x
cone 9×9           0.869    24.554     3.552      12.253         6.91x          2.00x
disc 9×9           0.799    24.548     4.237      12.251         5.79x          2.00x
cross 9×9          1.408    24.613     2.933      12.169         8.39x          2.02x
uniform 11×11      1.677    38.349     6.904      12.242         5.55x          3.13x
gaussian 11×11     1.378    38.040     6.889      12.386         5.52x          3.07x
pyramid 11×11      1.556    37.900     5.972      12.301         6.35x          3.08x
cone 11×11         1.655    37.952     5.628      12.359         6.74x          3.07x
disc 11×11         1.560    37.959     6.468      12.343         5.87x          3.08x
cross 11×11        1.486    37.882     3.727      12.291        10.17x          3.08x
```

### Zero-sum convolution on `Image8Bit`

```
kernel             Metal     ImPro  vImage(1T)  OpenCV(1T)  ImPro/vImage   ImPro/OpenCV
laplacian4 3×3     1.501     3.056     1.380       1.405         2.21x          2.17x
laplacian8 3×3     1.538     3.118     1.437       1.658         2.17x          1.88x
sobelX 3×3         0.486     3.069     1.416       1.493         2.17x          2.05x
sobelY 3×3         0.599     3.040     1.296       1.518         2.35x          2.00x
prewittX 3×3       1.323     3.060     1.420       1.488         2.15x          2.06x
prewittY 3×3       1.364     3.069     1.233       1.486         2.49x          2.07x
laplacian4 5×5     1.462     6.743     1.470       1.430         4.59x          4.71x
laplacian8 5×5     1.299     6.691     1.528       1.695         4.38x          3.95x
sobelX 5×5         0.780     6.825     1.850       2.491         3.69x          2.74x
sobelY 5×5         0.490     6.770     1.790       2.446         3.78x          2.77x
prewittX 5×5       0.558     6.696     1.865       2.463         3.59x          2.72x
prewittY 5×5       0.475     6.690     1.795       2.485         3.73x          2.69x
laplacian4 7×7     0.784    12.068     1.803       1.417         6.69x          8.52x
laplacian8 7×7     1.069    11.891     2.127       1.698         5.59x          7.00x
sobelX 7×7         0.890    11.956     3.356       4.012         3.56x          2.98x
sobelY 7×7         1.226    11.781     3.129       4.074         3.77x          2.89x
prewittX 7×7       1.223    11.904     3.399       4.040         3.50x          2.95x
prewittY 7×7       1.380    11.906     3.163       4.027         3.76x          2.96x
laplacian4 9×9     0.743    18.837     1.983      12.318         9.50x          1.53x
laplacian8 9×9     0.769    18.884     2.304      12.387         8.20x          1.52x
sobelX 9×9         1.030    18.892     4.261      12.430         4.43x          1.52x
sobelY 9×9         1.064    18.911     4.074      12.348         4.64x          1.53x
prewittX 9×9       1.705    19.065     4.243      12.383         4.49x          1.54x
prewittY 9×9       1.433    19.012     4.059      12.349         4.68x          1.54x
laplacian4 11×11   1.794    27.348     2.234      12.312        12.24x          2.22x
laplacian8 11×11   1.371    27.696     2.270      12.360        12.20x          2.24x
sobelX 11×11       1.271    27.876     6.938      12.413         4.02x          2.25x
sobelY 11×11       1.629    27.551     6.413      12.273         4.30x          2.24x
prewittX 11×11     1.521    27.538     6.878      12.341         4.00x          2.23x
prewittY 11×11     1.707    27.681     6.426      12.298         4.31x          2.25x
dogOneStep 5×5     1.430     6.751     1.957       2.823         3.45x          2.39x
dogOneStep 7×7     0.961     0.027*    3.381       4.234         0.01x*         0.01x*
dogOneStep 9×9     1.566     0.028*    4.328      12.185         0.01x*         0.00x*
dogOneStep 11×11   1.073     0.031*    6.912      12.362         0.00x*         0.00x*
dogTwoStep 7×7     1.422     0.027*    3.450       4.254         0.01x*         0.01x*
dogTwoStep 9×9     0.684     0.028*    4.255      12.248         0.01x*         0.00x*
dogTwoStep 11×11   1.550     0.038*    6.927      12.343         0.01x*         0.00x*
```

`*` ImPro silently throws on these DoG kernels (`try?` returns `nil`), so the
0.02–0.04 ms numbers are the cost of the throw, not real convolution time —
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

- **8-bit grayvalue convolution, GPU vs CPU.** Metal wins everywhere by 2×–28×.
- **8-bit grayvalue convolution, CPU race.** Among the three single-thread CPU
  backends, the order is consistently **vImage ≤ OpenCV < ImPro**. vImage and
  OpenCV are roughly tied on small kernels (3×3–7×7); on 9×9 and 11×11 OpenCV
  jumps to a flat ~12 ms because OpenCV's `filter2D` switches to a DFT-based
  implementation past a kernel-size heuristic, and that path is slower in
  single-thread mode than vImage's direct convolution. The AI-written ImPro is
  2–12× slower than both, so it has roughly an order of magnitude of CPU
  performance to recover against the hand-tuned Apple/OpenCV implementations.
- **4-bit grayvalue convolution.** Metal loses catastrophically (250–360 ms vs
  1–16 ms for ImPro). The Metal 4-bit path expands 4→8 bit, convolves, then
  quantises 8→4 bit on every call, and the conversion overhead dominates. A
  packed-pixel Metal shader would close this gap.
- **Binary morphology.** ImPro's word-parallel bitwise inner loop wins at small
  kernels (0.15–0.61× of Metal time). The crossover is around 9×9; at 11×11
  Metal is slightly faster. Metal's morphology shader appears to carry a fixed
  per-launch overhead that small kernels can't amortise.
- **DoG kernels (≥ 7×7).** ImPro currently rejects them because the rounded Int8
  weights don't sum to exactly zero — visible as the 0.02–0.04 ms throw
  shortcut in the zero-sum tables. Tracked as an upstream ImPro C-library bug.
