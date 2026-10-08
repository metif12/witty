This proof uses the pinned PNG `ChunkWriter` public type factory, record fields,
`write`/`flush` methods and `chunkWriter` constructor. Original dependency bodies
and visibility are unchanged. It is separate from the established chunk-writing
matrix and preserves that matrix's corpus and hashes.

From the repository root:

```sh
python3 zigimg/verify_png_chunk_records_reference.py \
  /tmp/witty-png-audit-20261008/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/witty-png-zig-20261008/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-png-chunk-records-proof
```

Add `--v-prod` with a fresh work directory for ReleaseSafe versus V production.
`--zig-mode` overrides the native mode. A positive finite `--timeout` applies to
builds, compiler controls and producers. The runner verifies Zig 0.15.2 and
V 0.5.2, sets `VEXE`, disables core
dumps, and retains source copies, exact compiler/process argv and environment,
raw streams, source/fixture/consumer hashes and `result.json`. Every native proof
uses a fresh Zig global cache; source trees and fixture/implementation hashes
are rechecked after comparison, including copied fixtures and the runner hash.

Both modes compare **163 returning records**, SHA256
`54fe144e5a027d6259fa65b01ae19169fd5470bf14f350593635306bd6dd9ec9`.
They cover capacities 0, 1, 4, 16 and 16,384 with sixteen seeds, default `end=0`,
complete public record literals, public field mutation, independent copied
inline buffer/end/identifier state, borrowed views into live inline bytes,
owned buffer data returned from a constructor with local storage, and shared
underlying output. Aliases of scalar `u8`, fixed buffer, writer and full record
are included. A pointer writer preserves its shared writer state when the outer
record is copied. The standard factory's identifier, capacity and `end` default
are observed without reading default buffer bytes. Destination and observed
buffer bytes are always initialized first.

Source requires `unbuffered_writer` and `section_id`; V records now declare both
with `@[required]`. Source default `buf` bytes are undefined, while V initializes
its buffer. The proof excludes Source undefined-byte observations and seeds the
buffer before hashing or flushing it. Both record types retain public mutable
fields and inline fixed-array value copies.

The pinned V compiler ignores required-field attributes on this generic record.
**Six independent Source omission consumers ordinarily reject**: each required
field or both, through the direct record and an alias. The matching **six V
consumers compile and run**, observing their defined V defaults. These are
measured constructor-enforcement differences, including the record alias;
they are not paired rejections. No public generic fields were replaced to hide
that compiler limitation.

**Five ordinary storage rejection pairs** exclude word arrays, pointer arrays,
arrays of pointer aliases, scalar storage and pointer-to-array carriers. Fixed
arrays of scalar aliases of `u8` now work. The byte constraint checks pointer
indirection before alias normalization and retains the fixed-array constraint.
Native Source uses `[buffer_size]u8`; V's generic `B` names the represented
inline storage type. V cannot declare `[0]u8`, so capacity zero uses an empty
`[]u8` or an alias of that exact slice. An additional V compile control excludes
a dynamic array of scalar byte aliases; dynamic arrays are not inline storage.
The older writer proof separately checks runtime nonempty-slice rejection.

Source can construct a record with scalar `W=u32` and read its fields without
instantiating writer methods. The unchanged native consumer returns normally.
Pinned V eagerly checks the specialized generic methods and ordinarily rejects
the matching record. This **one record-only `W` boundary** is separate from the
supported concrete adapter, its alias and its pointer used by this proof.
Source `Error` type aliases, Zig error sets and V result errors have different
type representations; arbitrary writer types are not certified by these cases.
The Source legacy `Writer`/`writer()` and `ZlibCompressor` failures remain the
previously measured Zig 0.15.2 boundaries, with no replacements in this proof.

The historical chunk writer still matches **5,960 records** with SHA256
`934ba176552e9370b30073ea1f648fab7dcb4ca85424296097b173f4d298115e`,
**28 additions** with SHA256
`4632f854f9f77422d2de7a764c23a1a4fd81ff8223c310bcfb53f8032841e317`,
and six strict trap pairs in both modes after these record/element changes.
This record proof introduces compiler controls rather than additional runtime
trap claims. Ordinary rejections require expected diagnostics and exclude
compiler crashes, generated-C failures and linker failures.

Source revision is `d7b7ab0ba0899643831ef042bd73289510b39906`; full `src`
SHA256 is `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected Zig 0.15.2 Reader/Writer/CRC/memory/debug helper SHA256 is
`8f15ac8ae0cb2cdabf972d66be18fda272d2a2fecee4673107bbfa1b2c949fa9`.
Allocator/GC/OOM, undefined bytes, record ABI/layout, wider native slice/index
representations and readonly input-slice typing remain outside the comparison.
