# XBM checked arithmetic, parsing and retained caller state

`verify_xbm_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug with ordinary V and
Source ReleaseSafe with production V.

```sh
python3 zigimg/verify_xbm_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is 64-bit little-endian `aarch64-macos.14.0`. `--timeout` bounds corpus/build
commands; `TMPDIR` and `VTMP` select compiler temporaries. Artifacts retain full
Source, fixtures, binaries, commands, inputs, outputs and provenance.

The detector still peeks without advancing over a leading `#define`; the checked
u32 counter now retains integer overflow in production. Width-times-height and
expected-byte rounding have explicit native-usize guards at Source's assignment/
allocation/palette boundaries. On this verified 64-bit target the bounded u32
dimensions cannot overflow either usize expression. The four detector loop pairs
are each stopped after half a second; ready-state snapshots match, and neither
process returns. They do not reach the counter's four-billion-iteration boundary.
No runtime trap observations are claimed for these arithmetic guards or 32-bit
targets. The loops are intentionally retained from the pinned implementation.

Both modes match **15,337 returning/error records**:

| Returning records | Count |
|---|---:|
| Default records, mutable scalar fields and independent copies | 1 |
| Every byte pattern, varied widths/heights and continuous bit order | 7,168 |
| Delimiters and all byte separators | 2,304 |
| Hex token lexing over every byte | 2,048 |
| Define-value lexing over every byte | 1,024 |
| Byte/word boundaries and low-two-byte truncation | 450 |
| Signed/underscore/overflow numbers, define prefixes and whitespace | 630 |
| Ordered definitions and zero-sentinel hotspots | 16 |
| Complete and partial lines, EOF, CRLF and initial cursors | 1,336 |
| Empty/odd dimensions, maximal zero-area dimensions and data counts | 90 |
| Non-define/unterminated detector controls | 14 |
| Detector first-byte domain | 256 |
| **Total** | **15,337** |

SHA-256: `6544506d5e8c60983270a840d0b278fb9419c4690e7c7d1e8235040527065e0e`.

Records compare errors, cursor, fully initialized caller codec fields and input,
dimensions/format, pixels and the white/black palette. Mutable PixelStorage views
are compared before/after mutation and remain independent of input. Empty pointer
identities are excluded. Direct codec fields retain their original values before
the Source assignment boundary and parsed values after it. Default readImage's
private codec state is excluded. Failed/freed private pixel or byte-list storage,
uninitialized capacity and physical allocation/growth/lifetime are unobserved.
Private Source helper visibility is unchanged.

Define names remain ignored, later malformed defines still fail, zero hotspots
keep their sentinel behavior, first-pixel-line trimming differs from later lines,
CR is not a hex delimiter, large words retain only their low two bytes, bits span
row boundaries, extra tokens are accepted and unterminated final lines remain
unconsumed. The no-op writer remains unchanged. Generic interface/ignored writer
options, readonly/narrow typing, native layout, allocation/OOM/GC, wider extents,
file streams, big-endian/32-bit runtime and portable ABI remain boundaries. Cross
compilation establishes build coverage only.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The additional
fmt.zig pin is `667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500`.
Zig 0.15.2/V 0.5.2 versions and before/after Source/library/fixture/input/runner/
implementation checks protect the retained comparison.
