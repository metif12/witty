# SGI header debug payloads

`SgiHeader.debug()` now sends the pinned Zig formatter's anonymous-record payload
to V's standard debug logger. Field order, punctuation, spacing, unsigned decimal
values and dotted enum labels match Source. Both fixed byte arrays are printed in
full as `{ 0, ... }` decimal lists: the 80-byte image name is not decoded as text,
and all 404 padding bytes remain visible. No type name, address or newline is added.

`verify_sgi_debug_reference.py` imports the complete unchanged Source tree and
infers the private Header type through SGI's public `header` field. It calls the
actual public Source debug method with every field initialized. The root callback
captures the actual message, debug level and default scope; V uses a capturing
implementation of the standard `log.Logger` interface. Source bodies, enum/type
definitions and visibility remain unchanged. No alternate formatter supplies
expected text.

Run from the repository root, then repeat with `--v-prod` and a separate empty directory:

```sh
python3 zigimg/verify_sgi_debug_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Source Debug compares with ordinary V, ReleaseSafe with production V, using
Zig 0.15.2, V 0.5.2 and `aarch64-macos.14.0` with libc. Both modes match
**6,470 records**, SHA-256
`199f41511a424f50adaa8b631ea6aefeefb2bf8c903cbf58c728f736f951be47`.
Each configured enabled/suppressed logger runs 3,235 cases:

| Record group | Count per configuration |
|---|---:|
| All compression/dimension/pixel-format combinations and byte boundaries | 288 |
| Every byte value at every position of both arrays | 256 |
| Single nonzero array positions, with four boundary byte values | 1,936 |
| Individual unsigned 16-bit field boundaries | 36 |
| Individual unsigned 32-bit fields at decimal and width boundaries | 111 |
| Every enum combination with zero through three repeated calls | 96 |
| Seeded full records | 512 |

Records compare every message byte, callback count/classification and all caller
fields before/after logging. Array patterns include zero, non-ASCII bytes, newline,
quote and backslash values; arrays remain decimal lists. Every byte position is
exercised independently, including the final element. The byte channel-width field
spans 0..255; dimensions and u32 scalar fields include their maximum values.
Repetition preserves message order and header contents. The module regression
locks two full payloads observed directly from Source, including byte 403 of padding.

Source thresholds are explicitly configured at compile time; the V capture logger
filters at runtime. Default logging levels, timestamps/prefixes, routing, global
logger ownership/synchronization, eager versus lazy formatting, allocation/OOM,
custom scopes, physical layout and logger ABI remain adaptations. Invalid enum
representations and undefined Source fields are excluded. Decoding is unchanged.

All 61 image and 58 Vaxis test files pass. Eighteen production/platform checks
cover IFF/SGI/TIFF production tests, native/Linux application checks, three Windows
dependency libraries, Windows SGI tests in both modes, two Linux shared libraries
and Windows/Linux builds of the fixture. Cross builds establish compilation
coverage; they do not establish foreign-platform runtime parity.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner also pins fmt/log/std/Writer files and hashes V's logging library,
compiler versions, implementation, fixtures, runner, helpers, settings and inputs
before/after comparison. Commands retain stdout/stderr.

Artifacts are retained under `/Users/alex/.cache/witty-sgi-debug-20261013`.
The original Source sample and runnable previous V hook demonstrate the formatting
difference. The first build hit a disk-space limit before its command log could
be written; that partial directory and the successful comparison before locking
goldens remain separate from final proofs. The previous IFF checkpoint archive
was fully verified before its expanded duplicates and compiler caches were pruned.
The final SGI archive is verified by reading every member against its manifest.
