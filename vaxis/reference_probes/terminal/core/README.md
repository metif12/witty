# Classic Terminal public core and lifecycle comparison

The runner compares the pinned classic Vaxis Terminal's public controls, drawing,
key input, writer borrowing, and native cleanup. It copies the dependency without
changing any source bytes. The full Vaxis and uucode trees are checked against the
recorded hashes in `widgets_classic/source_build.py`.

Run:

```sh
python3 vaxis/verify_terminal_core_reference.py VAXIS_SOURCE UUCODE_SOURCE ZIG V
python3 vaxis/verify_terminal_core_reference.py VAXIS_SOURCE UUCODE_SOURCE ZIG V \
  --v-prod --zig-mode ReleaseSafe
```

Debug and V production/Zig ReleaseSafe match 12,394 returning records and five isolated checked traps. Its output
SHA-256 is `6be3faff0915dedb07e6d0d65983f526a2b2a5d283d66fb6b9d2647359c2143e`.
The original 12,390-record prefix is unchanged, with hash
`4674cdf033bf50da74e90e236d3580ce17134705fd61452946888eb98af73286`.

Returning cases cover mode changes, origin-dependent carriage returns, forward
and backward tabs, sync mode and lock contention during drawing, window clipping,
wide cells, cursor state, key writer buffer sizes and flush ordering, borrowed
writer access, closing both PTY descriptors, and null or nonexistent process IDs.
Terminal deinitialization retains the source's event queue.

The traps preserve the source's primary-screen-to-short-front-screen copy failure,
back-tab subtraction, empty back-tab list, zero-width forward tab, and unsupported
Kitty press. Traps require a panic/assertion diagnostic and reject explicit
`UNEXPECTED:` result markers. Core dumps are disabled.

Six lifecycle consumers ordinarily fail to compile in the original source and V
on macOS: PTY construction and resize, Command spawning, and Terminal construction,
spawning, and resize. All six unchanged-source consumers compile for
`aarch64-linux-gnu` in the source's default libc-disabled configuration; the V
Linux consumers pass compiler checks. Linux PTY/process/thread behavior is
translated and source-reviewed, but is not runtime-compared on this macOS host.
Fourteen source-required field omissions produce ordinary compiler errors in
both languages, while three complete constructor consumers compile in Debug and
production. The allocator field is omitted through the GC adaptation.

The libc-enabled source PTY constructor has a separate inherited ioctl type error;
this runner uses the source's default configuration.

`Terminal`, `TerminalPty`, and `TerminalCommand` flatten the classic package.
Allocator parameters become GC-owned arrays and strings; descriptors still require
explicit deinitialization. Source globals are accessed through
`terminal_global_state()`, and its `count` retains the source registry's copied-map
header count behavior. Native threads use a pthread handle adapter; source error
and ordering rules remain explicit. The source's default scrollback can make its
initial primary-to-front copy trap, and this port preserves that behavior.

Private `run`, CSI, OSC, and C0 bodies are translated and source-reviewed; the
public API matrix does not claim to execute them. The separate `private_run`
fixture documents any comparison through an appended visibility wrapper while
retaining every original dependency byte. Port-only focused tests check queue
borrowing, malformed UTF-8 printing, and writer borrowing.
The focused core test file is POSIX-only because it also consumes Command's
POSIX process-kill API; the standalone screen/parser tests compile for Windows.

The separate Debug `--registry-only` fixture measures three registry states before
and after removing two registered dummy terminals. The source map's copied header
continues to report count 2 while iteration finds 2, 1, and 0 live entries. The V
adapter reports the same source count through `globals.count`, while its ordinary
`globals.vts.len` reports the live entries. Both registries remain present after
the second removal. The extension's output SHA-256 is
`fffc0c277b830839c956ad90dff7fef86557ecb03194fffd50b602ac9ef928fb`;
it is separate from the established returning corpus and was run in Debug.
