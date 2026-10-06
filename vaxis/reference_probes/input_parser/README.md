This comparison calls the pinned input `Parser.parse` directly. It does not expose
private source helpers or change dependency statements. It covers the input parser
in `src/Parser.zig`, distinct from the classic Terminal widget's parser.

Run from the repository root:

```sh
python3 vaxis/verify_input_parser_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
```

Add `--v-prod` to compare Zig ReleaseSafe with V production. `--workdir PATH`
retains binaries, compiler arguments, source copies, metadata, case inputs,
returning outputs, trap diagnostics and constructor diagnostics. `--timeout`
sets the returning producer deadline. Core dumps are disabled. The runner sets
`VEXE` and uses the unchanged module graph and generated locked uucode tables from
`../widgets_classic/source_build.py`.

The source tree SHA256 is
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`;
the locked uucode tree SHA256 is
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
Both original and copied trees are checked before/after comparison. Metadata
records fixture digests and target/build modes.

Both Debug/ordinary and ReleaseSafe/production match **79,299 returning records**,
**19 strict trap pairs**, **one complete mutable/copy constructor** and **two
required Result-field omission pairs**, plus **one measured alias-marker
boundary**: the unchanged source rejects an empty alias of `Parser.Result`,
while the pinned V compiler accepts an empty `ParserResult` alias because it
drops inherited required markers. This is separate from the paired direct-field
constructor proof. The returning SHA256, over source rows
joined by a newline without a trailing newline, is
`526ddb882d3040c927af9264ffe7ce70cfe5e33fa269ef9f224a6b3b0d2e0502`.

Returning cases include every one- and two-byte input, malformed/raw UTF-8,
SS3/APC/DCS/SOS/PM cutoffs, legacy and Kitty key fields, modifiers and releases,
exact-capacity codepoint text, invalid Unicode after prior scratch writes,
valid SGR/Xterm mouse values and leave precedence, resize/capability reports,
OSC colors and clipboard errors, and live input/scratch mutation. Every scratch
byte observed in the comparison is explicitly initialized. Public buffer writes
and by-value Parser/Result copies are exercised from external consumers.

Isolated traps preserve empty-input and DA1 assertions, truncated APC slice
bounds, four invalid SGR button values and an invalid Xterm button, three Xterm
byte underflows, two missing clipboard allocator cases, a short clipboard
payload slice, and five UTF-8 output-capacity failures. `utf8Encode` checks
capacity before rejecting a surrogate; a codepoint above Unicode's maximum
returns its error before the capacity check. The returning cases retain these
orders and partial scratch writes. Trap checks require a nonzero exit and the
expected category on a complete `thread N panic:` or `V panic:` header.
Trap stdout must be empty. Returned errors and successful returns produce
line-start `UNEXPECTED` markers and are rejected; quoted source lines in a native
backtrace are not interpreted as emitted fixture markers. Ordinary constructor rejections exclude compiler crashes and generated
C/backend failures.

Source assert headers use `reached unreachable code`; V records an explicit
assertion message. This is diagnostic mapping, not identical stack-trace output.
V's `InputEvent` sum carriers, `string` text, native-width fields for Zig packed
u21/u3 values, and GC ownership are representation adapters. Event values and
raw byte lengths are compared; no packed ABI, allocator/OOM, arbitrary alias
construction, or generated-C layout parity is claimed. V's `clipboard` boolean
represents presence of the source's optional allocator. Clipboard allocation is
owned by GC; ground text borrows input and CSI text borrows the live Parser buffer.
Source's default undefined buffer contents are excluded; V's zero initialization
is not a source byte-state guarantee. Private helpers remain private.
