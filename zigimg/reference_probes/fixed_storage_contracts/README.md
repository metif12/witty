# Exact fixed-buffer resize failures and retained borrowed views

`verify_fixed_storage_contracts_reference.py` imports unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and compares Source Debug with ordinary
V, then Source ReleaseSafe with production V:

```sh
python3 zigimg/verify_fixed_storage_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The native target defaults to
64-bit little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds
commands; `TMPDIR` and `VTMP` select compiler temporaries. Artifacts retain the
unchanged full Source tree, fixtures, binaries, inputs, outputs, panic snapshots,
generated compiler consumers, commands and provenance.

All three V fixed-buffer forms now retain Source's exact resize diagnostic:
`index out of bounds: index N, len L`. Their guards execute before replacing data.
The generic implementation keeps its sizeof-based capacity calculation. An initial
attempt to use generic storage.len reported three after shrinking a seven-element
buffer, and failed the existing ordinary/production unit tests. That implementation
was corrected before the final proofs; the failed run and implementation remain in
artifacts. The empty-array adapter still requires empty storage; nonempty storage
has no corresponding Source zero-capacity array value. Separate V-only guard
checks pass in both modes and are excluded from the matching observations.

Both modes match **11,508 returning records** and **1,320 exact panic/state pairs**.
The fixtures exercise u8, u16 and the public Rgba32 type across generic capacities
0/1/7/8/256/513 and the actual 8/256-element specializations. Initial data descriptors
include the default empty view, borrowed inline views, and full/offset external
views. Old lengths span zero, one, maximum and near-maximum controls. Resize sizes
span zero, one, half capacity, capacity, capacity plus one and native usize maximum.

Seven operations cover resizing the original/copy, writing through relocated copy
views, retaining and mutating old borrowed views, copying inline arrays, replacing
copied descriptors with external/short views, and mutating inline storage before
a failing resize of the copy. Copies preserve independent inline values and data
headers; their existing data pointers continue borrowing the original target until
resize rebinds them. Descriptor lengths may exceed inline capacity when they borrow
external storage, as permitted by Source's public data field.

Snapshots compare both live data descriptors, the retained old view, complete
initialized inline arrays and all four external elements. Nonempty views use
canonical origins (original/copy/external) and element offsets, with no raw address
comparison. Empty pointer identities are omitted. Every panic pair requires a
failing exit, the exact diagnostic, no stdout and a nonempty matching snapshot.
The failure corpus uses both invalid sizes, four operations and empty/maximal prior
views; return cases use two initialized byte patterns.

Return SHA-256: `ca784ad0d6cf34998a7b78d16c63893daa7b6511fe6c8fb526973e2af64deb8d`.
Panic/state SHA-256: `8cf452e2aa375778bb4f19266e1fcb02ff2e65ce1c554f0700a518322d1c5fb4`.

Three compiler acceptance pairs cover default/initialized records and mutation.
Three rejection pairs cover constant resize, constant inline writes and mismatched
array element types. A separate constant-record borrowed-pointee control measures
Source acceptance and V rejection. Default construction is checked without reading
Source's undefined storage; every observed storage byte is explicitly initialized.

The unchanged historical fixture retains **2,373 returning records**, SHA-256
`ba652143ec8ea584ce4522ed61dc6605986e90185c524ce8b13281b40b642c0b`, in both modes.
TIFF metadata also retains **86 records and 15 trap pairs** in both modes, SHA-256
`c22c2516d50b6861d84f15605a3904f2a4fc935e45c8b3583ca0ead0c76f1346`.
Its three capacity checks now require the exact Source diagnostics. The TIFF runner
uses private compiler caches after an initial missing shared-cache archive failure.

V resize entry points use concrete buffer types because nested generic forwarding
failed code generation. The V observer reads live built-in array headers and fixed
initialized extents; its initial generic record observer produced invalid reads and
was replaced. These development failures are retained. Source uses the unchanged
public type factory, fully initialized caller storage and specialized panic observers.
No Source visibility or implementation is changed.

All 61 image and 58 Vaxis test files pass, with production fixed-storage/TIFF/GIF/
image-API tests, historical image-API/GIF/compression assertions in both modes,
native/Linux application checks, three Windows DLLs, both Windows fixed-storage
test executables and two Linux shared libraries. Cross builds establish build
coverage only.

Undefined/inactive/freed storage, record padding, empty identities, generic types
beyond the represented element/capacity controls, wider V array extents, record
relocation/lifetime, allocation/GC and portable ABI remain boundaries. V array
carriers and its zero-capacity specialization remain adapters; sizeof-based
capacity is not an ABI or layout-equivalence claim.

Complete Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Before/after dependency/fixture/input/consumer/runner/implementation hashes and
compiler-version pins protect the proof.
