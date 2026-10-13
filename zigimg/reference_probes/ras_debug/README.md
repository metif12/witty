# Sun Raster direct header diagnostics

`RasHeader.debug()` writes its five-line header message directly to stderr.
The existing payload is unchanged; a private helper now makes its complete bytes
available to module regressions. Width, height, depth, declared length and map
length use unsigned decimal values, while type/map labels retain their dotted
Source names. Each call ends with exactly one newline after `cmap_len`.

The older RAS contract suite already checks all 21 type/map pairs. This comparison
extends that coverage to scalar width/decimal boundaries, repeated calls, zero
calls, initialized header immutability and independence from logger thresholds.
The Source root configures debug or info logging and rejects any logger callback;
V installs a rejecting standard logger at the same two thresholds. Direct output
remains identical under both settings. It is not routed through a log callback.

`verify_ras_debug_reference.py` imports the complete unchanged pinned Source tree
and infers its private Header type through RAS.header without changing visibility.
Both fixtures call the public method on immutable, fully initialized headers.
Actual Source stderr supplies the expected bytes. Stdout carries only call counts
and all header fields before/after each group of calls. The runner verifies those
fields against the inputs, frames five lines per call, compares every Source/V
message byte, requires ordered repeated messages and rejects trailing output.
No alternate formatter supplies expected text.

Run from the repository root, then repeat with `--v-prod` and a separate empty directory:

```sh
python3 zigimg/verify_ras_debug_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Source Debug compares with ordinary V, ReleaseSafe with production V, using
Zig 0.15.2, V 0.5.2 and `aarch64-macos.14.0` with libc. Both modes match
**13,494 records** and **15,190 direct messages**, SHA-256
`5851cec9d8d4540cdba6c32cb4b769b08d122c4100f05735b7f759d3f58c0734`.
Each logger configuration runs 6,747 cases:

| Record group | Count per configuration |
|---|---:|
| Original initialized Source samples | 2 |
| All type/map pairs over byte patterns in u32 fields | 5,376 |
| Each u32 scalar at decimal and width boundaries | 185 |
| All type/map pairs with boundaries and zero through three calls | 672 |
| Seeded full headers with two calls | 512 |

Each scalar includes zero and maximum u32 values. Decimal transitions around
powers of ten and 2^31 are exercised individually. Both logger settings produce
identical stdout/stderr streams. Two module goldens lock original Source stderr
messages. The pre-refactor comparison has the same corpus hash, confirming that
this checkpoint extends verification rather than changing diagnostic text.

All 61 image and 58 Vaxis test files pass. Nineteen production/platform checks
cover RAS/IFF/SGI/TIFF production tests, native/Linux application checks, three
Windows dependency libraries, Windows RAS tests in both modes, two Linux shared
libraries and Windows/Linux fixture builds. Cross builds establish compilation
coverage. Historical RAS header/writer (2,585 records), decoder (40,320 records)
and 21-message debug hashes remain unchanged in both modes. The historical panic
matrix is not rerun for this diagnostic refactor; decoder bodies are unchanged.

The proof covers single-process message bytes and routing to an open captured
stderr stream. Concurrent interleaving, locking/stdio flush order relative to
stdout, failed/closed stderr, signal/async safety, custom build flags/platform
sinks, allocation/OOM, physical layout and portable ABI remain adaptations or
excluded. Invalid enum representations and undefined Source default headers are
excluded. Default codec palette storage is not observed.

Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner also pins Source fmt/log/std/Writer/debug files and hashes V's printing
and logger implementations, versions, implementation, fixtures, runner, helpers,
settings and inputs before/after comparison. Commands retain stdout/stderr.

Artifacts are retained under `/Users/alex/.cache/witty-ras-debug-20261014`.
The complete comparison before the refactor remains alongside both final modes,
historical checks and module/platform/formatting logs. The final archive is
verified by reading every member against its manifest.
