# App public record contracts

This compares the public `vxfw.App.Options` / V `AppOptions` and the four
represented `App` fields: `tty`, `vx`, `timers`, and `wants_focus`. Source fields
are externally mutable and have no constructor defaults. V now exposes them as
required mutable fields; options retain the mutable `framerate = 60` default.
`App.init` supplies empty timers and no pending focus explicitly, preserving
Vaxis initialization before TTY initialization and the enabled clipboard / five
Kitty flags selected by the source.

The runner hashes the complete pinned `src` before copying it unchanged. It uses
the unchanged module graph and locked Unicode table generator from
[`source_build.py`](../widgets_classic/source_build.py):

- Vaxis tree: `bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`
- `vxfw/App.zig`: `24d8515dd780f83a075c61435891a50fe7672ab337062725203639eb7b4837b6`
- Locked uucode: `2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`

Source Debug / V ordinary and Source ReleaseSafe / V production both match the
same 5,377 returning records and hash. The batched public consumer checks all 256
framerates, default and copied options, Vaxis width/Kitty/clipboard projections,
empty and populated timer lists, extreme signed deadlines, pending-focus
replacement, and copied timer headers sharing the original item storage.
Changing a copied timer item affects the original item; shortening the copied
header leaves the original length intact. Pending-focus and represented Vaxis
scalar changes remain separate after a value copy. The source consumer uses
fixed local timer storage and does not append or free through a copied list.

Two complete constructor types are compiled together in this consumer. Four
plain-App omissions must produce ordinary compiler errors independently.
Source allocator/buffer omissions are two additional source-only rejections,
and accessing these absent fields in V produces two ordinary V rejections.
The pinned V type checker accepts a struct alias that omits `timers`, whereas the
source alias rejects it. This is one measured asymmetric required-marker
boundary, excluded from paired constructor parity.

The source allocator has no V field because the translation uses GC. The
source's `[1024]u8` buffer is borrowed by its buffered TTY writer; V's native TTY
adapter writes strings directly and has no caller-owned writer buffer. This
proof initializes source TTY, previous-screen, and buffer storage as undefined
and never reads them. V initializes a native Vaxis template for its internal
handles, observes only the listed scalar fields, and releases that template
once. The source TTY can be publicly assigned; its internal descriptor state
and copy ownership are not projected. No equivalence of allocators, allocation
failure/cleanup, arena ownership, synchronization handles, TTY buffer lifetime,
or copied terminal-resource ownership is claimed. `App.init` / `run` terminal
runtime behavior belongs to the separate App runtime proof.
V `App.init` retains its heap pointer result, while source `init` returns an App
value; this constructor proof does not assert identical object addresses or
return-value storage.

Reproduce from the repository root:

```sh
VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v V_C_ERROR_BUG_REPORT_DISABLED=1 \
python3 vaxis/verify_app_contracts_reference.py \
  /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
```

Add `--v-prod` to select V production and Source ReleaseSafe automatically.
`--zig-mode` can override the source mode. `--workdir` retains commands,
unchanged copied source/dependencies, compiler diagnostics, and consumer output.
Positive constructors share one emitted consumer per language; each rejection
uses a source compile-only build or V `-check` without repeated production C
compilation. Native probes select macOS ARM64 14 and libc. Their returning
SHA-256, excluding the final output newline, is
`4f65eaf15452bc86bc3df2276c3007e1a50a55d192d98022bb9c5055d7512270`.
