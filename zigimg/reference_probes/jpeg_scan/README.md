# JPEG public Scan contracts

`verify_jpeg_scan_reference.py` compares the public Scan API with unchanged
zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary
V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_jpeg_scan_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. `--target` defaults to
`aarch64-macos.14.0`; `--timeout` bounds commands. `VTMP` can relocate V compiler
temporaries. Cross compilation alone does not establish runtime equivalence.

`JpegScanComponentSpec` and `JpegScan` are public mutable records and require all
three/nine represented fields. Component slots are a fixed four-element optional
array; prediction values remain a fixed three-element i32 array. Component count
and spectral fields use u8. Source u4 selectors/approximation fields use V byte
carriers, with wider constructor values measured separately below.

`JpegScanComponentSpec.read`, `JpegScan.init` and `JpegScan.perform_scan` are public.
Both Scan entry points borrow a Frame without requiring a mutable Frame binding;
the scan operation changes the Frame's coefficient slice. `JPEG.read` calls the
public scan entry point. Initialization preserves Source's OR validity rule:
a matching frame component, an existing DC table or an existing AC table suffices.
DC table bounds are still checked even after a component matches. AC selectors
retain Source's two-bit mask. Spectral validation precedes the approximation read
and late segment-length assertion. Both modes preserve all explicit checks.

Scan copies retain independent scalar fields, component slots, predictions and
reader bit state, while borrowing the same Frame and stream. In V 0.5.2, optional
struct unwrapping produces a local value; replacing the fixed slot expresses
Source's in-place payload field update. A named intermediate also avoids the
pinned compiler's backend error for directly unwrapping fixed-array entries with
`or`:

```v
mut scan := zigimg.JpegScan.init(&frame, mut stream)!
entry := scan.components[0]
mut component := entry or { panic('missing component') }
component.component_id = 2
scan.components[0] = component
```

| Returning observations | Count |
|---|---:|
| Component reads: every ID/selector byte pair and truncation | 65,541 |
| Scan initialization, table/component OR rules, spectral/approximation validation and truncation | 6,795 |
| Public field updates, fixed-array/reader copies and live Frame borrowing | 1,024 |
| Direct baseline/progressive/other-marker scans, initialized padding, entropy failures and restart controls | 3,040 |
| **Total** | **76,400** |

Returning SHA-256:
`22ff0ced5a3fb14f5f80f8ff99e012a7f2bb78d38b34e92baf202990342408c8`.

Twenty-seven strict failure pairs match exact panic categories and retained stream
position/coefficient state: twelve DC selector bounds, five late lengths, three
block bounds before entropy fill (including an unhandled Frame marker), a fourth
component lane bound before fill, two restart-product overflows, two zero restart
divisors, and missing DC/AC tables. MCU identity, grouped block coordinates,
restart products and loop increments use checked native-width arithmetic. Block
and component addresses are checked before the swallowed `fill_bits(24)` attempt,
preserving Source's failure order and consumed bytes. Production retains these
checks. Failure-state SHA-256:
`26a190953880f66299ebb8834f75b8ad3603c881efa5285386a06543b17fd46e`.

Two complete record constructors compile in both languages. Twelve omitted fields
and two mutations through immutable bindings receive ordinary compiler rejections;
actual error lines must match, and crashes/backend/linker failures cannot satisfy
the controls. Four separate construction pairs measure V bytes accepting 16 where
Source u4 fields reject it. One pair measures Source rejecting scalar mutation
through Scan's `*const Frame` while V's pointer carrier accepts it. V does not
encode that pointee const qualifier. Two separate process pairs preserve inherited
zero-horizontal/vertical-step loops when component sampling is zero and restart
processing is disabled; they must time out without output.

Source is copied unchanged, and private frame-component types are inferred from
existing public fields. The runner pins the complete Source src tree, compiler
versions and selected memory/debug/reader/writer/file/map library files. Before
and after checks protect Source, compiler-library files, fixtures, runner and all
top-level V image implementation files. Commands, generated constructor consumers,
raw results, diagnostics, observer state, corpus, provenance and summaries remain
in the proof directory.

All direct scan storage is initialized in every component lane before observation,
including progressive scans and padding. Unknown components accepted by the OR
rule are compared in init only: performScan leaves component indexes/sampling
undefined for those inputs. Direct scan tables use explicitly constructed public
records with defined map and acceleration fields; these controls do not assert
canonical table construction. Existing canonical-table decoder and historical
matrices are rerun separately. Allocator/OOM/GC/lifetime, undefined Source storage,
ABI, const/narrow integer/key typing, map layout/order/capacity, arbitrary SIMD
selection and cross-target runtime remain limits. The separate quantization boxed
copy difference remains documented in [the record proof](../jpeg_records/README.md).
Source quantization.Header.read still has its inherited Zig 0.15.2 compiler failure;
JPEG's pinned no-op writer is unchanged.

The existing Frame, record, decoder and historical JPEG comparisons retain their
hashes/exclusions in both modes. All 57 image and 58 Vaxis test files pass, as do
focused ordinary/production Scan tests and native/Linux application checks.
Three Windows dependency DLLs, the new Windows test executable in both modes and
two Linux shared libraries build with `-gc none`; cross-target runtime is unverified.
