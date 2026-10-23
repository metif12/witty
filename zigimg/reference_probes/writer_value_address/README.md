# Pointer address Writer value dispatch

`WriteStream.print_value("*", options, value, max_depth)` dispatches the
represented pointer, optional-pointer and dynamic-slice carriers to the unchanged
`print_address` helper. Native u8/u16/u32/u64/usize, i8/i16/int/i64/isize, f32/f64
and bool are covered, including scalar, pointer and slice aliases. Plain voidptr
represents Source's opaque pointer. V int prints Source's `i32` spelling.

Pointers and slices print the child type, `@`, and lowercase hexadecimal address
without padding or `0x`. Optional pointers print the pointer type, with address
zero for none. Opaque pointers print `anyopaque`. Slice length does not affect the
address. Precision, width (including present zero and maximal usize), alignment,
fill and depth are ignored. Byte slices bypass their text/hex/base64 option rules.
The prefix and digits remain separate writes; no target is dereferenced.

V can classify optional pointers by their scalar payload, so option/pointer
detection precedes scalar dispatch. Byte slices retain their existing non-address
formats. All other formatter bodies, IO and C are byte-identical to the previous
checkpoint. The public regression covers aliases, optional float/bool pointers,
null, ignored options, a live borrowed slice and partial address output.

The Source fixture calls the original public Writer.printValue("*", ...) without
changing its body or visibility. Deterministic synthetic pointer bits use Source
allowzero/align(1) for non-optional pointers/slices; optional addresses are aligned
or null. Seven forms and all 13 native scalar types are exercised. An additional
external consumer checks the address of live borrowed storage and unchanged bytes.
Synthetic addresses establish formatting, not allocation validity or permission to
dereference arbitrary integers.

The independent model reuses the direct address model for type prefixes, integer
digits and the two write boundaries, then separately models ignored dispatch
options/depth. Five complete snapshots retain backing bytes, position, pending /
unused views and headers, descriptors, argument bits/spans/options/type/length /
depth and file/wire contents through caller changes and flush. Memory,
positional/streaming files, replaced pipes and closed descriptors are covered.

Debug/ordinary and ReleaseSafe/production each check 39,484 complete returning
records and 3,234 isolated returning controls: 42,718 returning observations.
No valid represented address case is expected to panic. The 12,939 WriteFailed
observations preserve every independently predicted state. Six groups cover
type/alias/address-bit edges, write order/failure, every prefix/digit capacity,
every caller mask, seeded addresses and ignored options/depth. The frozen bodies
produce these hashes in both modes:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 39,484 | `1ce2999c904df36a3c8b2f2b8fa7160e2fa6d0427abe4db5691d811d1e6566bc` |
| Isolated returning controls | 3,234 | `04a44532abf84d9a8d63fa9e596ae1fd1b112f4f3092c28848f840fc0cf768a2` |
| Panic/state controls (empty) | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Sixteen external compiler pairs per mode cover four commonly accepted consumers,
six paired ordinary rejections and six explicit boundaries. Source requires a
compile-time format where V accepts a runtime string. Source rejects non-pointer
`*` or unsupported pointer `d` statically; V returns an error before writer effects.
Compound/nested pointees remain unrepresented in V. An optional const pointer
prints `*const u8` in Source and `*u8` in V; that pair is explicitly non-equivalent.
Qualifier, sentinel, struct, enum, function, arbitrary nominal type names, string
carriers and broader coercions/ABI remain outside this stage.

All 110 image test files and 17 production/application/Windows/Linux commands are
checked. Cross builds establish compilation only. Vaxis source is unchanged and
its dependencies build; its runtime tests are not rerun. Historical primitive and
character/codepoint dispatch are rerun in both modes with unchanged hashes. Full
Writer.print, custom formatter reflection and further dispatch remain unported.

Whole Source and selected compiler libraries, Io/fmt/math/meta/time/path/encoder
pins, versions, implementation, shared models/helpers, fixture and input hashes
are checked before and after. Runtime/test/fixture/model bodies freeze before
final comparisons; only the six EXPECTED assignments may change afterward.
Independent replay verifies every observation, compiler outcome, mode, binary and
provenance pin. Every retained archive member is read back before the checkpoint
commit. The earlier RAM workspace was unavailable on resumption: its transient
proofs are not claimed retained or successful; surviving SSD logs and the current
superseded run remain separate. Fresh final proofs are archived before RAM release.

Evidence is pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge successful
output/storage, private allocation and lifetimes remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_address_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Users/alex/.cache/witty-writer-value-address-20261015/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches are
excluded; owned RAM and reserves are released after commit.
