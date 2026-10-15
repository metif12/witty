# Native integer formatting

`print_int_any[T](value, base, letter_case, options)` and
`print_int[T](value, base, letter_case, options)` translate the pinned
std.Io.Writer.printIntAny / printInt methods for ten native integer types and
their direct aliases: u8/u16/u32/u64/usize and i8/i16/int/i64/isize. V int maps to
Source i32 in this corpus. `FormatCase` selects lower/upper letters;
`FormatOptions` supplies alignment, width and fill. Precision is ignored.

Negative values get '-'. Nonnegative signed values get '+' exactly when width
is present and nonzero; unsigned values omit '+'. Width zero/none does not add a
sign. Padding surrounds the complete signed representation: -12 with right width
5 and fill '0' becomes '00-12', and typed signed 12 becomes '00+12'. Width never
truncates digits. Use an explicit native integer type for Source-compatible
signedness; untyped literal differences are measured below.

The base is a byte. Bases zero/one panic before writer effects. Bases 2..255 are
accepted when every generated digit is below 36; a larger remainder panics
before alignment/output. For example, 255 in base 255 writes '10', while 254 in
base 255 traps. Signed minima are handled without overflowing signed abs.
Both methods finish constructing the representation before the existing
align_buffer_options call, retaining its padding, partial-error and scratch
behavior. Existing IO/C bodies and locked Source bodies/visibility/syscalls are
unchanged. Source's widening wrapper is represented by the same native integer
formatter; generic/code-generation costs are outside the claim.

Debug/ordinary and ReleaseSafe/production match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 30,856 | `c0860bc0ab3e4e8edb62f9ed02e9a3f6f0ea428c5c9f5e5686edd9232528fc9e` |
| Returning boundary controls | 720 | `83626d714d8d42ef1d6431d77d7d74f4c366dec670ba21834b9ae3d1b977eb94` |
| Exact panic/state pairs | 742 | `c17a2c69e5484247097c0a743263c4b83f0d91cb4679b78a60a6486e38ed526c` |

Returning records include caught WriteFailed. The five deduplicated groups
cover native extrema, alignment/failure order, options/signs, every 8-bit value
and all 256 byte-sized base values (zero/one in controls). Each complete record
and returning control has an independent model of five snapshots: initialized
backing, pending bytes/length, logical position, unused-view length/offset/bytes,
eight raw argument-carrier bytes and their relative view, type/base/case/options
metadata, descriptor validity/references, caller changes, flush results and
complete file/pipe output. Python's integer formatting handles bases 2/8/10/16;
other bases use mathematical divmod. The model separately reconstructs the
native sign rules and each padding/write/drain operation, including failed IO
scratch preparation and pipe transitions.

Coverage includes both APIs, all ten native types and ten direct aliases,
minimum/maximum/zero/one values, both letter cases, all alignments, omitted/zero /
short/long widths, none/zero/maximum precision, memory/positional/streaming writers,
empty/full pending output, zero/short/65-byte capacity, zero/three starts,
regular/replaced-pipe/closed descriptors, caller changes and flushes.
Maximum-width controls retain finite failures/traps/bypasses and exclude huge
successful padding. The 742 exact pairs comprise 678 base/digit precondition
failures and 64 padding overflows. Every trap requires empty stdout, one exact
panic message, identical retained state and an independent modeled state after
any prior writes. FullPanic / at_exit capture before opening the retained state
file. Application traps remain active in production.

Compiler controls distinguish these finite representation boundaries:

- Twenty paired type/option rejections per mode cover both APIs with bool,
  float, string, array and record values, plus invalid base/case/options and
  bool width/precision. A literal beyond u64 also rejects in both compilers/modes.
- Fill literal 256 rejects in Source. V ordinary warns and writes an actual NUL
  padding byte; V production rejects.
- Source printInt(1) with width 3/fill '_' writes '__1'; V's untyped literal is
  signed and writes '_+1'. Source printIntAny(1) rejects its comptime_int type;
  V accepts that literal and writes '+1' with width 1. Explicit native types are
  the returning equivalence domain.
- Source successfully prints u128, i128, u7 and i65 values. V declarations of
  those carrier types reject. A direct unknown-u128 generic argument causes
  V's type resolver to panic in both modes; this compiler crash is recorded
  separately from ordinary rejections and application panic/state pairs.
- External consumers exercise both APIs with all native/alias types, a
  FormatCase alias and actual signed/unsigned output.

Three public regressions, all 96 image test files and 17 focused production,
application, Windows and Linux checks pass. Historical text formatting retains
36,852 records, 512 returning controls and 188 exact panic/state pairs per mode.
Full/streaming IO retains 37,133 records, 17 generic traps and four compile
boundaries per mode. Their hashes remain unchanged. Generic traps do not prove
exact state. Vaxis source is unchanged; its runtime tests are not rerun and
dependency builds pass. Cross builds establish compilation only.

Complete locked zigimg Source retains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler libraries retain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole Io.zig and fmt.zig keep their existing pins. This suite additionally pins
whole math.zig at
`65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1`
and whole meta.zig at
`3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40`.
Runtime and compiler controls check these before/after, plus compiler versions,
path/encoder libraries, implementation, probes, direct helpers and inputs.
Runtime bodies are frozen before discovery; only EXPECTED assignments change
afterward. Preflight passes 161 records/nine exact traps. Preliminary compiler
evidence retains two mistaken fixture expectations: a beyond-u64 literal was
expected to wrap, and the unknown-u128 generic compiler crash was expected to be
an ordinary rejection. Corrected compiler controls pass before final runtime
comparisons. Neither correction changes implementation/probe/model bodies.

Independent replay checks every record/model, exact failure, compiler outcome,
actual mode, binary, provenance pin and old IO/C body. Lossless parent compression
pins raw/compressed outputs. Every retained archive member is read back before
committing exact reviewed hashes and releasing the owned RAM workspace.
Recorded jobs survive headless input turns.

From the repository root, with pinned compilers and a fresh work directory:

```sh
python3 zigimg/verify_writer_int_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /Users/alex/.cache/witty-jpeg-scan-20261013/tools/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /path/to/fresh/proof
```

Add `--v-prod` for ReleaseSafe / production. Runtime is little-endian 64-bit
macOS. Windows/Linux/other CPU runtime, big-endian/32-bit runtime, arbitrary
devices/short drains, injected errors/signals, syscall counts/timing, invalid or
concurrently changed headers/tags, huge storage/OOM, allocator lifetime, portable
ABI, general coercions/comptime integers/other integer widths and remaining V
representation limits remain boundaries. Other formatting APIs remain outside
this checkpoint.
