# IFF header debug payloads

`BmhdHeader.debug()` and `DgblHeader.debug()` now send the pinned Zig formatter's
anonymous-record payload to V's standard debug logger. The payload retains
`.{ .field = value, ... }` punctuation, declaration order, signed decimal values,
dotted enum labels and Source's `x_asoect` spelling. It includes neither a type
name nor an address. The private IffHeader dispatcher uses these same hooks.
SGI payloads have a [separate comparison](../sgi_debug/README.md). TIFF generic
debug rendering and RAS direct printing remain unchanged.

`verify_iff_debug_reference.py` imports the complete unchanged Source tree at
original visibility. Its root log callback captures the actual payload supplied
by the public Source methods, level and default scope. The V fixture installs a
capturing implementation of the standard `log.Logger` interface. Source Debug
compares with ordinary V and ReleaseSafe with production V, using Zig 0.15.2,
V 0.5.2 and `aarch64-macos.14.0` with libc.

Run from the repository root, then repeat with `--v-prod` and a separate empty directory:

```sh
python3 zigimg/verify_iff_debug_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Both modes match **142,912 returning records**, SHA-256
`893786350ccb1081f99146384847741efd45b9f7a0e180a417c153ddea79591a`.
Each logging configuration runs 71,456 records:

| Record group | Count per configuration |
|---|---:|
| BMHD byte domains and all mask/compression choices | 3,072 |
| DGBL byte domains and all compression choices | 1,280 |
| Every signed 16-bit coordinate and unsigned 16-bit fields | 65,536 |
| BMHD boundaries with zero through three repeated calls | 384 |
| DGBL boundaries with zero through three repeated calls | 160 |
| Seeded BMHD/DGBL records | 1,024 |

Enabled records capture every message as hex bytes, along with debug/default
classification, callback count and all caller fields before/after logging.
Suppressed records produce no captured callbacks. Both coordinates span the
complete i16 domain; width, height, transparent color and page dimensions span
the complete u16 domain. Four mask, three ILBM compression and five DEEP
compression choices appear. All byte fields span 0..255. Repetition verifies
identical ordered payloads and no mutation.

The Source fixture explicitly sets `.log_level` to debug or info at compile time;
V configures its capture logger at runtime. The comparison certifies these
payloads and configured suppression, not identical default logging levels,
timestamp/prefix formatting, routing, global logger ownership, synchronization,
eager versus lazy formatting, allocation/OOM, custom scopes or logger ABI.
Invalid enum representations and uninitialized fields are excluded. Source
bodies, enum/type definitions and visibility are unchanged; no alternate
formatter model supplies expected text. Private IffHeader.debug remains private.

All 61 image and 58 Vaxis test files pass. Eighteen production/platform checks
include IFF/SGI/TIFF production tests, native/Linux application checks, three
Windows dependency libraries, Windows IFF tests in both modes, two Linux shared
libraries and Windows/Linux builds of the new fixture. Cross builds establish
compilation coverage. A module regression locks four payloads observed directly
from Source. Decoder implementation is unchanged.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner additionally pins Zig fmt/log/std/Writer files and hashes V's logging
implementation, compiler versions, implementation, fixtures, runner, proof helpers,
settings and inputs before/after comparison. Commands retain stdout/stderr.

Artifacts are retained under `/Users/alex/.cache/witty-iff-debug-20261013`.
The original Source sample and previous V payloads show the type-name/field-syntax
difference. Logging-file discovery attempts and the comparison before locking
goldens remain separate from completed proofs. Previous verified archives retain
expanded duplicate evidence pruned to recover disk space. The final archive is
verified by reading every member against its per-file manifest.
