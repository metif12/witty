# Global TTY recovery reference comparison

`verify_recovery_reference.py` compares `recover`, `panic_handler`, and `Panic.call`
with the unchanged pinned Vaxis source. It checks the entire source tree before
copying it into the build directory; no dependency statements or visibility are
changed. The V fixture is compiled as a module-local test in an isolated copy so
it can observe the private registered snapshot without adding a public API.

Pinned inputs:

- Vaxis source tree: `bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
- Locked uucode source: `2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
- Zig 0.15.2, native `aarch64-macos.14.0`; V 0.5.2 fallback compiler.

Run from the repository root on macOS with a controlling-PTY-capable host:

```sh
python3 vaxis/verify_recovery_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-recovery-debug

python3 vaxis/verify_recovery_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --workdir /tmp/witty-recovery-prod
```

Each retained directory must be new. The runner selects Zig ReleaseSafe with
`--v-prod`, pins `VEXE`, disables core dumps, and retains compiler arguments,
returning observations, panic diagnostics, and all ordinary boundary diagnostics.
It uses the common `widgets_classic/source_build.py` dependency graph and content
verification. The product base module and these consumers do not require V's
`-enable-globals` option.

Both Debug/V ordinary and ReleaseSafe/V production pass:

- 56 paired returning PTY records, including absent registration, successful
  registration, failed first/subsequent init, caller mutation, caller deinit,
  repeated recovery, replacement registration, prefix writes, and reset-write
  failure using a read-only descriptor.
- 14 paired explicit-panic cases for absent/basic/`Panic.call`/trace/read-only/
  replacement/mutated state, with two prefix lengths. These compare reset bytes
  and complete restored terminal attributes before the panic runtime can finish.
- 48 Source-only buffered-writer observations, with buffer capacities
  1/8/32/47/48/49/64/128, recovery counts 1/2/3, and prefixes 0/5.
- Six individually measured ordinary compiler-rejection pairs for Source's
  removed-standard-library `FormattedPanic` aliases, plus one public-global
  access adaptation.

The returning-record SHA256, excluding the final file newline, is
`4101322a2b3636fd13ba3fa721e6bcedc928df711057799a2a46688d8d0dd645`.
The Source-only buffered-record SHA256 is
`336343f9e968444519d30154bd7c1d6fed3e0451066c9f19f03b581da34db850`.
Panic observations and compiler boundaries are separately checked rather than
counted in those hashes. The portable `vaxis/recovery_test.v` file adds two focused
consumers for absent recovery and independent/replaced snapshot ownership.

The PTY driver installs one explicit canonical terminal profile before each
consumer; macOS can otherwise retain raw attributes when a PTY minor is reused.
It reads reset bytes from the master and all attributes from the slave while the
child is still alive. Returning consumers wait on a separate release pipe, which
avoids changing terminal state through a fixture read. For panic cases, a full
stderr pipe blocks the panic diagnostic while the parent observes recovery;
the parent then releases diagnostics and requires the exact `recovery-proof`
panic header, nonzero exit, and no `UNEXPECTED` line on stdout or stderr. Master
output is drained concurrently with terminal restoration, and the PTY is closed
before waiting for process exit to avoid macOS descriptor-close stalls.

The implemented contract preserves the last successful initialization by value,
the exact 48-byte reset sequence, swallowed reset-write failures, restoration
after writing, and the registered snapshot remaining present after recovery.
On this macOS source, deinit restores attributes without closing the registered
descriptor. A second init records the already-raw state, so subsequent recovery
restores that second snapshot; the proof retains this source behavior.

Representation and runtime boundaries:

- V Tty writes are unbuffered. The paired proof uses Source `Tty.init` with a
  zero-length output buffer. The larger-buffer Source matrix proves that recovery
  does not flush: with a 48-byte buffer, the first recovery retains all 48 reset
  bytes in the global writer and emits none. These buffer-header/shared-storage
  effects are measured Source behavior, outside V's current Tty buffer contract.
- Source exposes `tty.global_tty` as a public mutable optional value. V uses a
  private C static GC root holding an owned value snapshot; public direct access
  ordinarily rejects in V while empty Source access compiles and runs. Registration
  and recovery retain Source's lack of synchronization guarantees.
- V panic entry points call the existing V panic runtime after recovery. Source
  StackTrace/return-address information, diagnostic formatting, and global panic
  hook injection are outside that runtime adapter; no automatic hook is installed.
- Source `Panic.sentinelMismatch`, `unwrapError`, `outOfBounds`,
  `startGreaterThanEnd`, `inactiveUnionField`, and `messages` each fail ordinarily
  with Zig 0.15.2 because `std.debug.FormattedPanic` no longer exists. Their V
  counterparts are absent. Each probe excludes compiler crashes, internal errors,
  and generated-C failures; `Panic.call` itself compiles and is exercised.
- PTY behavioral comparison is native macOS. Linux and Windows build gates cover
  the translated platform branches separately and do not establish PTY runtime
  equivalence on those hosts.
