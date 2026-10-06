# Public packed Scale comparison

Run from the repository root:

```sh
python3 vaxis/verify_cell_scale_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_cell_scale_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

The fixture directly constructs, reads and mutates unchanged public
`vaxis.Cell.Scale` fields, uses its public `eql` method, and exercises Source
`@intCast`, `@enumFromInt`, `@intFromEnum` and `@bitCast` operations. It neither
changes Source bodies/visibility nor adds wrappers inside Source files. Source
has no Scale constructor or setter methods: the corresponding V factories and
setters adapt packed field access and language builtins.

The runner compares 24,580 returning records in ordinary V/Source Debug and
V `-prod`/Source ReleaseSafe:

| Records | Coverage |
| ---: | --- |
| 1 | Default Scale: scale/numerator/denominator 1, top alignment, bits `0x89` |
| 3 | Checked numeric enum construction for top, bottom and center |
| 8,192 | Every constructor combination: scale 0–7, numerator and denominator 0–15, raw alignment bits 0–3 |
| 8,192 | Every u13 pattern, getters, equality and independent value copies |
| 8,192 | Every initial u13 pattern with four sequential field mutations and snapshots; embedded Cell mutations, copied Cell independence and restoration |

The Source comments say numerator/denominator are limited to seven, but the
runnable u4 fields permit all values through fifteen. Zero scale, numerator and
denominator are also constructible; validation here preserves those values.
Renderer-specific validation remains in the renderer.

Forty-four strict native/V panic pairs cover each constructor/setter width
boundary, 255, 256, 65,535 and u64 maximum where representable by that entry,
u13 bit boundaries, enum tag 3, and oversized numeric enum inputs. Each requires
a nonzero exit, empty stdout, no unexpected-return marker and an actual anchored
panic header of the expected category. Fixture-only Source `FullPanic` and V
`at_exit` hooks also observe the previous packed value. Every failing operation
must retain exactly `3805,5,11,13,1,0`, proving that validation precedes mutation.
Core dumps are disabled. Six complete public consumers and six paired ordinary
compiler rejections separately check defaults, partial construction, public
mutation and invalid scalar/alignment types. Rejections require the expected
diagnostic on an actual `error:` line and reject compiler crashes/C-code failures.

Five Source-only compiler boundaries are measured separately. Source rejects
constant u3/u4 overflow, constant enum tag 3 and a constant oversized u13 value
during compilation; the wider V factories compile and guard equivalent runtime
values. One additional compiler boundary measures Source's rejection of directly
bitcasting an integer to its enum. V's unsafe literal enum cast of 3 is accepted
in ordinary mode and rejected with an ordinary enum-value diagnostic under
`-prod`. The returning matrix uses Source's legal packed-Scale bitcast and the
V bit-pattern factory for that raw representation instead; all 8,192 patterns
work in both modes.

Raw alignment bits 3 are representable in a Source packed Scale and survive
field reads, field assignment, copying and equality, even though the enum only
declares tags 0, 1 and 2. Consequently `from_bits`, the typed constructor and the
typed alignment setter preserve raw 3. `VerticalAlignment.from_int(3)` separately
traps `invalid enum value`. Width checks occur before tag checks, so numeric 4
and larger trap `integer does not fit in destination type`.

V preserves the existing getters, `init`, `eql`, two-byte backing storage and
default bits. It adapts the Source mutable fields as follows:

```v
mut cell := vaxis.Cell{}
cell.scale.set_scale(2)
cell.scale.set_numerator(3)
cell.scale.set_denominator(4)
cell.scale.set_vertical_alignment(vaxis.VerticalAlignment.from_int(2))
copy := vaxis.CellScale.from_bits(cell.scale.bits())
assert copy.eql(cell.scale)
```

The numeric factory/setter carriers are u64 and validate the Source narrow
domains before storage narrowing. Existing u8/u16 callers continue to widen
implicitly. This avoids a pinned V0.5.2 behavior where a literal such as 256
passed to a u8 parameter only warns and is truncated before entering a guard.
V still lacks Source arbitrary-width integers and its constant-checking rules;
the factory is limited to representable u64 inputs, rather than a compile-time
u3/u4/u13 type. The alignment parameter remains a typed byte-backed enum with
an explicit two-bit guard; caller unsafe casts can perform their own narrowing.
The getter returns raw alignment 3 without declaring a fourth enum tag.
These APIs preserve logical packed bits, not native packed-struct ABI or all
language builtin behavior. Private backing storage prevents ordinary callers
from bypassing the checked numeric adapters.

The native target defaults to `aarch64-macos.14.0` with libc. Before compilation,
the runner verifies original Vaxis `src` SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` and locked
uucode SHA256
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
`widgets_classic/source_build.py` copies and generates the unchanged dependency
graph. Original/copied source and dependency trees, fixture and runner hashes
are checked again after all comparisons.

`--build-dir /tmp/fresh-directory` retains exact build/run/compile/trap argv,
working directories, the complete selected child environment, stdout/stderr,
panic state files, corpus, mode/result/fixture metadata, unchanged copied trees,
tables and binaries. The directory must not exist. Only recorded PATH, HOME,
TMPDIR, SDKROOT, deployment target and locale values when present, plus pinned
VEXE and disabled C-error reporting, are inherited by child processes.
`--timeout` is a positive build/run deadline, default 180 seconds.

Returning output SHA256:
`1cd11fb0acef78afd31bb32546989e382fda9688b3275387855b0f3609b89a52`.
Ordered panic-state SHA256:
`3b12f3ab7fac4930f479b2ec9f320ddbe9ef18c293a1fee9e6f4d13b69430172`.
