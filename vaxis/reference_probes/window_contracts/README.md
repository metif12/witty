# Window record contracts

`verify_window_contracts_reference.py` compares the public Window-related record
constructors, defaults, mutations and borrowed payloads with unchanged pinned
Vaxis. It verifies the complete source tree before copying it and builds the
locked Unicode dependency through `widgets_classic/source_build.py`. No Source
wrappers, visibility changes or dependency-body edits are used.

Source tree SHA256:
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
Locked uucode SHA256:
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.

```sh
python3 vaxis/verify_window_contracts_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-window-contracts-debug

python3 vaxis/verify_window_contracts_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --workdir /tmp/witty-window-contracts-prod
```

Build directories must be new. `--v-prod` selects Zig ReleaseSafe and V production;
ordinary mode uses Zig Debug. The default target is `aarch64-macos.14.0`. Commands,
returning output, layout observations and every compiler diagnostic are retained.
Compiler crashes, panics and generated-C failures cannot count as ordinary
constructor rejection. Accepted adaptation consumers are compiled and run, rather
than inferred from a successful type check.

The returning consumer covers 311 records. Both modes match SHA256 (including
the final newline)
`016aff5f7db4b2c5d9ba08210bc93d0e150a7c99244051cffdb800c93d54cc8d`.

The cases cover:

- Required Window fields at signed i17 endpoints, and u16 size endpoints;
  PrintResult endpoints and both overflow values.
- Thirteen selected default observations across ChildOptions, BorderOptions,
  Locations and PrintOptions; all sixteen location-bit combinations; every border
  location arm and all glyph arms; optional absent versus explicit zero sizes;
  every wrap/commit combination and u16 print offsets.
- Custom glyph array headers copied by value while the individual glyph byte
  strings remain borrowed. Mutating a source array header leaves the captured
  header unchanged; mutating its byte storage remains visible.
- Seven public mutable records with independent value copies: Window,
  PrintResult, ChildOptions, Locations, custom glyph payload, BorderOptions and
  PrintOptions. Window keeps the borrowed Screen pointer while its size fields
  remain a snapshot. The copied records retain their old scalar/array-header state.
- Screen-backed creation through public `vaxis.init`/`Vaxis.new`, Screen
  initialization and `Vaxis.window`, with zero offsets, pixel sizes, empty and
  populated buffers, pointer identity and initial cursor/width-method state.

Separate constructor checks cover seven complete pairs, eleven required-field
omission pairs and two incorrect fixed-glyph array lengths. The Source custom
glyph arm requires its six-element payload; its V wrapper requires `glyphs`.
Window requires all seven fields, including its Screen pointer; PrintResult
requires all three fields. ChildOptions, BorderOptions, Locations and PrintOptions
allow empty literals because every field has a Source default.

The returning records, constructor checks and measured boundaries pass in both
comparison modes. Exact ordinary compiler categories are required for the Source
rejections and invalid fixed-array lengths.

Measured representation and compiler boundaries are kept separate:

- Twelve Source i17 range rejections versus accepted V int literals: both adjacent
  out-of-range values for four Window offsets and two ChildOptions offsets. This
  proof observes record construction only; public method arithmetic and range
  guards are verified by the behavioral Window comparisons.
- Three alias-required limitations: Source aliases reject missing Window width,
  PrintResult overflow and custom glyph payload. Pinned V aliases accept the
  corresponding omitted inherited required field and initialize it to zero,
  false or an empty six-string array. Ordinary unaliased omissions reject.
- An explicit zero Screen pointer rejects in Source's nonnullable pointer carrier;
  V accepts `unsafe { nil }`. The V consumer observes the pointer without
  dereferencing it. Requiring the field restores its presence contract, not Source
  pointer nullability or lifetime checking.
- Source Locations is a four-bit packed record stored in one byte. V has four
  independent bool fields, occupying four bytes. Logical flags and their mutations
  match; layout, union tags and ABI remain representation adaptations. Native
  observations also record Window, PrintResult, ChildOptions, BorderOptions and
  glyph carrier sizes; matching sizes alone do not establish ABI equivalence.
- Two carrier-copy differences are measured independently by `payload_copy.zig`
  and `payload_copy.v`. Source union copies own independent custom-array headers
  and packed location flags. V `BorderGlyphs` and `BorderWhere` sum carriers share
  boxed payloads: mutating a captured custom glyph header or location flag is seen
  by a copied carrier. Direct V `BorderCustom` and `BorderLocations` record copies
  are independent and match Source. Ordinary value copying of a sum carrier is
  therefore outside logical copy parity, in addition to its ABI difference.

Observed native record sizes in bytes (both comparison modes):

| Carrier | Source | V |
| --- | ---: | ---: |
| Locations | 1 (4 bits) | 4 (32 bits) |
| Window | 32 | 32 |
| PrintResult | 6 | 6 |
| ChildOptions | 144 | 176 |
| BorderOptions | 128 | 88 |
| Glyphs | 104 | 16 |

Source supplied allocators map to V GC ownership. Allocation-failure parity,
uninitialized or dangling source pointers and arrays, and cross-platform record
ABI are excluded. The existing `Window.new(&Screen)` helper is a V convenience
adapter; public Source root-window creation is compared through `Vaxis.window`.

Five focused consumers in `vaxis/window_contracts_test.v` exercise complete manual
records, root-window creation, optional defaults, custom glyph borrowing and
public mutation/copy independence. The broader border and scroll/mouse behavior
belongs to the separate Window operation comparisons.
