# Enum Writer value dispatch

`WriteStream.print_value` formats enum values and aliases with `d`, `b`, `o`,
`x` and `X`, using the carrier's signedness. `t` aligns the tag name and ignores
precision. Empty and `any` formats write `.tag_name`; enums marked
`@[nonexhaustive]` instead write `@enumFromInt(number)` for unnamed values.
Default formatting checks forbidden precision and width before writing.
Named defaults use a vectored dot/name write; unnamed defaults retain separate
prefix, integer and closing writes. Arrays recurse through existing helpers.

The public regressions cover signed enums without negative named tags, unsigned
64-bit extrema, aliases, tag alignment, unnamed values, fixed and nested arrays,
depth cutoffs, unsupported formats and every capacity around named/unnamed output.
The enum helper guards its generic body because the pinned V compiler also
generates unused specializations for arrays of enums.

The native fixture calls the original public Zig 0.15.2 Writer.printValue body
without changing Source or visibility. Eight carriers (`u8`, `u16`, `u32`, `u64`,
`i8`, `i16`, `int`/Source `i32`, `i64`) each have exhaustive, nonexhaustive and
aliased forms: 32 types. The main comparison covers scalars, dynamic slices and
nested dynamic slices. Fixed arrays additionally have public regressions,
external compiler consumers and a portable build/run fixture; they are outside
this enum suite's complete retained-state matrix.

Five snapshots retain backing, position, pending/unused views and headers,
descriptor state, input payload/spans, options, actual typed leaf bytes and
file/wire contents through caller mutation and flush. Memory, positional and
streaming files, replaced pipes and closed descriptors are covered. Shape names
specify construction; nested descriptor layout and every copied value are not
observed. An independent Python model predicts enum names/numbers, recursive
writes, vectored boundaries and writer state.

Debug/ordinary and ReleaseSafe/production each compare 11,256 returning records,
208 isolated returning controls and 208 exact panic/state pairs. The main corpus
contains 2,511 independently predicted WriteFailed states; all 208 returning
controls also fail to write. Panics comprise 192 forbidden-option checks and
16 invalid unnamed-tag checks. Each requires one exact diagnostic, empty stdout
and matching retained state, including production. Five groups cover tags and
numeric extrema, write order/failure, numeric/tag options, recursive enums and
every capacity through 65 bytes. Both modes retain these goldens:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 11,256 | `21959274d17fcbc7f36ef1d92cd57f68f29a8b78aa073ab1a27ec1d7ff6df87e` |
| Isolated returning controls | 208 | `d68c854bd76a58d737148506f61e7fc864130014bdfee1ffed60bd71ad447690` |
| Panic/state controls | 208 | `ef9706f86674434cf02bc10b1fd8dcc3ec175b0f7b403bdf5728f96cd3b93c8b` |

Nineteen external compiler pairs per mode cover five accepted consumers, three
paired ordinary argument rejections and eleven measured boundaries. Source
requires compile-time formats; V accepts runtime strings. Unsupported enum
formats are Source static rejections versus V errors before writer effects.
The pinned V compiler rejects enum declarations with `usize`/`isize` carriers
and an `i8` tag explicitly equal to 127, all accepted by Source. Nonexhaustive
unnamed signed maxima remain covered by the returning matrix. The V
`nonexhaustive` attribute is an explicit adaptation of Source's `_` declaration.
Aliases retain its behavior in the measured cases.

Flag enums, escaped/keyword tag names, arbitrary attributes, unsafe invalid
exhaustive values, broader coercions and ABI/layout are outside this proof.
Full Writer.print, custom formatter reflection and further dispatch remain
unported. Other formatter bodies, IO and C are unchanged.

All 113 image test files and 21 production/application/Windows/Linux commands
pass. The portable fixture runs natively in both modes and compiles for Windows
in both modes and Linux. Cross builds establish compilation only. Historical
primitive, recursive slice and fixed-array comparisons retain their previous
hashes in both modes. Vaxis source is unchanged and dependencies build; its
runtime tests are not rerun. The unchanged Ryu tables retain all 1,336 limbs.

Whole Source and selected compiler libraries, Io/fmt/math/meta/enums/base64 /
float/path/encoder pins, versions, implementation, shared models/helpers,
fixtures and inputs are checked before and after. Runtime and comparison bodies
freeze before final comparisons; the portable fixture is pinned before final
platform checks. Only six EXPECTED assignments change afterward. Retained evidence
is replayed independently, including compiler outcomes and build modes. Every
archive member is read back before committing. Development evidence stays
separate from final proofs.

Evidence is pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge
successful output/storage, private allocation and lifetimes remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_enum_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Users/alex/.cache/witty-writer-value-enum-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
