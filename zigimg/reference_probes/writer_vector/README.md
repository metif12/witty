# Public Writer.printVector adaptation

`WriteStream.print_vector(format, options, lanes, max_depth)` translates Zig
0.15.2's public `Writer.printVector` helper. Inline fixed arrays carry the lane
values in V; ordinary `print_value` array dispatch remains unchanged. Fixed-array
and element aliases are accepted for native integers, f32/f64 and bool.

Depth zero emits `{ ... }` in one write. Otherwise the helper writes `{ `,
formats each lane with the unchanged format/options and one less depth, writes
`, ` between successful lanes, and closes with ` }`. Byte lanes use scalar
numeric formatting, so `x` emits `{ 1, ff }` rather than the ordinary byte-array
encoding `01ff`. The direct public helper also accepts valid scalar character,
Unicode, duration and byte-size formats. It does not implicitly add vector
carriers to `print_value` or `Writer.print`.

The native fixture calls the unchanged public Source body through the locked
image writer. Seven carriers cover i64, u8, bool, f32/f64, an integer/array alias
and u64, with lengths one, three and eight. Numeric formats, raw lane bits,
special floats, options, depth and capacities are checked. Four snapshots retain
position, backing/pending/unused bytes, descriptor state, constructed lane bits
and file contents through caller-buffer mutation and flush. Memory,
positional/streaming files, replaced pipes and closed descriptors are included.
The independent model composes lane writes using the pinned scalar integer,
float rendering and writer-state models.

Each build mode compares 7,048 records, including 2,992 records containing
`WriteFailed`. Fifteen external compiler pairs add all native scalar widths,
direct character/Unicode/unit formats, invalid carriers and leaf formats, runtime
formats and pointer lanes. That compiler control now accepts both implementations;
the original checkpoint rejected V pointer lanes. The later
[pointer-lane comparison](../writer_vector_pointer/README.md) records the extended
carrier support and compiler limits. Unsupported scalars, aggregates and optional
nonpointer lanes are rejected before depth can bypass their validation.

Eight paired traps per mode retain the exact outer writer state when a float
lane exceeds the existing hexadecimal formatter's 50-byte scratch buffer. Both
languages report `attempt to unwrap error: WriteFailed`. Sixteen returning
controls show that earlier opening-write failure or depth zero suppresses that
trap, including partial cutoff-marker writes.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 7,048 | `0dd0cd3406c6ea2e24f15e0e02b6810ee36eb91ac833da51ca5b71799154f32b` |
| Isolated failure/control states | 24 | `9d9c88403f6d22fc485dc081642ec4acd0e418a1b1b538314ea608353ec98da3` |

Source formats are static and leaf validity is checked even with zero depth.
V validates visited leaf formats at runtime: an invalid format can leave the
opening write, or be bypassed at zero depth. The fixed-array adaptation establishes
lane values and formatting, not native vector ABI, packing, alignment, copying
or mutation equivalence. Zero-length array declarations, nonnative integer/float
widths and other existing scalar boundaries remain unrepresented or unproven.
Pointer/optional-pointer lanes have a separate comparison linked above. Runtime
evidence is little-endian 64-bit macOS; cross builds establish compilation only.

Five public regressions and a portable consumer cover aliases, per-lane padding,
byte-array distinction, bool/float/character formats, partial writes and V runtime
validation. All 121 image test files and 23 additional production/application /
platform commands pass, including native/production consumers and Windows/Linux
builds. Historical fixed-array and floating-point hashes remain unchanged in both
modes. Vaxis runtime tests are not rerun.

Source/library, compiler executable, implementation, fixture,
runner/helper and input pins are checked before/after. Float dependencies and
all 1,336 Ryu limbs are checked separately. Counts/hashes and proof bodies freeze
before final ordinary/production runs. Retained records, compiler outcomes,
failure states and provenance are replayed independently; every archived member
is read back. Development evidence stays separate.

```sh
python3 zigimg/verify_writer_vector_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-vector-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
