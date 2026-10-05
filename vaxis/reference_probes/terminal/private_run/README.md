# Fixture-only private Terminal loop comparison

This checkpoint measures the original private `Terminal.run` body on macOS.
Public PTY initialization and process spawning retain their separate macOS
compiler boundaries; this fixture does not add support for those public APIs.

The runner verifies the complete pinned vaxis `src` tree before copying it,
then appends exactly one fixture method to the copied `Terminal.zig`:

```zig
pub fn audit_run(self: *Terminal) !void { return self.run(); }
```

Every original Terminal byte remains an identical prefix, and every other
original source file is checked byte-for-byte after copying. `prefix.json`
records the full source tree hash, original Terminal size and digest, and
exact appended suffix. The original Terminal file is 32,465 bytes with SHA256
`fbcff2eecf1d16bd632813ad99d78a44dd9560e88d059d6bbe71b825c852a38c`;
the pinned source tree hash is
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
The appended helper exposes the body within its own source namespace. No
original declarations or statements are changed. The unchanged locked uucode
package is verified and its tables are regenerated through `source_build.py`.

The V consumer is `probe.v`, copied into an isolated module snapshot as
`vaxis/private_run_reference_test.v`. It calls the module-private V method
directly; no public V API is added. `-keepc` retains the compiled test executable
after V automatically runs its empty-environment test. The actual comparison
then supplies a corpus through `WITTY_TERMINAL_PRIVATE_CORPUS`.

Run from the repository root with the pinned tools:

```sh
python3 vaxis/verify_terminal_private_run_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_terminal_private_run_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod --zig-mode ReleaseSafe
```

Both Debug and V production/Zig ReleaseSafe pass 1,767 returning records,
ten checked trap pairs, one inherited-loop timeout pair, and the ordinary
private-access rejection pair. Returning-record SHA256 is
`e7dc5af0356c8a4f074b5b94114cb70addee9c1fc5c638d9d40c2ebd5ab43b0b`.

The 1,767 returning inputs stay below the queue's 16-event capacity. They cover
all C0 controls and CSI final bytes; cursor movement and scrolling; erasure,
tab stops, modes, SGR, cursor shapes, device/status replies; escape/SS2/SS3/APC
and skipped control strings; valid and malformed print bytes; OSC title updates
and percent-decoded working directories; truncated inputs, existing dirty
state, and the quit guard. Records include complete front/primary/alternate
screen cells, styles and cursor state, modes, tabs, title, working directory,
last-printed bytes, output bytes, ordered events, dirty/quit flags, EOF/error
results, the physical input-file position, and released back-mutex state.

Ten isolated source/V checked traps cover u16/u8 parameter overflow, an invalid
cursor shape, truncated percent escapes, back-tab arithmetic, erase bounds,
relative-position and reply arithmetic, and malformed grapheme-start arithmetic.
The runner checks the expected category in an actual native or V panic-header
line, rejects ordinary returns and `UNEXPECTED:` diagnostic lines, and keeps
these cases outside the returning
corpus. One separate one-second timeout pair preserves the inherited
`insertLine` loop when the cursor is at the bottom and its adjusted insertion
count becomes zero. A paired ordinary compile probe verifies that external
consumers still cannot call the original private `run` declaration.

The manually initialized terminals use ordinary streaming input/output files,
valid seeded screens, zero scrollback, initialized cursor URI lists, and
128-byte title/directory capacity. The capacity keeps queued borrowed bytes
defined across the repeated updates being measured. GC ownership, allocator
failure, PTY/process/thread lifecycle, racing consumers, queue saturation,
borrowed data after reallocation, and log presentation are separate adaptation
or validation scopes. This fixture proves execution of the preserved private
body; it does not claim a new callable source public API.
