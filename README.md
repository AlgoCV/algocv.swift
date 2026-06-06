# algocv.swift

## Running the benchmarks

Throughput benchmarks for the Metal vs ImPro backends live in
`AlgoCV/Tests/KernelBenchmarks.swift`. They are regular Swift Testing tests, so
they run via `swift test` or Xcode's test runner — they just print timing tables
to stdout instead of asserting anything.

From the command line, in the `AlgoCV` package directory:

```sh
# Run only the benchmark suite
swift test --filter "Backend throughput benchmarks"

# Run a single benchmark
swift test --filter "KernelBenchmarks/unitSumThroughput"
swift test --filter "KernelBenchmarks/zeroSumThroughput"
```

From Xcode: select the `AlgoCV` scheme, open the Test navigator, and run the
two tests under **Backend throughput benchmarks**. The timing tables appear in
the test report's console output, e.g.:

```
=== Unit-sum convolution on 1024×1024, 10 iterations (avg ms) ===
  kernel                       Metal       ImPro  ImPro/Metal
  gaussian 3×3                 0.514       5.073        9.87x
  gaussian 5×5                 0.894       4.045        4.52x
  gaussian 7×7                 1.602      14.742        9.20x
  gaussian 11×11               1.359      37.757       27.79x
```

Image size, warmup count, iteration count, and the kernel sides under test are
configured at the top of `KernelBenchmarks.swift` (`imageSide`, `warmup`,
`iterations`, `kernelSides`). Increase `iterations` if you need tighter
measurements; reduce `imageSide` if a run on a slow machine takes too long.

The suite is automatically disabled when no Metal device is available
(non-Apple hosts), so there is no third "Metal CPU-only" comparison — Metal
does not expose a way to redirect compute kernels off the GPU.
