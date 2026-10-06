This proof calls public `Tty.init`, `Tty.deinit`, its writer and window-size query
against the unchanged pinned source on a controlled **macOS PTY**. V uses
`Tty.new`, `deinit`, `write` and `get_winsize`. No source body or visibility is
changed. The source writer is initialized with a **zero-length output buffer**,
which is the shared unbuffered domain supported by the existing V Tty adapter.

Run from the repository root:

```sh
python3 vaxis/verify_tty_deinit_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
```

Add `--v-prod` for Zig ReleaseSafe versus V production. `--workdir PATH` retains
binaries, build arguments, pinned source copies, metadata, each case's raw
stdout/stderr/terminal bytes and original/final termios state. `--timeout` bounds
each PTY consumer. Core dumps are disabled. The runner sets `VEXE`, recreates the
unchanged module graph through `../widgets_classic/source_build.py`, and verifies
both dependency trees again after comparison.

Source tree SHA256:
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
Locked uucode tree SHA256:
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
Metadata records fixture digests, native target, both build modes and zero buffer
size.

Both Debug/ordinary and ReleaseSafe/production pass **40 public PTY records**.
The record+raw terminal output SHA256 is
`e07ae36d87128e0f3b4a1a18f47dede10a8083e6f5eab232f23d39649472f810`.
Cases use zero, one, two, three or eight deinitializations, optional termios
mutation between restorations, and four real terminal dimensions. The proof
checks initial raw mode, original-state restoration, successful writes and window
size queries after each deinit, and exact terminal bytes. Both fixtures propagate
post-deinit window-size errors; they cannot substitute earlier dimensions. Each
mode proves 112 successful post-deinit queries across the 40 cases. The master is drained
while the consumer runs because source `tcsetattr(.FLUSH)` waits for preceding
output. The consumer remains alive until the parent has observed the state;
closing the PTY before release avoids macOS exit-time `/dev/tty` close blocking.

The source deliberately leaves its descriptor open on macOS, so repeated deinit
still restores the saved original state and its writer remains usable. The V
macOS branch now retains that descriptor. Other POSIX branches retain their
existing close/invalidation adapter and are outside this native macOS proof.
The POSIX focused consumer `tty_posix_nix_test.v` also checks retained descriptor,
window-size queries and a second restoration when it runs in a real terminal.

The existing V Tty has unbuffered writes. Larger configurable source writer
buffers, buffering/timing parity, public fd/writer record layout and source
allocator APIs remain outside this proof. Successful write/state observations
are compared without normalizing terminal output. Errors, panic stacks and
signal-handler internals are not claimed identical. This checkpoint does not
install a panic hook or change recovery snapshot ownership.
