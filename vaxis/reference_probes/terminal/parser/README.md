# Classic Terminal Parser and ANSI reference consumers

`verify_terminal_parser_reference.py` verifies the complete pinned vaxis `src`
tree before copying it unchanged. The consumer enters that copied package at
its root and calls the original `widgets/terminal/Parser.zig` and `ansi.zig`;
no dependency bodies are rewritten. These imports need only the pinned Zig
standard library, so no Unicode dependency regeneration is involved.

Run from the repository root with the pinned tools:

```sh
python3 vaxis/verify_terminal_parser_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_terminal_parser_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod --zig-mode ReleaseSafe
```

The 140,489 returning records cover every single-byte and two-byte input,
all C0 and escape families, intermediate/private-marker replacement, skipped
control strings, OSC/APC terminators, raw malformed UTF8, truncation, pending
bytes, ten streaming-file buffer sizes, and borrowed event-buffer reuse. Each
parse records its event or error, logical reader position, buffered length,
pending byte, and parser bytes. The source's skipped DCS/SOS/PM strings consume
the ESC delimiter only; the byte following it becomes the next input. OSC/APC
instead discard one following byte and propagate an EOF error if it is absent.
Their streaming discard does not prefetch subsequent text. Ground parsing
joins only already-buffered codepoints and accepts raw continuation bytes.

ANSI records cover all final byte values, present/absent optional fields,
embedded NUL and high bytes, matching predicates, and short fixed-writer
capacities with existing bytes. Iterator records cover the translated native
integer types, a V `u16` alias, empty/invalid parameters, caller-set indexes,
subparameter flags, and lookahead. Lookahead restores only the index, including
the source's flag changes and its consumption attempt when the requested count
is zero. Sixteen isolated checked arithmetic traps exercise multiplication and
addition overflow, both directly and through lookahead; successful return,
unexpected errors, and compiler crashes are rejected by the runner.

Five ordinary compile boundaries are paired: calling `next()` for `i8`, `f32`,
or `bool`, and constructing CSI without its required final or parameter field.
The source's runtime `u8` digit cannot coerce to `i8` or `f32`, and `bool` cannot
initialize its numeric accumulator. A sixth constructor probe measures a
separate compiler limitation: the source rejects `ParamIterator(u16){}` without
`bytes`, while pinned V accepts `TerminalParamIterator[u16]{}` despite the
field's `@[required]` annotation. This case is counted separately and never
claimed as paired rejection.

The V names flatten the private source Event variants into public sum-type
wrappers, and `[]u8` represents source borrowed byte slices. Event storage is
reused by the next parse call, as in the source. GC arrays replace the parser's
managed allocation; an empty default V parser is a convenience for that memory
representation. Allocator exhaustion, arbitrary Zig integer bit widths,
custom writer types, and invalid enum casts are outside the returning parity
corpus. This runner does not test the Terminal core or screen; their probes
are separate checkpoints.
