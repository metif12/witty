# String descriptor pointer formatting

Native `&string`, pointers to string aliases and pointer aliases now use the
Source pointee name `[]const u8`. Direct `print_address` and value-format `*`
write the descriptor's address, without inspecting its descriptor or text.
Default/`any` formatting preserves the type/`@` vector write followed by aligned
hexadecimal digits. Direct address formats ignore width, precision and depth.

Present optional `?*` values use the same descriptor address; absent values use
aligned `null`. Bare `*` and direct optional addresses retain `*[]const u8@…`,
including zero for absence. Direct optional calls now bind their payload before
normalizing pointer aliases through the existing value-address helper. This
avoids treating the alias itself as a second pointer level. Fixed-array and
slice element names also compose with native and optional string pointers.

The `unsafe` casts only convert the existing native pointer bits. V 0.5.2's
checker requires that scope for generic string pointees. A raw `voidptr` cast to
`&Text` (where `Text = string`) produces invalid C in the caller; the synthetic
fixture instead initializes a zero pointer and copies the native pointer bits.
Owned descriptors and pointer aliases exercise ordinary caller construction.
The construction diagnostic is retained separately from the parity corpus.

Unchanged public pinned Source methods and an independent writer-state model
match **10,960 full records per mode**, including **4,426 WriteFailed records**.
Seven native/alias/present/absent carriers cover direct/default/explicit address
formats, 190 input addresses, all capacities through 32, ignored direct options,
digit alignment and memory/file/pipe/closed-descriptor states. Some optional
addresses are aligned to eight bytes to represent Source's natural pointer type;
plain pointers cover every address bit. Four snapshots preserve position,
backing/buffered/unused bytes and file state through caller-buffer mutation and
flush. Synthetic addresses establish formatting only.

**77 isolated returning controls per mode** retain partial prefix/digit/null
writes and unused bytes. No controls panic. **11 external compiler pairs per
mode** check routes, aliases, owned descriptor replacement, optionals, pointer
array/slice element names, `print`, unsupported formats and runtime formats.
The previous direct-string suite's pointer-to-string rejection becomes a positive
owned-address control. Source rejects unsupported/static formats at compilation;
V rejects unsupported runtime formats before writing.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 10,960 | `9b0ab14a5a25f2dae78e14b3488848ba655d2ef275b4259f70a9214ea1fa5ab8` |
| Isolated return states | 77 | `50ac9566f9f1349f8fd4e8542762e0dfe4e75c07a4330276a3408640074e8260` |

Six public regression functions check raw/owned descriptors, aliases, zero and
optional pointers, exact partial writes, pointer elements, preserved header bytes
and address stability across text replacement. All 143 image test files and 24
additional production/application/platform commands pass. Portable consumers run
natively in both modes and compile for Windows/Linux; cross builds establish
compilation only. Historical scalar-pointer and direct-string suites retain
record/control/state hashes in both modes. Vaxis runtime tests are not rerun.

Reversing the string name, pointer casts and optional alias binding reconstructs
the previous runtime exactly. Other runtime bodies, parsing, direct string byte
addresses and C remain byte-identical. Source/library, executable,
implementation, fixture/model/helper and input pins are checked before/after;
expected outputs freeze before final runs. Independent replay verifies recorded
observations, failure state, compiler outcomes and provenance, and every retained
archive member is read back before commit.

The Source slice mapping does not equate V string/slice descriptor layout,
allocation, ownership or lifetime. Direct optional strings, deeper pointer
indirection, unsupported pointees and unrepresented qualifiers remain boundaries.
Generated GC traversal, overlapping input/output, concurrency and huge successful
output are outside the claim. Zero witnesses can use stack space proportional to
array types. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_string_pointer_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-string-pointer-20261105/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
