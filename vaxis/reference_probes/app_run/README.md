# Public framework App lifecycle comparison

`verify_app_run_reference.py` builds and runs the unchanged public
`vxfw.App.init`, `App.run`, and `App.deinit` APIs on an actual controlling macOS
PTY. The complete pinned Vaxis source tree is SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`; the locked
uucode package is
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
The runner uses `widgets_classic/source_build.py` to verify both trees and
reproduce the original module graph. It copies the dependency without changing
bodies or visibility. The paired programs are ordinary public consumers, not
private-method wrappers. The Source consumer selects the standard `.err` log
level; dependency logging statements remain unchanged.

Run from the repository root:

```sh
python3 vaxis/verify_app_run_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-app-run-debug

python3 vaxis/verify_app_run_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --workdir /tmp/witty-app-run-prod
```

Work directories must be new. The runner sets `VEXE`, disables core dumps,
targets `aarch64-macos.14.0`, and retains source copies, fixture copies, build
arguments, stdout callback traces, diagnostics, and raw terminal streams. The
default per-process deadline is 15 seconds and can be changed with `--timeout`.
Debug/V ordinary and ReleaseSafe/V production each pass **32 returning public
PTY traces** and **7 strict public trap pairs**. Returning serialized traces
have SHA256
`4947fb0e0877a64f4f62d3cf52b83d4833e0d1a2e4b5dcc8755678d3fcc4cc9e`.

## Returning behavior

Every process begins with an explicit canonical termios profile and controlled
cell/pixel dimensions. The first observation reads only initialized public
App state: all five Kitty flags, the enabled clipboard allocator/adapter,
empty timers, absent requested focus, and an initially empty screen. No bytes
of Source's undefined inline output buffer are read.

For run scenarios, the consumer then calls public `Vaxis.resize` with the actual
PTY dimensions. This initializes published screen dimensions before the input
thread starts. Source's initial winsize event is posted concurrently with init
and focus events; preinitializing the screen removes a scheduling-dependent
final-size difference when an early callback returns an error. The initial
App defaults remain separately observed. The input loop and its queued resize
event retain their original bodies and order.

The controller answers DA1 during terminal queries and DSR during loop shutdown.
It sends each key, mouse, focus, or resize input only after a relevant public
callback/draw observation. Returning traces compare:

- Init followed by focus, early quit, ordinary layout/render, and framerates
  0, 60, and 255, including the zero-rate fallback.
- Root/child capture, target, and bubbling phases; capture and target
  consumption; requested focus and subsequent focus-path rebuilding.
- Mouse enter/leave, translated local coordinates, press/release, focus loss,
  and in-band resize with updated draw constraints and cell pixel dimensions.
- Title, clipboard, notification, color query, mouse-shape, and refresh
  commands; command processing before quit and a second layout after refresh.
- Equal-deadline reverse dispatch, delayed handling of ticks scheduled from a
  tick callback, future-timer retention, and manually seeded public timer
  lists. `seed_unsorted` preserves Source's future-last blocking behavior;
  `seed_resort` proves adding a tick sorts the complete existing list.
- Callback errors from init, focus, draw, capture, key, tick, mouse enter,
  mouse target, and requested-focus in/out, including remaining timer and
  requested-focus state.

Every returning process calls public `deinit` and stays alive until the
controller verifies that all original termios fields and control characters
are restored. Error returns are observations, not panic substitutes. The draw
callback uses Source's permitted `error.OutOfMemory`; other callbacks use the
same explicit `ProbeFailure` domain error in both consumers.

## Checked failures

The isolated public traps are a requested widget without an event handler,
an inherited empty focus path after layout omits the focused widget, zero
screen width, zero screen height, an invalid nonempty surface buffer,
u16 surface-size multiplication overflow, and commands appended during layout.
For the last case, the init callback borrows the live EventContext pointer;
draw appends a command while that context is still alive. This reaches run's
post-layout command-empty assertion through public callbacks without accessing
private implementation methods.

Each pair requires a nonzero exit, the exact expected category on an actual
native/V panic header, identical callback output before failure, and no returned
`R|` observation, `DONE`, or fixture `UNEXPECTED` line. Assertions remain checked
in V production. The pre-layout command-empty assertion is retained by source
review; ordinary command handling clears that list before this point, so this
fixture does not claim a public runtime witness for that separate assertion.

## Output and representation limits

The stdout callback/state trace is the differential record. Each complete raw
terminal stream is also retained as `.tty`; `terminal-output.txt` records both
lengths and SHA256 values without removing or reordering bytes. Full output or
timing equivalence is not claimed: the initial queued resize can place its
screen-clear bytes before or after init commands, or remain unhandled when an
early callback fails.

`buffer_probe` separately holds a public focus callback after a direct public
TTY write. Source's 1024-byte App output buffer retains `buffered-proof`; V's
unbuffered writer has already emitted it. The controller captures the actual
PTY bytes in `.barrier` files before releasing the callback and requires this
difference. Source title/notification/query helpers flush their writers, so
their ordinary command writes are not used as a buffering witness. Output
buffer ownership, partial write timing, and arbitrarily large-buffer behavior
remain representation boundaries.

V uses a heap App pointer, GC-managed contexts/surfaces/command lists, and
platform mutexes/condition variables in place of Source's allocator-bearing
value records, arena resets, and futexes. Allocation-failure paths, explicit
allocator/free behavior, source pointer/value-copy ABI, negative or overflowing
wall-clock timestamps, exact frame deadlines, arbitrary concurrent public
state mutation, and other platforms are outside this native runtime matrix.
The public constructor proof records field, width, and copy boundaries
separately. This matrix does not turn any unsupported private access into a
public API claim.

The `seed_resort` regression also reproduced the previous V behavior in an
isolated module snapshot: Source dispatched nodes 1, 3, 2 while insertion of
only the newly appended timer dispatched 3, 2, 1. The final production adapter
sorts the complete list and matches unchanged Source in both comparison modes.
