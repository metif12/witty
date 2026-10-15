# Numeric format record contracts

`NumberFormat` translates pinned `std.fmt.Number`; `NumberMode` translates its
nested `Mode`. The Source `case` field is spelled `letter_case`, matching the
existing V writer parameters. All six represented fields are public and mutable.

| Mode | `base()` |
| --- | --- |
| decimal | `u8(10)` |
| binary | `u8(2)` |
| octal | `u8(8)` |
| hex | `u8(16)` |
| scientific | `none` |

Defaults are decimal mode, lower case, absent precision/width, right alignment
and space fill. `FormatOptions.to_number(mode, letter_case)` copies both optional
integers, alignment and fill while using the supplied mode/case. Absent values
remain distinct from present zero. Record copies, by-value returns and later
argument mutations retain independent values. This checkpoint supplies format
records; float rendering and byte-size formatting remain unported.

The runner compares the public, unchanged compiler-library declarations at their
original visibility. Debug/ordinary and ReleaseSafe/production each match
**25,480 complete returning records**, with SHA-256
`cce7031efc0a921872f0c3c3d655676ecdaee0d02e878b02451ba770c08c83e1`.
Every record also matches an independent Python value model.

Five construction forms cover default, mode/case-only, explicit, converted and
precision/width-only records. Seven operations cover unchanged values, mutations
of either copy, changed source options, chained by-value returns, whole-record
reset and reconversion. Observations retain the initial number/options and all
three final numbers/options, including each mode's optional base. Cases cover
all modes, cases, alignments and fill bytes, absent/zero/maximal option values,
values above signed-64 range, and 1,000 seeded random inputs. No enormous output
allocation is needed: precision/width are record data only.

Per mode, two external accepted consumers execute assertions and produce exact
output. They cover defaults/base lookup, direct enum aliases, conversion and
field mutation. Twenty-three rejection pairs cover immutable fields in direct
and converted records, incorrect field/conversion types, unknown enum tags and
passing an optional base without unwrapping. These are ordinary compiler
rejections; there are no application traps in this record-only proof.

A 185-record stratified preflight and all compiler consumers pass in both modes
before the final comparison. Development evidence retains the probe's signed
`strings.Builder` interpolation of large unsigned values. Explicit `u64.str()`
bypasses that builder optimization; typed value assertions and unchanged native /
Python outputs distinguish the observer issue from record storage. Production
implementation bodies do not change during those fixture corrections.

Both modes retain the historical duration suite's 38,653 records, 598 returning
controls and 288 exact panic/state pairs, plus the full/streaming IO suite's
37,133 records, 17 generic traps and four compiler boundaries. Historical hashes
are unchanged. All 98 image test files and 17 focused production, application,
Windows and Linux checks pass. Vaxis source remains unchanged from its retained
runtime validation; dependency builds pass. Cross builds establish compilation.

Complete Source SHA-256 remains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler-library SHA-256 remains
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole fmt.zig is pinned at
`667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500`
and whole Io.zig at
`09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef`.
Whole math.zig/meta.zig retain the integer proof's pins as well.
Runtime and compiler controls check before/after pins, versions, helpers, inputs,
fixtures and implementation. The complete unchanged Source tree is retained for
provenance; this new probe invokes the compiler's formatting records directly.
Old IO/C bodies remain byte-identical.

Value behavior is established on little-endian 64-bit macOS with the pinned
compilers. Record/optional/enum ABI, raw invalid enum casts, other widths and
platform runtimes, broader literal/coercion rules, reflection, allocation/lifetime
and remaining V representation limits are outside this proof. In particular, the
existing mode-dependent oversized fill-literal boundary is not redefined here.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_format_number_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-format-number-20261015/verified-proofs.tar.gz`, with a
checksum, per-file manifest and complete member read-back before the commit.
Failed development probes remain separate from final comparisons. Task-owned
compiler caches and temporary files are excluded from the manifest.
