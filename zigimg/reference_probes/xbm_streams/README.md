# XBM positional file streams and retained delimiter buffers

`verify_xbm_streams_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` with Zig 0.15.2 and compares Debug
against ordinary V 0.5.2, and ReleaseSafe against production V.

```sh
python3 zigimg/verify_xbm_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, linked with libc. `--timeout` bounds build/corpus commands;
`TMPDIR` and `VTMP` select temporaries. Retained artifacts include unchanged
Source, fixtures, inputs, commands, outputs, binaries and provenance.

The shared delimiter refill previously moved retained bytes to the front before
every file read. Source `Reader.fillMore` rebases only when there is insufficient
tail capacity for one more byte; `readVec` resets a fully consumed buffer. The
translation now preserves that distinction. For a 24-byte caller buffer and
`#define w 8\n#define h`, both implementations return `EndOfStream` at position
12 with nine bytes buffered. Source retains the consumed first line in its
original location. The old translation overwrote it with the unfinished second
line. The pre-fix corpus has **1,884 differing records**.

Both final modes match **87,419 returning/error records / 181,446 calls**:

| Returning records | Count |
|---|---:|
| Every byte pattern, varied dimensions and refills | 46,080 |
| Complete/partial lines, EOF, initial discard and retries | 18,423 |
| First/pixel/trailing line lengths 0..131 and capacity boundaries | 14,256 |
| Define parsing, zero hotspots and retained fields on failure | 756 |
| Empty/odd dimensions and insufficient/extra pixel data | 1,296 |
| Every detector first byte | 6,144 |
| Detector EOF, unterminated lines, whitespace and initial discard | 230 |
| No-op static/interface writers, pending bytes and ignored options | 234 |
| **Total** | **87,419** |

Returning SHA-256:
`2387acb029df067d85d6dc60f14d55aa2fee2599887769738298879ba0d34b64`.

Readers use memory and file capacities 0, 1, 7, 11, 12, 13, 16, 24, 32, 64 and
128. Direct codec, static readImage and generic interface calls share each
stream across two attempts; returning detector controls use three attempts.
File descriptors start at EOF, independently of the positional reader cursor.
Snapshots compare position, buffered length, all initialized caller buffer
bytes, unchanged input/disk, and direct public codec fields. Successful reads
compare dimensions, indexed1 values and both palette entries, before/after
mutating borrowed pixel/palette views. Private failed/freed allocations, pointer
identities, inactive capacity and default readImage codec state are excluded.

Writers use a 32-byte memory buffer and file capacities 0, 1, 3, 8, 16 and 32,
three attempts, zero to three pending setup bytes, positional
offsets 0/7, a fully initialized RGBA32 pixel and dimensions up to native usize
maximum. Static and generic writers emit no bytes and leave pending data intact;
generic BMP/QOI options are ignored. An explicit fixture flush writes only the
setup bytes. No XBM encoder is added to the pinned empty writer body.

The inherited detector still peeks without advancing over a leading `#define`.
**24 paired loops** are stopped after half a second, after priming the delimiter
peek and emitting equal ready-state snapshots. These cover memory/file 12/64,
static/interface detection, offsets 0/3, and two leading-define spellings. Ready-state SHA-256:
`05322ee600feeba73130d3cfaaef0f8068a620379fd91bd191b86fbae0f3618d`.
No observation of the four-billion-iteration counter trap is claimed.

Full Source tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler-library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`;
additional fmt.zig SHA-256 is
`667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500`.
Versions and before/after implementation, Source, library, fixture, runner,
helper and input hashes protect the final comparisons.

Custom/nonseekable readers, pipes, operating-system I/O failures, larger
allocations, allocator/OOM/GC/lifetime, const/narrow/boxed representation,
physical layouts, big-endian/32-bit runtime and portable ABI remain boundaries.
Cross compilation establishes build coverage only. The historical
[XBM contract proof](../xbm_contracts/README.md) retains its previous hash.
