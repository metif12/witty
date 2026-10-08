This proof calls the unchanged public `InfoProcessor.init`, `processor`,
`ReaderProcessor.processChunk`, and `processPalette` APIs from zigimg commit
`d7b7ab0ba0899643831ef042bd73289510b39906`. It also constructs the public
processor record directly. The complete copied `src` tree must match SHA256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`
before compilation and after execution. No dependency bodies or private
source helpers are changed or exposed.

Run from the repository root, substituting the local source and compiler
paths as needed:

```sh
python3 zigimg/verify_png_info_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/witty-png-zig-20261008/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-png-info-debug

python3 zigimg/verify_png_info_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/witty-png-zig-20261008/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --workdir /tmp/witty-png-info-prod
```

`--v-prod` selects Zig `ReleaseSafe` unless `--zig-mode` explicitly overrides
it. Ordinary V defaults to Zig `Debug`. The default native target is
`aarch64-macos.14.0`, linked with libc. A supplied `--workdir` must be absent or
empty and retains the exact copied sources, fixture hashes, commands,
diagnostics, corpora, binaries, result metadata, and panic-state files.
Without that option, temporary artifacts are removed after execution. Zig
uses a fresh global cache beneath the work directory. `--bounds-only` omits
the two returning corpora but retains the constructor and trap checks.

The runner pins the translated Zig 0.15.2 reader/writer/DEFLATE sources to
`e8898fcced291d899efc9ebacf42762954ac5a1e088283cee0f1f261a498cab5`
and its format/float files to
`9ad2e71bc2e950a01e29eec9d20a6e9674097602774399a5451839a23c4b278b`.
The native diagnostic output runs through those unchanged dependencies.

Both ordinary/Debug and production/ReleaseSafe gates compare:

| Observation | Records or pairs | SHA256 |
| --- | ---: | --- |
| Historical diagnostic corpus | 51,223 | `87adba8bfd33b6f94e620ef6b277496fe1303c0fc80ca07a261f22fae0af7d4a` |
| Added suppression and exact-limit corpus | 1,041 | `05946f5a7cbbcdc928e51c71edb9d4d6ee25c208ef21611cd4562bf6c91bcff8` |
| Direct/init defaults, counter copy, borrowed writer | One combined record, two complete constructors | `4915f0abe0141219e84b1fdf33fbe144f55ef9379143743f5a5cee6176b08a1a` |
| State at checked panics | 16 | `529d510c5be49ae7fa2e42b35e70ec2c0786cc88e77e1d87c57c79f7e470445a` |

Returning records include the returned format/error, input position, IDAT
count and size, output position, and hash of the whole initialized output
buffer. The historical corpus covers every diagnostic branch, palette
lengths, short input, output capacity, binary byte-size formatting, raw text,
compressed zTXt, and buffered decompression. Its cases and hash are retained.
The added corpus checks failed prints before malformed header names/text
fields, both nonzero iTXt flag variants, and successful additions reaching
`u32` and `u64` maxima. Compressed iTXt remains printed as raw bytes, and an
unknown zTXt method retains the source's unusual input position.

The 16 isolated traps cover both IDAT additions and their precedence, four
invalid tag-name lookups, four missing NUL delimiters, missing zTXt/iTXt
fields, and the iTXt slice after a single remaining flag byte. The exhaustive
color/interlace invalid-tag probes inject raw tag bytes; they test the
source's checked malformed-carrier failure, without treating those carriers
as ordinary valid enum values. Compression/filter enums permit unnamed
values, whose `@tagName` calls still trap.

A fixture-only root panic observer writes count, size, input/output position,
and the full initialized output-buffer hash before delegating to Zig's
normal panic handler. V's fixture uses `at_exit` for the corresponding
observation. The observer does not change processor statements or replace
the failing operation. Size overflow retains the prior count increment;
count overflow stops before the size addition. Failed writer calls can
return before later tag, delimiter, index, or slice checks. Checks remain
active in V production builds. A trap requires nonzero exit, no ordinary
stdout, no `UNEXPECTED` marker, and an expected category on an actual anchored
panic-message line. Returned errors, success, crashes without the expected
panic, and category words occurring only in a backtrace do not qualify.
Native indexed-access panics map to V's checked `array.get` category; message
text, stack traces, and process exit codes need not be identical.

One paired ordinary compiler rejection verifies omitted `writer`. Complete
controls demonstrate default-zero counters, public counter mutation, by-value
counter independence, and a shared writer pointer while its storage remains
alive. Two additional compile probes record source rejection and V acceptance
of an explicit unsafe nil writer and an immutable writer reference. They are
representation/qualifier boundaries, not matched constructors or safe runtime
nil accesses. V GC allocation, writer lifetime outside these live scopes,
allocator contracts, whole-record ABI, reader-options generic constructor
contracts, and other PNG reader/writer processors are outside this proof.

Focused consumers are in `zigimg/png_info_test.v` and
`zigimg/png_info_fidelity_test.v`; each can be compiled and run with the pinned
V executable in ordinary or `-prod` mode. They cover callback/options borrowing,
suppressed writes, exact diagnostics, the addition limits, text-field failure
ordering, invalid names suppressed by earlier failed writes, and copied
counter state sharing the writer.
