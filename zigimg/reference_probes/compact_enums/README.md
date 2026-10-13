# Compact image enum storage

`PostConversionBehavior`, `NetpbmFormat` and `PamTupleType` now have explicit
`u8` backing and native ordinals. Their initialized storage and alignment are
one byte, matching the pinned Source enums instead of V's default four bytes.
Source's inferred tag integers remain u1, u2 and u3 respectively; V's u8 carrier
does not reproduce those integer type widths.

`verify_compact_enums_reference.py` imports complete unchanged Source at its
original visibility. Ordinary V/Source Debug and production V/Source ReleaseSafe
both match **3,584 returning records**, SHA-256
`9009c28f3efdd4db457b134de4c62873ee83534cf7837b3c89a73b3071a49fee`.

The two public enums cover every named value, 256 seeds and array lengths
0/1/2/3/7/16/64. Records observe size, alignment, names, ordinals, copied values,
by-value returns, initialized original/cloned byte slices and subsequent
mutation. Valid tags written through the clone's borrowed byte view remain
independent of the original array. Empty slices compare lengths and contents;
their pointer identity is excluded.

PAM's `TupleType` and `Header` are private in Source. The native fixture retains
the public PAM decoder, and `dsymutil`/`dwarfdump` extract the original compiled
enum's size, alignment and six names/ordinals in each corresponding compiler
mode. Six V records compare against that native debug metadata. Source files
and visibility are unchanged; no private header access or substitute oracle is
used. Two compiler controls retain Source's private-name rejections and V's
existing public adapter acceptance.

Both modes pass two accepted mutable enum controls and two immutable-assignment
rejection pairs. Source rejects two unnamed constant literals. Ordinary V
accepts those unsafe casts, while production V rejects them. These compiler-mode
differences are separate from the valid-value returning comparisons. Arbitrary
runtime integers, invalid byte writes and their failure timing remain outside
this proof.

The complete Netpbm and PAM contract matrices retain their returning and
retained-failure-state hashes in both modes: 137,226/74,189 returning records and
969/1,723 strict failure pairs respectively. The existing 5,792-case colorspace
comparison retains its corresponding-mode hashes with zero differences. All
61 image and 58 Vaxis test files pass. Nineteen production/platform commands
cover six color/math/codec test executables, native/Linux application checks,
three Windows dependency DLLs, four Windows matrix executables and two Linux
shared libraries. Cross builds establish compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Seven std.math files, the SDK math header, compiler/metadata-tool versions and
before/after implementation/runner/fixture/input/consumer hashes protect the
proof. Enclosing record field order/padding, undefined storage, arbitrary ABI,
allocator/lifetime behavior and unrepresented callers remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_compact_enums_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-compact-image-enums-20261013/verified-proofs.tar.gz`,
with checksum, per-file manifest and complete read-back verification. Before-change
implementations and development previews are retained, including the initial
fixture/compiler-control diagnostics. Regenerable task-owned compiler caches
and temporary files are excluded from the manifest.
