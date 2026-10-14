# PAM public option unions, row traversal and retained stream state

`verify_pam_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_pam_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The runtime target is native
64-bit little-endian `aarch64-macos.14.0`. `--timeout` bounds each command; `VTMP`
and `TMPDIR` can select compiler temporaries. Artifacts retain binaries, commands,
outputs, input/consumer hashes, panic snapshots, provenance and a JSON summary.

PAM options preserve mutable comment/duration fields. Both public write methods
now accept the complete encoder-option union. `writeImage` defaults other option
tags to empty comments and no duration metadata. `writeFrame` first rejects an
unsupported pixel format, then checks the PAM union arm before writing its header.
Its exact active-field diagnostic remains enabled in production.

Frame writing retains Source's usize row/column loops, checked row offsets and
pixel index/length failures. It does not multiply image dimensions into one
flattened int loop. A wide dimension can therefore write existing pixels and then
trap at the first missing pixel. Zero height bypasses traversal even with maximum
width. Source accepts grayscale2 in its header factory but omits the writer arm;
nonempty traversal retains `reached unreachable code` before pixel indexing.
Short header output still precedes all pixel traversal; completed earlier frames
and pixels remain visible on subsequent failure.

| Returning observations | Count |
|---|---:|
| Header tuple/depth/max-value/dimension combinations | 6,912 |
| Every byte component across tuple and scaling boundaries | 32,768 |
| Wide little-endian component boundaries | 960 |
| Complete header/raster prefixes | 2,240 |
| Multiple images, compatible/incompatible animation and trailing bytes | 100 |
| Empty/short/wrong magic controls | 40 |
| Numeric/whitespace/duplicate-key validation | 60 |
| All official tuple strings and retained trailing whitespace | 96 |
| Invalid headers preceding pixel-count overflow | 36 |
| Detection first bytes and short/trailing controls | 2,052 |
| Direct/static/interface writes across all 24 storage tags | 13,185 |
| All 17 encoder-option tags and validation order | 3,901 |
| Wide dimensions, zero extents and short output controls | 405 |
| Animation comments, loop counts and float duration words | 10,560 |
| Subsequent-frame failure order and partial output | 874 |
| Borrowed comments, field replacement and independent scalar option copies | 3 |
| **Total** | **74,192** |

Decoder/writer SHA-256:
`6918abab3af429f8fd98f930b0e70b800f100dd20c0f62571c82c373d373834f`.
Option borrow/copy/mutation SHA-256:
`ce4a89a7351dd22af4ec69bfe6cd07b1810e24616ac54ab2bbc842d720b90af1`.

**1,723 strict panic/state pairs** cover 960 wrong option-arm failures, 368 pixel
bounds, 275 grayscale2 unreachable cases and 120 decoder dimension overflows.
Exact full diagnostics, unsuccessful exit, no stdout, no unexpected return and
no core dump are required. Case names, diagnostics, initialized reader/writer
cursors, output, caller image/frame metadata and bytes, comments and unchanged
input join SHA-256
`97974518c141b10b9c5952a4502ff89aa03a00c4e7015c0d91e9f203d5988908`.
Failed private/freed decoder buffers and private header fields are excluded.

Returning decodes compare fully written main/frame bytes before and after toggling
a valid bit, independent nonempty allocation outside input, separate main/frame
backing and unchanged input. Writer snapshots retain every initialized output
byte and unchanged main/frame pixels/comments. Narrow pixel fields contain valid
Source values; unsupported palettes are not observed. No empty pointer identities
are compared. Animation cases include zero/one/two frames, every comment profile,
both duration flags, five signed loop counts and eleven f32 words: signed zero,
0.125, 2, 0.1, minimum subnormal, maximum finite, signed infinities and signed NaNs.
The unchanged historical duration matrix remains separately verified.

Default options, replacement of both mutable fields and two immutable-binding
rejections pass Source/V compiler controls. A separate compiler control records
that Source rejects assignment to a comment-slice element while V's mutable
array accepts it. Replacing the field and borrowing a caller-owned mutable array
retain the measured behavior; V does not reproduce the const-slice type contract.

Source's Header/TupleType are private. A dedicated unchanged-Source compiler
control requires its actual Header visibility rejection. The exposed V helper
header now requires all six fields; one complete constructor and six omissions
are V-only controls, not a native public-header parity claim. Header semantics
are compared through public encoding/decoding without changing Source visibility.
Internal V builder placeholders and physical header layout are unobserved.

Tuple inference, exact tuple-rest matching, duplicate header fields, raw comments,
component validation/scaling, little-endian 16-bit samples, monochrome-alpha AND,
short trailing magic retention and full-sequence validation remain unchanged.
Writer comments retain raw bytes/newlines, the loop comment only on the main image
and per-frame duration comments. Public sequence reads retain Source's frame
compatibility rules and duration/loop defaults.

File buffering and output retained before flush are checked separately by the
[PAM stream proof](../pam_streams/README.md); this fixture uses memory streams.

Allocator/OOM/GC/lifetime, explicit reclamation, wider allocated
extents, enum/narrow/const typing, exposed private helpers, physical records/
unions/slices, boxed payload copies, big-endian runtime and portable ABI remain
boundaries. Native checks do not establish cross-target runtime parity.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The runner
checks Zig 0.15.2/V 0.5.2 and before/after generated-input/consumer, fixture, runner
and implementation hashes. Every native fixture imports unchanged Source.
