# Character and codepoint Writer value dispatch

`WriteStream.print_value(format, options, value, max_depth)` now dispatches byte
characters and Unicode codepoints through the existing text helpers.

| Format | V carrier and aliases | Source carrier |
| --- | --- | --- |
| `c` | u8 | u8 |
| `u` | u8, u16 | u8, u16, implicitly widened to u21 |
| `u` | u32 | u21, through an explicit fixture conversion |

Byte characters preserve all 256 byte values, including NUL and bytes above 127.
They copy width, alignment and fill into normal byte padding; precision and depth
are ignored. Unicode emits UTF-8 and ignores all formatting options and depth.
Surrogate halves and values above U+10FFFF within the u21 range become U+FFFD.

The u32 row is a representation adaptation, following the existing
`print_unicode_codepoint` API. Source rejects a direct u32 argument to `printValue`
with format `u`; V accepts u32 and checks the u21 range before writer effects.
The native runtime fixture converts a u32 carrier to u21 before calling the
unchanged public Source method. Values above 0x1FFFFF therefore trap at that
fixture conversion, while V traps in the existing helper's range check. These
conversion observations do not establish a panic inside Source's formatter body,
or equivalence of the two carrier types or their static acceptance.

Other integer character/codepoint carriers return V unsupported-carrier errors
before IO, while Source rejects the corresponding coercion at compile time.
Source requires a compile-time format; V takes a runtime string. General coercions,
untyped literals, signed characters/codepoints, non-native carriers, reflected
formatters and ABI/layout remain outside the equivalence claim.

The independent model uses Python's UTF-8 encoder and explicit replacement/range
rules, then models each byte write, padding, drain and failure boundary. Expected
output does not come from either implementation. Five snapshots retain full
backing, logical position, pending/unused bytes and headers, descriptor ownership,
raw argument bits/span, options/type/format/depth and file/wire contents through
caller mutation and flush. Memory, positional/streaming files, replaced pipes and
closed descriptors are represented. Source method bodies, visibility and shared
C observer syscalls are unchanged.

Debug/ordinary and ReleaseSafe/production each match:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 39,449 | `06c81d54a106939938cbb5465d8ad1f1cf7aa6bf9ffabcdb03dab7efa00bcb74` |
| Isolated returning controls | 360 | `b78a3c828e0f7d3c301a60f4b5cd320814a421faa98debe49ad17904c0b6a727` |
| Exact panic/state pairs | 368 | `31833d2705234a3eae9fe4bf4fa5dd27fc8b198099bc208ad38517cf24b00568` |

The 368 pairs comprise **32 formatter-body padding overflows** and **336 u21
carrier conversion checks**. Every pair requires one exact diagnostic, empty
stdout and matching independently predicted observer state. All remain active in
production. Returning WriteFailed observations retain exact state. Huge successful
padding/storage is excluded.

Nine groups cover all character bytes, independent fill/padding choices, UTF-8
boundaries, every surrogate half, plane samples, native u16 samples at stride 17,
aliases, depth zero/one/usize.max and ignored Unicode options. Capacity, pending
prefixes, writer mode, replaced pipes, closed descriptors, caller changes and
flushes preserve the existing state model. Controls include maximal widths,
conversion failures and conversion-before-option-bypass observations.

Sixteen external compiler pairs per mode include four commonly accepted consumers
for byte aliases/options, u8 Unicode aliases, u16 surrogates and unchanged ignored
Unicode options. Six paired ordinary rejections cover invalid parameters and
unrepresented carriers. Six separately measured boundaries cover runtime formats,
wide character/codepoint carriers, the V u32 extension, Source u21/V u32 adaptation
and an invalid specifier. A Source compile error is distinct from a V runtime
error; an accepted adapted-carrier pair is distinct from an identical-carrier pair.

Three public regressions, all 109 image test files and 17 production/application /
Windows/Linux checks pass. Cross builds establish compilation only. Vaxis source
is unchanged and dependencies build; its runtime tests are not rerun. Historical
primitive and duration/byte-size dispatch retain all hashes in both modes:
16,308 records / 343 controls / 159 panic pairs and 59,122 records / 1,127 controls /
476 panic pairs, respectively. Existing float dispatch and all other runtime/C
files remain byte-identical. The dispatcher changes only by adding the two text
branches before integer widening; existing formatter bodies are unchanged.

Whole Source and selected compiler-library pins, unicode/base64/fmt/Io/math/meta/
time/float/path/encoder pins, versions, implementations, shared models/helpers,
fixtures and inputs are checked before/after. Runtime/test/fixture/model bodies
freeze before final comparisons; only EXPECTED assignments change later.
Independent replay checks every observation/failure, conversion classification,
compiler outcome, mode, binary and provenance pin. Superseded development runs
are retained separately. Every retained archive member is read back before
committing exact reviewed hashes.

Evidence remains pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge successful
output/storage and private allocation remain boundaries. Further printValue
formats/carriers, full Writer.print and custom reflection remain unported.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_text_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence is retained at
`/Users/alex/.cache/witty-writer-value-text-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and full member readback. Owned RAM and reserves are
released after commit; regenerable caches are excluded.
