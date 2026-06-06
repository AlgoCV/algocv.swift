# AlgoCV Agent Guide

These are algorithmic computer vision high-level abstraction libraries,
providing both persistence and operation implementation. It is written in Swift 6.0.
It uses multiple backends, which for now include
- ImPro package - CPU-only SIMD-optimized backend
- Metal

The libraries must be cross-platform, compilable on Linux, macOS and Windows.

## Code style

- Keep types in separate files, unless these are small enums of nested types
