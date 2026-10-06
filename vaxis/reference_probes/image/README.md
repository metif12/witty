This proof calls public `Image.draw`, `cellSize`, `transmitLocalImagePath`,
`transmitPreEncodedImage` and `transmitImage` on unchanged pinned dependencies.
Source bodies and private visibility are not edited.

Run from the repository root:

```sh
python3 vaxis/verify_image_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --zigimg /tmp/witty-zigimg-audit/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  --build-dir /tmp/witty-image-debug
```

Add `--v-prod` and use a fresh build directory for Source ReleaseSafe/V production.
The default pair is Source Debug/V ordinary. `--target` defaults to
`aarch64-macos.14.0`; `--zig-mode` can override the Source mode. `--timeout`
sets each producer/build deadline. The runner sets matching `VEXE`, disables
core dumps and retains exact commands, selected child environment, copied
dependencies, Unicode table generation, consumer hashes, corpus, complete build
and runtime output, compiler diagnostics, panic observations and metadata.

Dependency pins are verified before and after the proof:

| Dependency | SHA-256 |
| --- | --- |
| Vaxis `src` | `bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` |
| Locked uucode package | `2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380` |
| zigimg `src` | `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b` |
| zigimg root entrypoint | `3e847079e41f2ca99ff7f77df1d374e7d05cadbd8c9043f02a850e63e5633812` |
| Complete recovered zigimg package | `6a2871b44b8699244584194964a3611cfd184805d1f8266188a1999bbc5188e0` |

The root zigimg entrypoint imports its tests even in an executable build, so the
complete recovered package is copied. Its entrypoint is outside the `src` hash.
Selected unchanged Zig 0.15.2 math, base64 and writer bodies are pinned separately
in the runner. The module graph generates Unicode tables from the unchanged
locked package with `../widgets_classic/source_build.py`.

The returning corpus contains **5,506 records**: 5,188 geometry, 156 local-path,
129 preencoded and 33 managed-image cases. Geometry covers all four scaling
modes, zero geometry, zero pixel sizes, u16 extremes, preserved optionals and
caller options, clipping, replacement of existing cell text/style/link, and
pixel products exceeding signed 32-bit range. A fully initialized one-cell
buffer is sufficient because every attempted write targets `(0,0)`; the public
geometry fields can be large without allocating or reading missing cells.

Both Debug/ordinary and ReleaseSafe/production retain returning SHA-256
`e58eae6f7ede06b34fc86cfab106ec0a8f106162693f3f06ab0ae5bab3c6157e`
and panic-state SHA-256
`89e0105b69174290783306c5ecf88ff4b3ea6fbe07429fe0c5420524a3e77897`.

Transmission cases observe exact bytes, returned dimensions/IDs and next-ID
state. They include every medium/format, raw NUL/invalid UTF-8 bytes, capability
gating, encoded path limits, 4,095/4,096/4,097/8,192/8,193-byte packet boundaries
and managed RGB/RGBA conversion. Exactly 4,096 preencoded bytes emit the initial
`m=1` packet without a closing packet, as Source does. PNG retains the pinned
writer's eight-byte signature-only behavior. Insufficient PNG buffers return
`WriteFailed` before image dimension casts, and capability errors precede both.
Some managed records use public dimensions that differ from the initialized
pixel slice; the operations under test only access the provided valid slice.

Eight isolated public failures compare strict panic categories and retained
public state. Local and preencoded ID overflow occurs in the exit defer; a
`PathTooLong` error still runs that defer. Managed width/height casts occur after
conversion/encoding and before registering a transmission ID increment. Invalid
PNG header assertions occur before PNG buffer writing. The fixtures observe
next ID and initialized managed pixel format/byte count, then continue through
the normal fatal panic. Nonzero exit, empty ordinary output and the complete
expected panic header are required; unexpected returning-fixture markers reject.
Panic text, stack, signal and cleanup ABI are not asserted equivalent.

Four represented Source record types enforce nine direct field omissions:
Image's three fields, CellSize's two, Placement's two and pixel offset's two.
Six complete V constructors additionally include the two sum payload wrappers;
those wrappers require their sole payload. The four paired complete constructors
permit direct mutation of every represented field. Rejections require an ordinary
compiler error with the exact missing-field diagnostic; crashes and backend failures
cannot satisfy those checks. Eleven V alias omissions are measured
separately: the pinned V compiler drops inherited required markers, while the
nine corresponding Source aliases reject. Source has union arms for path/memory
rather than those V wrapper records, so their two omission checks are V-only.

The V-only `ImageTransmission` adapter retains its existing zero-image default.
Image/CellSize and placement/offset records are mutable, while path/memory sum
payload wrappers remain read-only. Source mutable union payload access, V boxed
sum ownership, borrowed string/array headers, native aggregate ABI and arbitrary
copy/alias behavior are separate boundaries. Source writes and flushes through a
caller writer; V returns a complete string. Writer failure, partial output,
flush timing and allocator/GC failure cannot be inferred from this successful
allocating-writer comparison. In particular Source can expose packet bytes before
an ID-overflow defer traps; V's complete-string adapter does not return that
packet. Oversized primitive literals and narrower V constructor carriers remain
compiler-domain adaptations beyond the initialized typed inputs here.
