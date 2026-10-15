# Duration formatting

`print_duration_unsigned(nanoseconds u64)`, `print_duration_signed(nanoseconds i64)`
and `print_duration[T](nanoseconds, options)` translate the pinned
std.Io.Writer duration helpers. The generic variant accepts ten V native integer
types and ten direct aliases: u8/u16/u32/u64/usize and i8/i16/int/i64/isize.
V int maps to Source i32 in the corpus. Generic FormatOptions precision is
ignored; width/alignment/fill apply to the completed representation.

Units are fixed 365-day years, seven-day weeks, days, hours and minutes, followed
by seconds/milliseconds/microseconds with at most three fractional digits, or
integer nanoseconds. Fractions truncate instead of rounding, then omit trailing
zeros. Zero prints '0ns'; exact larger units return immediately without '0ns'.
Microseconds use ASCII 'us'. For example, 1001ns prints '1.001us', 1100ns prints
'1.1us', and 1000001ns prints '1ms'. Signed negative values write '-' first;
signed minima retain their full unsigned magnitude.

Direct methods preserve separate sign, integer, unit and fractional writes.
The generic method first renders into a private 24-byte writer, then aligns its
completed bytes. Consequently their partial failures can leave different backing
contents. Existing IO/C bodies, Source bodies, visibility and syscalls are
unchanged. Temporary allocation/stack representation is outside the claim.

Debug/ordinary and ReleaseSafe/production match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 38,653 | `a3bde2e30b52f05830955a26b88c6e4ab91777b3888ce47b104aeb9165662ec1` |
| Returning boundary controls | 598 | `babed571c162e6585daa27be296f0f7303bb817ece029c1753cd4937553aeb8c` |
| Exact panic/state pairs | 288 | `9b01a092f2612575570e56d7522ce47407b4e4f5ad23ab761a6ca142e03fcf0a` |

Returning records include caught WriteFailed. The eight deduplicated groups cover
unit boundaries, native/alias boundaries, write order/failures, every fraction,
options, every fill byte, large combinations and the private-buffer boundary.
Every complete record/control has five independently modeled snapshots: initialized backing, pending bytes /
length, logical position, unused-view length/offset/bytes, raw argument carrier /
relative view, type/options metadata, descriptor validity/references, caller
changes, flush results and complete file/pipe output. The model uses divmod to
build separate unit/digit/fraction pieces and reconstructs padding, scratch
preparation, positional/streaming drains and pipe transitions. Direct output
writes pieces individually; generic output joins them before alignment.

Coverage includes all three APIs, ten native types/ten aliases in generic calls,
zero and signed/unsigned extrema, values on both sides of unit boundaries,
9,000 fraction records spanning every thousandth for s/ms/us and all three APIs,
large combinations, ignored precision, all alignments, omitted/zero/short/long
widths, every fill byte, memory/positional/streaming writers, zero/short/24/65-byte
capacity, starts zero/three, empty/full pending output, regular/replaced-pipe /
closed descriptors, caller changes and flushes. Maximum widths retain only
finite failure/trap/bypass paths; huge successful padding runs are excluded.
The 288 exact pairs comprise 60 padding overflows and 228 private
rendering failures. Every pair has empty stdout, one exact diagnostic and a retained
destination state matching both implementations and the model after prior writes.
FullPanic / at_exit capture before opening the retained state file.
The modeled exact-trap cases have no prior pipe output. Traps remain active in
production. For valid 64-bit input the post-minute remainder is below 60 billion
nanoseconds, making its multiplication by 1000 safe. Some signed representations
are 25 bytes: '-101y11w1d11h11m123.456ms' is one example. Direct output can write
that full representation. Source's generic 24-byte temporary fails internally and
panics with 'attempt to unwrap error: WriteFailed' before touching the destination.
V preserves that exact panic. Controls cover ms/us, trimming transitions around
24/25 bytes, i64/isize and aliases, all writer kinds, existing output, unavailable
IO and maximum/omitted widths. The private failure precedes parent alignment/IO.

Compiler controls compare invalid value/options types, negative unsigned input
and a beyond-u64 literal. Fill 256 rejects in Source; V ordinary warns and emits
an actual NUL padding byte, while V production rejects. Source also accepts u7/i7
duration values, whose V carrier declarations reject. A u128 value cannot narrow
to the Source unsigned duration parameter; that Source case and the corresponding
V carrier declaration reject. External consumers verify all three methods,
untyped positive/negative generic literals, extrema and ignored precision with
actual output. Other coercions and non-native widths remain boundaries.

Four public regressions, all 97 image test files and 17 focused production,
application, Windows and Linux checks pass. Historical integer formatting retains
30,856 records, 720 returning controls and 742 exact panic/state pairs per mode.
Full/streaming IO retains 37,133 records, 17 generic traps and four compile
boundaries per mode. Their hashes remain unchanged. Generic traps do not prove
exact state. Vaxis source is unchanged; runtime tests are not rerun and dependency
builds pass. Cross builds establish compilation only.

Complete locked zigimg Source retains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler libraries retain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole Io.zig/fmt.zig/math.zig/meta.zig keep their existing pins. This suite adds
whole time.zig at
`b8b686d5ecaa81cb25b3234229a85cf0ff99c5bd6153283b272fe586c558d7f1`.
Runtime and compiler controls check pins before/after, plus versions, path/encoder
libraries, implementation, probes, direct helpers and inputs. Final runtime bodies
freeze before discovery; only EXPECTED assignments change afterward. Preflight
passes 161 records/8 exact panic pairs before final comparisons start.
Preliminary regression evidence retains a V fixed-array slice copy in the
fractional scratch buffer, corrected with an explicit borrowed byte span, and a
mistaken extra-day expectation for u64-max output. Corrected regressions pass in
both modes before preflight. An earlier full matrix found the pinned Source's
private-buffer failure; its implementation/runner, fixtures and logs remain
separate. The final implementation/model preserve that failure and the new
preflight checks both panic categories before fresh final comparisons. Old IO/C
bodies stay byte-identical.

Independent replay checks every record/model, exact failure, compiler outcome,
actual mode, binary, provenance pin and old IO/C body. Lossless parent compression
pins raw/compressed outputs. Every retained archive member is read back before
committing exact reviewed hashes and releasing the owned RAM workspace. Recorded
jobs survive headless input turns.

From the repository root, with pinned compilers and a fresh work directory:

```sh
python3 zigimg/verify_writer_duration_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /Users/alex/.cache/witty-jpeg-scan-20261013/tools/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /path/to/fresh/proof
```

Add `--v-prod` for ReleaseSafe / production. Runtime is little-endian 64-bit
macOS. Other platforms/CPUs, big-endian/32-bit runtime, arbitrary devices/short
drains, injected errors/signals, syscall counts/timing, invalid/concurrently
changed headers/tags, huge storage/OOM, allocator lifetime, portable ABI,
general coercions/non-native widths and remaining V representation limits are
boundaries. Other formatting APIs remain outside this checkpoint.
