# Operators — Implementation Plan

## 1. Goal

Introduce the concept of an **Operator** into `AlgoCVData` and `CVLibrary`. An
`Operator` is a serialisable, content-addressable description of a single call
into the AlgoCV frontend (`AlgoCV.*Backend` methods, exposed today through
`Image8Bit+Filtering`, `Image4Bit+Filtering`, `ImageMono+Morphology`,
`ImageRGB+Channels`, and the future histogram/spectrum/transform APIs).

An operator captures:

- a stable **identity** — its *signature*, the canonical encoding of which
  method it invokes plus the values of any fixed parameters (e.g. the bytes of
  a kernel, the resampling enum, a clamp gray value);
- a **human-readable name** (and optional details / kind hierarchy) for UI;
- an ordered, named set of **inputs** and **outputs** typed against
  `AlgoCVData` value types (today: `Image8Bit`, `Image4Bit`, `ImageMono`,
  `ImageRGB`; later: histograms, spectra, scalar variables);
- the (fixed) **parameters** the operator binds before being placed into a
  library — variable parameters become inputs instead.

`CVLibrary` becomes the registry of operators just as it is the registry of
kernels today, with the same distinctness invariant — no two operators may
share a signature.

## 2. Scope

| Package      | Changes                                                                                             |
| ------------ | --------------------------------------------------------------------------------------------------- |
| `AlgoCVData` | Add the `Operator` data model, signature hashing, `CVLibrary.operators`, standard-library presets   |
| `AlgoCV`     | (Follow-up, out of scope of this plan) An `OperatorRuntime` that dispatches an `Operator` to a backend call |

This plan covers **`AlgoCVData` only**. Execution wiring in `AlgoCV` is sketched
in §10 so the data model has the right shape, but its implementation lands in a
later commit.

## 3. Non-goals

- Do **not** model variable / unbound parameters as a separate kind. The
  operator stores *fixed* parameters; everything that varies per-call becomes
  an input or an output slot.
- Do **not** invent a new execution layer in `AlgoCVData`. The package stays
  pure data + validation.
- Do **not** preserve JSON wire compatibility with the current `CVLibrary`
  encoding. There are no consumers persisting `CVLibrary` JSON across this
  change, so `CVLibrary` may make `operators` a required key and otherwise
  freely reshape its `Codable` form.

## 4. Type design

All new types live in `AlgoCVData/Sources/` as `Sendable`, `Equatable`,
`Codable`. Types are one-per-file per `AGENTS.md`, except small nested enums.

### 4.1 `OperatorKind` and `OperatorSubKind`

```swift
public enum OperatorKind: String, CaseIterable, Codable, Sendable {
    case colorSpace
    case histogram
    case transformation
    case highpass
    case lowpass
    case morphology
    case combinator
}

public enum OperatorSubKind: String, CaseIterable, Codable, Sendable {
    // colorSpace
    case channelSplit
    case channelComposition
    case spaceTransformation
    // histogram
    case histogramTransformation
    case histogramFilter
    case histogramCombinator
    // transformation (no subkind — `nil`)
    // highpass
    case sharpening
    case edgeDetection
    // lowpass
    case linearBlur
    case nonlinearBlur
    // morphology (no subkind — `nil`)
    // combinator
    case arithmetic
    case bitwise
}
```

The hierarchy is enforced by a single validator
`OperatorKind.allowedSubKinds: Set<OperatorSubKind>` that lists the legal
subkinds for each kind (e.g. `.colorSpace → {channelSplit, channelComposition,
spaceTransformation}`; `.transformation → {}`; `.morphology → {}`). Construction
of an `Operator` whose `(kind, subKind)` violates this map throws
`OperatorValidationError.invalidSubKind`.

`File: AlgoCVData/Sources/OperatorKind.swift` (the two enums + the
`allowedSubKinds` table — small, tied together, so they share a file per the
style guide).

### 4.2 `DataKind` — the type tag for slots

```swift
public enum DataKind: String, Codable, Sendable, Equatable, CaseIterable {
    case imageRGB
    case image8Bit
    case image4Bit
    case imageMono
    // reserved for the next phase:
    case histogram
    case spectrum8Bit
    case spectrum4Bit
    case variable
}
```

`DataKind` is intentionally a closed enum (`CaseIterable`) so adding a new
input/output kind is a deliberate API change with compile-time fan-out. The
reserved cases let later phases add slots without renumbering existing entries.

`File: AlgoCVData/Sources/DataKind.swift`.

### 4.3 `OperatorSlot` — input / output descriptor

```swift
public struct OperatorSlot: Codable, Equatable, Sendable {
    public let name: String      // display-only label, e.g. "source", "red"
    public let kind: DataKind
}
```

Inputs and outputs are both `[OperatorSlot]` — ordered, with positional
semantics. `name` is descriptive metadata only (UI / debugging) and is **not**
part of the operator's signature: see §5. Duplicate slot names within a list
are not an error — labels like `["red", "green", "blue"]` are fine, but so is
`["channel", "channel", "channel"]`.

`File: AlgoCVData/Sources/OperatorSlot.swift`.

### 4.4 `OperatorParameter` — fixed-value parameters

```swift
public enum OperatorParameter: Codable, Equatable, Sendable {
    case kernelUnitSum(KernelUnitSum)
    case kernelZeroSum(KernelZeroSum)
    case kernelNonlinear(KernelNonlinear)
    case shape(Shape)
    case colorSpace(ColorSpace)
    case nonlinearTransformation(NonlinearTransformation)
    case gray(UInt8)
    case count(UInt32)       // pixel counts, passes, etc.
    case size(width: UInt16, height: UInt16)
    case flag(Bool)
    case label(String)       // for finite enum-by-name values from upstream APIs
}
```

Coding uses a discriminator key (`type`) plus a `value` payload so the JSON is
forward-compatible. Each case folds into the signature hash by a stable
discriminator byte + the canonical bytes of its payload (kernels reuse their
existing `id`-style hashing via `FNV1a`; numeric cases mix as little-endian).

Each fixed parameter is paired with a name at the operator level (see §4.5);
the case itself only carries the value.

`File: AlgoCVData/Sources/OperatorParameter.swift`.

#### Why an enum, not a protocol?

- Operators have to be `Codable` round-trip without losing type identity. A
  closed enum lets the encoder/decoder use one discriminator and reject
  unknown cases up-front.
- The set of legal parameter shapes is small and known — the operator
  catalogue is *curated*, the way `CVLibrary.standard` is.
- Hash-signature stability requires a fixed list of cases (adding a case
  changes nothing about existing signatures); a protocol with arbitrary
  conformers would not give that guarantee.

### 4.5 `Operator`

```swift
public struct Operator: Codable, Equatable, Sendable, Identifiable {
    public let name: String
    public let details: String?
    public let kind: OperatorKind
    public let subKind: OperatorSubKind?

    /// The frontend method this operator invokes — a stable token that the
    /// `OperatorRuntime` (in AlgoCV) dispatches on.
    public let call: OperatorCall

    public let parameters: [NamedParameter]   // ordered; fixed bindings
    public let inputs: [OperatorSlot]         // ordered
    public let outputs: [OperatorSlot]        // ordered

    /// Signature — FNV1a digest over `call`, the ordered parameter payloads,
    /// and the ordered slot type lists (with cardinalities). Names of the
    /// operator, its parameters, and its slots do not participate.
    public var id: UInt64 { signature }
    public let signature: UInt64

    public struct NamedParameter: Codable, Equatable, Sendable {
        public let name: String        // display-only; ignored by signature
        public let value: OperatorParameter
    }
}
```

`File: AlgoCVData/Sources/Operator.swift`.

### 4.6 `OperatorCall` — the dispatch token

```swift
public enum OperatorCall: String, Codable, Sendable, CaseIterable {
    // Existing today in AlgoCV
    case applyKernelUnitSumImage8Bit
    case applyKernelZeroSumImage8Bit
    case applyKernelUnitSumImage4Bit
    case applyKernelZeroSumImage4Bit
    case filterImage8BitNonlinear
    case filterImage4BitNonlinear
    case erodeImageMono
    case dilateImageMono
    case openImageMono
    case closeImageMono

    // One case each: the bound ColorSpace parameter is what distinguishes
    // a Split-into-HSV operator from a Split-into-CMYK operator. The output
    // slot list of any individual operator instance is fixed (no variadics);
    // its cardinality just happens to equal the bound space.channelCount.
    case splitImageRGB
    case composeImageRGB

    // Reserved (planned)
    case cropImage8Bit
    case resampleImage8Bit
    case reflectImage8Bit
    case invertImage8Bit
    case histogramOfImage8Bit
    case histogramEqualise
    case histogramThreshold
    case addImage8Bit
    case subtractImage8Bit
    case bitwiseAndImageMono
    case bitwiseOrImageMono
    case bitwiseXorImageMono
}
```

Cases are versioned by *behaviour*, not by current Swift method names — once an
operator with `call = .applyKernelZeroSumImage8Bit` has a signature, that
signature is frozen forever even if the underlying Swift function is renamed.

`File: AlgoCVData/Sources/OperatorCall.swift`.

### 4.7 `OperatorValidationError`

```swift
public enum OperatorValidationError: Error, Equatable, LocalizedError, Sendable {
    case invalidSubKind(kind: OperatorKind, subKind: OperatorSubKind)
    case mismatchedCallSchema(call: OperatorCall, reason: String)
}
```

`mismatchedCallSchema` covers the per-call schema described in §6 (wrong
parameter count, wrong parameter type at position `i`, wrong slot count,
wrong slot type at position `i`).

Note: there is intentionally no `duplicateSlotName` / `duplicateParameterName`
error. Names are display-only and the signature is name-blind (§5), so
overlapping labels are permitted.

Lives alongside the existing `MatrixValidationError` / `CVLibraryError` —
`File: AlgoCVData/Sources/OperatorValidationError.swift`.

## 5. Signature hashing

Signature is an `FNV1a` digest computed once at init and stored, so callers
get a cheap `O(1)` `id`. Hash protocol (stable, never reordered):

```text
FNV1a()
  .mix("operator")                    // domain separator
  .mix(call.rawValue)                 // dispatch token
  .mix(UInt32(parameters.count))
  for p in parameters (in order):
      .mix(discriminator(p.value))    // single byte per case
      .mix(canonicalBytes(p.value))   // case-specific
  .mix(UInt32(inputs.count))
  for slot in inputs (in order):
      .mix(slot.kind.rawValue)
  .mix(UInt32(outputs.count))
  for slot in outputs (in order):
      .mix(slot.kind.rawValue)
.digest
```

`kind`, `subKind`, the operator-level `name`/`details`, **and the names of
parameters and slots** deliberately **do not** participate. Identity is the
call + the ordered, typed parameter values + the ordered slot type lists +
their cardinalities — nothing else. Two operators that make the exact same
call with the exact same fixed bindings and the same number/type of inputs
and outputs are the same operator regardless of how they are catalogued or
how their slots/parameters are labelled.

Implemented as `internal` helper `Operator.computeSignature(...)` and exercised
by tests (§9.4).

## 6. Per-`OperatorCall` schema validation

Each `OperatorCall` has a fixed schema describing its required parameters,
inputs and outputs. Stored as a static table:

```swift
extension OperatorCall {
    struct Schema {
        let parameters: [ParameterKind]   // positional, by type only
        let inputs:     [DataKind]        // positional, by type only
        let outputs:    [DataKind]        // positional, by type only
    }
    static let schemas: [OperatorCall: Schema] = [...]
}
```

`ParameterKind` is a sibling closed enum mirroring `OperatorParameter` cases
(without the payload). Validation is structural and **name-blind**:

- parameter count and the `ParameterKind` of each `OperatorParameter` payload
  must match the schema, in order;
- input / output slot lists must match the schema's `DataKind` sequence
  exactly (same count, same kinds, same order).

Slot and parameter **names are display-only metadata**; the schema does not
constrain them and the signature ignores them.

Some calls have parameter-dependent slot lists. The schema captures this with
a parameter-driven rule rather than a fixed list. For `.splitImageRGB`:

```text
parameters: [.colorSpace]                           // fixed
inputs:     [.imageRGB]                             // fixed
outputs:    count == parameters[0].colorSpace.channelCount,
            every element == .image8Bit             // parameter-driven
```

So a `.splitImageRGB` operator bound to `space = .hsv` has exactly 3
`.image8Bit` outputs in its slot list; one bound to `space = .cmyk` has
exactly 4. **The operator's slot list is still fixed at construction time —
there are no variadic outputs at runtime.** Different bound color-space values
produce *different operator instances* with different signatures (the
`ColorSpace` value flows into the parameter portion of the signature; the
resulting slot count + type list flows into the slot portion). The runtime
never has to expand anything.

## 7. CVLibrary integration

`CVLibrary` gains a fourth collection:

```swift
public struct CVLibrary: Codable, Equatable, Sendable {
    public let unitSumKernels: [KernelUnitSum]
    public let zeroSumKernels: [KernelZeroSum]
    public let nonlinearKernels: [KernelNonlinear]
    public let operators: [Operator]   // NEW

    public init(
        unitSumKernels: [KernelUnitSum] = [],
        zeroSumKernels: [KernelZeroSum] = [],
        nonlinearKernels: [KernelNonlinear] = [],
        operators: [Operator] = []          // NEW, default-empty for compat
    ) throws { ... }
}
```

### Uniqueness

The existing kernel-id distinctness invariant stays. A *separate* invariant is
added for operators: signatures must be distinct **within the operator list**.
`CVLibraryError` gains:

```swift
case duplicateOperator(signature: UInt64)
```

Kernel ids and operator signatures live in different namespaces — they share
the same FNV1a output space but with different domain separators (kernels mix
their `KernelKind.rawValue`; operators mix `"operator"` first). No cross-set
distinctness is enforced, and the test suite asserts this is intentional.

### Coding

`CVLibrary.init(from:)` decodes `operators` as a required key. The synthesised
`Codable` conformance is sufficient — there is no migration path from the old
schema to maintain.

### `CVLibrary.standard` extension

`standard` gains a `standardOperators` field that builds the catalogue out of
the existing standard kernels. Initial set (one operator per existing
`AlgoCV` frontend call × notable fixed bindings):

| Call                            | Fixed parameters                       | Inputs               | Outputs                                |
| ------------------------------- | -------------------------------------- | -------------------- | -------------------------------------- |
| `applyKernelUnitSumImage8Bit`   | `kernel: <each standard>`              | `[image8Bit]`        | `[image8Bit]`                          |
| `applyKernelZeroSumImage8Bit`   | `kernel: <each standard>`              | `[image8Bit]`        | `[image8Bit]`                          |
| `filterImage8BitNonlinear`      | `kernel: <each standard>`              | `[image8Bit]`        | `[image8Bit]`                          |
| `erodeImageMono`                | `shape: box3 \| cross3`, `passes: 1`   | `[imageMono]`        | `[imageMono]`                          |
| `dilateImageMono`               | (same)                                  | `[imageMono]`       | `[imageMono]`                          |
| `splitImageRGB`                 | `space: <each ColorSpace>`              | `[imageRGB]`        | `[image8Bit] × space.channelCount`     |
| `composeImageRGB`               | `space: <each ColorSpace>`              | `[image8Bit] × space.channelCount` | `[imageRGB]`            |

Each `ColorSpace` value therefore produces a *distinct* operator with a
distinct signature — `Split into HSV` and `Split into CMYK` are different
operations because their bound `space` differs (and, as a side effect, their
output slot lists do too). Names are derived from the underlying filter /
kernel name where one exists (`"Gaussian blur 5×5"`, `"Sobel X"`,
`"Erode by 3×3 box"`, `"Split into HSV"`).

## 8. File layout

```
AlgoCVData/Sources/
  Operator.swift                  (Operator struct + signature computation)
  OperatorCall.swift              (OperatorCall + schemas table)
  OperatorKind.swift              (OperatorKind + OperatorSubKind + allowedSubKinds)
  OperatorParameter.swift         (OperatorParameter enum + Codable)
  OperatorSlot.swift              (OperatorSlot struct)
  OperatorValidationError.swift   (errors)
  DataKind.swift                  (slot type tag)
  CVLibrary+Operators.swift       (standardOperators + helpers; keeps
                                   CVLibrary.swift focused on storage)
```

`CVLibrary.swift` itself is edited to add the `operators` field, the new
distinctness rule, and the updated `Codable` paths.

## 9. Tests (in `AlgoCVData/Tests/`)

All new tests use the `Testing` framework (per `AGENTS.md` and the existing
`KernelIDCollisionTests` style).

### 9.1 `OperatorValidationTests`

- valid `(kind, subKind)` pairs are accepted;
- every other pair throws `.invalidSubKind`;
- duplicate / overlapping slot or parameter names are accepted (signature is
  name-blind; assert no error and identical signatures regardless of names);
- schema mismatches (wrong parameter count, wrong parameter type at position,
  wrong slot count, wrong slot type at position) throw `.mismatchedCallSchema`.

### 9.2 `OperatorCodingTests`

- round-trips each `OperatorParameter` case through `JSONEncoder/Decoder`;
- round-trips a full `Operator` graph (parameters + slots) and asserts the
  decoded value's `signature` matches the original.

### 9.3 `OperatorSignatureTests`

- signatures are deterministic across runs and across processes (assert
  numeric value, not just equality);
- two `Operator`s differing only in `name`, `details`, `kind`, `subKind`,
  parameter names, or slot names share a signature;
- two `Operator`s differing in *any* of: `call`, parameter ordering,
  parameter value, parameter count, slot ordering, slot kind, slot count
  (input or output) produce different signatures.

### 9.4 `OperatorIDCollisionTests`

Mirror of `KernelIDCollisionTests`. Enumerates the catalogue produced by
`CVLibrary.standardOperators` and asserts no signature collisions. Records
a stable count (analogous to `#expect(fixtures.count == 979)`) so accidental
catalogue churn is caught in code review.

### 9.5 `CVLibraryOperatorTests`

- `CVLibrary(operators:)` rejects duplicate signatures with `.duplicateOperator`;
- the existing `CVLibraryError.duplicateKernel` path is unaffected;
- `CVLibrary` round-trips through `JSONEncoder/Decoder` with operators present;
- `CVLibrary.standard.operators` is non-empty and stable.

## 10. AlgoCV runtime (sketch — implemented in a follow-up commit)

Out of scope for this commit but informs the API surface above:

```swift
public struct OperatorRuntime {
    let backend: AlgoCVBackend

    public func apply(
        _ op: Operator,
        inputs: [Any]                  // positional, matches op.inputs
    ) async throws -> [Any]            // positional, matches op.outputs
}
```

The runtime switches on `op.call`, pulls the parameters out of `op.parameters`
by position, the input planes out of `inputs` by position, and calls the
matching backend method (`backend.apply(zeroSumKernel, to: image8Bit)` etc.).
Because each operator instance's slot list is fixed at construction (§6),
the returned array's count always matches `op.outputs.count` — a
`splitImageRGB` operator bound to HSV returns exactly 3 planes; one bound
to CMYK returns exactly 4. A separate doc will spec the runtime; this plan
only commits to a data shape that supports it without rework.

## 11. Migration / rollout

1. Land the data types and CVLibrary changes (`AlgoCVData` only, all tests).
2. Add `CVLibrary.standardOperators` and tighten the collision tests.
3. (Follow-up commit) implement `OperatorRuntime` in `AlgoCV`, wire it to
   `AlgoCVBackend`, and add round-trip tests that prove
   `OperatorRuntime.run(splitOperator, inputs: …)` matches the existing
   `ImageRGB.split(into:)` output bit-for-bit.

No existing API in `AlgoCV` or `AlgoCVData` is removed or renamed. The
`Filter*` types in `Filters.swift` are left in place; once `Operator` is in
common use the next pass can either retire them or re-express them as
operator-flavoured wrappers, but that decision is deferred to a separate
proposal.

## 12. Open questions

1. **Future variable parameters** (e.g. a kernel computed at runtime from an
   input histogram). Out of scope; would be modelled as an additional input
   slot of kind `.kernelUnitSum` once kernels gain a `DataKind` representation.
2. **Display / localisation of names** — out of scope; `name` and `details`
   are plain strings, callers can wrap them in their own localisation layer.
