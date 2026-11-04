# Native V strings as Writer byte slices

`WriteStream.print_value` maps V `string` and aliases to Source `[]const u8`
carriers. `s` aligns raw bytes, `x`/`X` emit hexadecimal, `b64` emits standard
base64, and `any` recursively formats decimal byte values. Empty formats remain
invalid for slices. Precision is ignored by `s`/`any`; encoded formats forbid both
precision and width before writer effects, even at depth zero. Depth zero under
`any` emits `{ ... }` without visiting bytes.

The private helper borrows `value.str`/`value.len` using `vbytes`, avoiding the
allocation performed by V's `bytes()`. Explicit `*` writes `u8@` and the original
storage address, ignoring options and depth. Present optional strings and aliases
unwrap under `?s`/`?x`/`?X`/`?b64`/`?any`/`any`; absent values retain aligned `null`.
`?*` formats the unwrapped address. Record fields, dynamic/fixed arrays and
`Writer.print` arguments use the same dispatch. This is a byte-slice adaptation,
not a claim about Unicode text, source type identity or private string layout.

The unchanged public Source formatter is called through the locked image writer.
Nine forms cover strings, aliases, present/absent optionals and optional aliases,
records and dynamic/fixed string arrays. Binary inputs, all 256 byte values,
UTF-8 examples, empty values, options, depth and capacities are included. Memory,
positional/streaming files, replaced pipes and closed descriptors are modeled.
Four snapshots retain writer/backing/views, position, descriptor/file state and
input bytes/header identity. Caller mutation changes input and writer backing
before a final snapshot/flush; the formatter never changes input storage.

An independent model composes per-byte hex writes, each base64 chunk, alignment,
recursive byte/record/array writes and writer operations. Each mode matches
**15,609 records**, including **6,681 records containing WriteFailed**.
**12 external compiler pairs** verify binary encodings, optional aliases,
record/array fields, print composition, original addresses (including empty
strings and optional unwrapping), invalid formats and runtime format strings.
Address controls compare each process's output with its actual input address;
they do not compare raw allocation addresses across processes.

**33 panic/state pairs per mode** retain exact backing/pending/unused bytes.
Thirty enforce the option prohibition for x/X/base64, including optional presence;
three cover inherited padding overflows after root/record byte-list prefixes.
Diagnostics remain exactly `reached unreachable code` or `integer overflow` in
production too. Thirty-three returning controls retain partial writes, absent
optional bypass, maximal-width raw text padding and recursive depth cutoffs.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 15,609 | `516b19e86376b7790895e2124a490ffa40c945b9c86599212081d5a33abd2cab` |
| Isolated failure/control states | 66 | `1c8ded5ed05e8f1c0284d4ae7e45274ca6955df39f543f6c5a9aaadd5a71cc26` |

Five regressions and a portable consumer additionally cover binary byte
behavior, aliases, recursion, options, partial writes and address identity. Source
requires static formats; V accepts runtime strings and returns errors for
unsupported formats. Static Source rejection of invalid optional payload formats
can occur even when V would return aligned `null` for an absent value.

All 124 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical record and
print comparisons retain their hashes in both modes. Vaxis runtime tests are
not rerun.

All non-dispatch leaf formatters, IO/C and previous runtime files are unchanged.
The previous dispatcher reconstructs exactly after removing the string branch and
the updated carrier diagnostic. Source/library (including base64), compiler
executable, implementation, fixtures, model/helper and input pins are checked
before/after. Expected results and proof bodies freeze before both-mode runs.
Independent replay verifies records, failures, compiler outcomes and provenance;
every retained archive member is read back.

General allocation/copy/lifetime equivalence, invalid string headers, overlapping
input/output storage, concurrent mutation, huge successful output/storage, broader
pointers and Source comptime coercions remain outside the claim. Runtime evidence
is pinned little-endian 64-bit macOS; cross builds establish compilation only.

```sh
python3 zigimg/verify_writer_string_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-string-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
