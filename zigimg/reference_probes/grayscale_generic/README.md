# Public generic grayscale factories

`Grayscale[T]` and `GrayscaleAlpha[T]` represent the pinned public type factories.
They expose mutable value/alpha fields and copy their scalar storage by value.
Unsigned integer and f32/f64 conversion uses the existing Source-shaped scaling
helpers. Signed records can be constructed, while conversion remains a compiler
error, as in Source. Plain boolean/string conversion also remains rejected.

Two call shapes adapt the pinned V compiler's generic limitations:

```v
gray := zigimg.Grayscale[u64]{value: u64(1) << 63}
rgba := zigimg.Grayscale.to_colorf32(gray)
alpha := zigimg.GrayscaleAlpha.init(f64(.5))
rgba_alpha := zigimg.GrayscaleAlpha.to_colorf32(alpha)
```

Use `GrayscaleAlpha.init(value)` when Source supplies its default alpha. It
returns the integer maximum, including signed maxima, or 1.0 for floats.
For a direct generic alpha literal, supply both fields explicitly. V 0.5.2 cannot
resolve the type-dependent field initializer and eagerly checks generic receiver
methods for signed records even when the method is unused. Static conversion
calls keep construction usable and retain compiler rejection at conversion.
The nine named built-in records retain their existing receiver methods and
required-value enforcement.

`verify_grayscale_generic_reference.py` imports complete unchanged Source at
original visibility. Both corresponding modes match **25,740 returning records**,
SHA-256 `65e24bc45804982251cc4a6fea67f6feb4f3501ad47c75aa33bcd51018c7aefa`.
The corpus covers u8/u16/u32/u64/usize, f32/f64, two numeric aliases, plain/alpha
records, default/explicit alpha, every mutable field, independent copies,
by-value returns and whole-copy replacement. Integer boundaries, floating
signed zero/subnormals/infinities/NaN payloads and seeded random values retain
every record and conversion bit, including f64-to-f32 results.

A separate native comparison observes five signed alpha defaults and copied
records without invoking their unsupported conversion, SHA-256
`19d4071100765fcc1c8fd06207ca2f2ed8e328dc2543f322c0552a8aebe8e490`.
The nine omitted-alpha differences retain SHA-256
`21c2fe5cc65150c9b49d96cf387ddd1348d0e7ae27a81cc7368c4f2165ee27b0`.
Compiler controls cover
eighteen accepted numeric constructors, ten signed constructors, twenty-seven
immutable-field rejection pairs and twelve unsupported-conversion rejection pairs.

Three measured representation/compiler differences remain:

- Eighteen empty generic constructors are rejected by Source and accepted by V,
  which ignores generic required-field annotations.
- Nine direct alpha literals with omitted alpha retain zero in V, while Source
  supplies opaque defaults. Their full differing outputs are retained; the
  `init` constructor is the verified default-alpha path.
- Six Source built-ins are aliases of their generic specializations. V retains
  separate nominal built-in types to preserve their required-field checks, and
  rejects assignment from the corresponding generic records.

The existing 10,232 named-record observations and frontend/width controls retain
both mode hashes. Color-model and constructor/getter matrices retain their
31,167- and 35,362-record hashes. All 61 image and 58 Vaxis test files pass, with
23 production/platform commands, including new generic Windows executables and
a Linux executable. Cross builds establish compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven std.math files, the SDK math header, compiler versions and before/after
implementation/runner/fixture/input/consumer hashes protect the proof. Sub-byte
and wider-than-native integer types, unrepresented generic types/callers,
physical ABI and allocation/lifetime remain boundaries. Source implementation
and visibility are unchanged.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_grayscale_generic_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-grayscale-generic-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete read-back verification. Compiler
experiments and development previews remain retained. Regenerable task-owned
compiler caches and temporary files are excluded from the manifest.
