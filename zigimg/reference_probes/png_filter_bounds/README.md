# PNG filtering exact bounds and retained output

`verify_png_filter_bounds_reference.py` calls unchanged public PNG filtering at
zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_png_filter_bounds_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The default runtime target
is `aarch64-macos.14.0`. Commands have a configurable timeout. Retained artifacts
include source copies, binaries, corpus, every command/output, public failure
snapshots, provenance and summaries. Compiler temporaries/caches belong to the
proof. Source implementation and private helper visibility remain unchanged.

The row-filling adapter now delegates pixel-range checks to the already checked
`PixelStorage.slice`, preserving full Source index/length messages. Packed samples
check the destination byte before updating it. Sixteen-bit rows check the native
word index/word length before loading its bytes, replacing V byte-array diagnostics.
Exact-division checks still precede word indexing. All guards remain active in
production, and Source's packed clipping and shorter word destinations remain.

| Returning observations | Count |
|---|---:|
| Matched indexed/gray/RGB/RGBA rows and short writers | 11,688 |
| Shorter or empty sixteen-bit destination rows | 180 |
| Zero-height try-all calls | 16 |
| Output failure before the next short pixel range | 192 |
| **Total** | **12,076** |

Returning SHA-256 in both modes:
`c1c523a2bf3693e10088e1476b6d31841d1eb0e855bc78106445e925c99177e3`.

Rows cover the fifteen supported PNG color/depth combinations plus direct
indexed16 storage, widths 0/1/2/3/9, heights 0/1/2, two initialized patterns,
none/sub/up/average/paeth/heuristic choices and zero/short/exact/long memory outputs.
Word controls use five sixteen-bit storage layouts with widths 2/4/8, heights 1/2
and smaller declared channel sizes, including a zero-byte destination. Short
output can return InvalidData on a completed row before reaching a later pixel
range failure. This precedence is observed through actual compiled Source.

| Exact panic/state pairs | Count |
|---|---:|
| Short pixel ranges before row conversion or output | 672 |
| Packed input with an empty destination | 162 |
| Short word source before filter choice/output | 108 |
| Odd sixteen-bit destination bytes | 20 |
| Unequal eight-bit copy lengths before try-all | 5 |
| **Total** | **967** |

Failure-state SHA-256:
`b710976b02b6955cfb609aa85612ab3696bb2270629092d9cb42b980a1aa3126`.

Short pixel ranges cover sixteen layouts, widths 1/3/9, heights 1/2/3, specified
none/heuristic choices and first-row try-all. Output capacities permit all earlier
rows, including exactly the completed prefix, so the next fill failure wins over
a simultaneous writer error. Packed failures cover six indexed/grayscale layouts,
three widths, none/heuristic/try-all and capacities 0/1/8. Word failures cover
indexed16/gray16/gray16-alpha/RGB48 against RGBA-sized rows, with those choices and
capacities. Odd destinations and unequal byte copies establish conversion before
choice/output. Strict checks require the exact sole panic message, unsuccessful
exit, no stdout/unexpected return and disabled core dumps.

All snapshots compare writer position, every caller output byte initialized to
165 and complete initialized input pixel bytes. Input remains unchanged. Failed
private current/previous scanlines and allocator effects are excluded. Indexed
palette storage is not read or compared. Returning records also retain recoverable
status and full output. No handwritten expected decoder output replaces Source.

A separate native-observed clipping control and module golden verify that gray4
samples 3/8/13 fill a one-byte declared row with 0x38, leaving the third sample
unused and the input intact. Both modes preserve the previous 43,389-record
filtering SHA-256 and 43,200-record FNV64, with all ten historical trap pairs.
All 61 image and 58 Vaxis test files pass, with 19 production/platform checks.
Cross builds establish compilation only. Initial V fixture pointer construction
errors and the corrected pre-fix exact diagnostic mismatch remain separate from
completed proofs. Completed runs freeze implementation, fixtures and input.

The runner checks full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, Zig 0.15.2,
V 0.5.2, and before/after fixture, implementation, runner, helper and corpus hashes.
The [historical filtering proof](../png_filtering/README.md) separately retains
DEFLATE and checked-helper pins, larger pattern coverage, arithmetic and inherited
unreachable/try-all controls.

Source-undefined initial scanlines at unsupported nonzero sample depths, failed
private row buffers, inactive/uninitialized palettes, arbitrary wide allocation/
indices, heuristic large-count overflow, allocator/OOM/GC/lifetime, const/narrow/
union typing, arbitrary SIMD/targets, file writers and portable ABI remain outside
this bounded public-filter proof. The pinned PNG image encoder still omits its
commented-out data writer; this change does not extend that Source boundary.
