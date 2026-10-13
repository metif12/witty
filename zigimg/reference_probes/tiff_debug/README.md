# TIFF bitmap diagnostic payloads

`TiffBitmapDescriptor.debug()` now sends the pinned Zig formatter's
anonymous-record payload to V's standard debug logger. Field order, punctuation,
spacing, unsigned decimal values and dotted enum labels match Source. Optional
strip arrays distinguish `null` from a present empty `{  }`. Rational pairs and
both the active data and eight backing words of each u16 fixed buffer are printed.
The payload includes its single trailing newline.

At Source's default formatter depth of three, each nested palette color appears
as `.{ ... }`. The complete palette data length and all 256 backing entries are
represented without exposing RGBA channels. External data views are formatted at
their actual length, even when they exceed the inline storage capacity.

`verify_tiff_debug_reference.py` imports the complete unchanged Source tree and
calls its public BitmapDescriptor.debug method. The root callback captures the
actual message, debug level and default scope. V uses a capturing implementation
of the standard `log.Logger` interface. Source bodies, enum/type definitions and
visibility are unchanged. Expected message bytes come exclusively from Source.

Run from the repository root, then repeat with `--v-prod` and another empty directory:

```sh
python3 zigimg/verify_tiff_debug_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Source Debug compares with ordinary V, ReleaseSafe with production V, using
Zig 0.15.2, V 0.5.2 and `aarch64-macos.14.0` with libc. Both modes match
**3,708 records**, SHA-256
`d2b914e99be534e8d5b9dd464680bafef5522f9a052b41695b6a1c217957cc48`.
Each configured enabled/suppressed logger runs 1,854 cases:

| Record group | Count per configuration |
|---|---:|
| Original initialized Source samples | 2 |
| All compression/resolution choices and zero through three repeats | 120 |
| Individual u32 fields at decimal and width boundaries | 296 |
| Individual u16 scalar boundaries | 60 |
| u16 backing/data patterns | 256 |
| Individual backing-word positions and boundaries | 192 |
| Every window into each eight-word buffer | 45 |
| Palette windows, including empty and full views | 30 |
| External word/color views, including lengths exceeding inline capacity | 36 |
| Absent/empty/nonempty optional strip-array pairs | 49 |
| Every RGBA byte value at every palette backing position | 256 |
| Seeded full records | 512 |

Every field and all inline storage are initialized, including inactive palette
entries. Observations compare exact payload bytes, callback count/classification
and before/after SHA-256 fingerprints of every scalar, optional-array presence
and contents, all fixed backing values, active data and logical nonempty aliases
into that backing storage. The fingerprints also match an independent reconstruction
of the fixture inputs. That reconstruction does not format debug messages.
Empty pointer identities, external allocation identities and array capacity/ABI
are excluded. Palette channel changes remain visible in state fingerprints even
though Source's message abbreviates them. Two module goldens retain payloads
observed directly from Source, including the terminal newline.

The existing readonly V receiver remains. Two ordinary/production mutable caller
pairs compile and execute; two separate immutable caller controls reject in Source
and compile/execute in V. That acceptance difference is a surface adaptation and
is excluded from the payload comparison. The controls and diagnostics are retained
under `receiver-controls` in the artifact directory.

Source thresholds are explicitly configured at compile time; V's capture logger
filters at runtime. Custom Source formatter depths, default logging levels,
timestamps/prefixes, routing, global logger ownership/synchronization, eager versus
lazy formatting, allocation/OOM, custom scopes, physical layout and logger ABI
remain adaptations. Invalid enum representations and undefined Source storage
are excluded. Decoding is unchanged.

All 61 image and 58 Vaxis test files pass. Eighteen production/platform checks
cover IFF/SGI/TIFF production tests, native/Linux application checks, three Windows
dependency libraries, Windows TIFF tests in both modes, two Linux shared libraries
and Windows/Linux builds of the fixture. Cross builds establish compilation
coverage; they do not establish foreign-platform runtime parity.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner also pins fmt/log/std/Writer and Source SHA-256 files, and hashes V's
logging, fingerprint and encoding implementations, compiler versions, implementation,
fixtures, runner, helpers, settings and inputs before/after comparison. Commands
retain stdout/stderr.

Artifacts are retained under `/Users/alex/.cache/witty-tiff-debug-20261013`.
The original Source sample and runnable previous V hook demonstrate the formatting
difference. The first comparison caught a fixture storage copy; using the existing
resize methods and fixed-array references preserves its intended borrowed views.
A dependency-file discovery attempt and the successful comparison before locking
goldens remain separate from final proofs. The previous SGI archive was fully
verified before expanded duplicates were pruned. The final TIFF archive is verified
by reading every member against its manifest.
