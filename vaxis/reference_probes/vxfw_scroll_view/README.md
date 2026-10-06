# vxfw ScrollView source comparison

`../../verify_scroll_view_reference.py` builds the original public ScrollView,
Builder and scroll methods on native macOS. The scroll type is private, but its
public methods are callable through the public `ScrollView.scroll` field. There
are no appended helpers or edits to dependency bodies.

The runner verifies the complete pinned Vaxis source tree SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` before copying it.
The original `src/vxfw/ScrollView.zig` SHA256 is
`adc7f6aaac90a6c9e58358823c9bef9979b4ef9443075bf40f834567537887dc`.
The shared `widgets_classic/source_build.py` verifies the locked uucode package
SHA256 `2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`
and runs its unchanged generators. The native target is
`aarch64-macos.14.0`, Zig 0.15.2, with libc.

Run from the repository root:

```sh
python3 vaxis/verify_scroll_view_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_scroll_view_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

The default comparison is Zig Debug/V ordinary; `--v-prod` selects Zig
ReleaseSafe/V production unless `--zig-mode` explicitly overrides it. The V
runner sets `VEXE` to the selected compiler so the standard library resolves to
that compiler's installation.

The corpus contains 14,353 returning records. It compares final state, event
flags and commands, builder/draw callback ordering and visible state, child
constraints, errors, recursive surface placement, cursor cells and widget
identity. It covers variable and zero heights, known/unknown item counts,
slice/builder sources, sparse builders, callbacks replacing the source or
mutating scrolling state and later children, all recognized key/mouse events,
ignored events, draw/navigation sequences, saturation, the original i17/u32
limits and maximum cursor indexes. Four focused V consumer tests exercise the
same meaningful ownership, error and overflow-short-circuit boundaries.

There are 22 isolated trap pairs, two one-second inherited navigation-loop
pairs, four ordinary missing-constructor/payload rejection pairs and complete
constructors. Trap checks require a nonzero exit, no stdout, the actual native
or V panic header with the expected category, and no actual `UNEXPECTED:`
diagnostic line. Incidental backtrace source text cannot satisfy a trap. Source
assertions map to V's `Assertion failed`; signed destination casts have separate
native/V message categories.

The V `vertical_offset` and `pending_lines` fields use i32 storage for Source
i17. Two constructor probes separately measure Source ordinary rejections and
V acceptance of out-of-domain constants; they are not paired rejections or
runtime parity records. All returning inputs stay within the original i17
domain, and translated arithmetic checks the original range even in production.
Allocator values are represented by V-managed storage; actual allocator
failures cannot be simulated by that storage. Child callback allocator errors
are compared, including mutation and cleanup ordering.

One Source branch calls `child_list.deinit` and then appends to the list's
undefined state when keeping an oversized cursor child. It is observed
separately and excluded from returning and trap parity. The existing V adapter
replaces the children array safely in that branch. The two missing-index-zero
builder navigation loops remain inherited behavior. The source's computed
`start`/`end` indexes remain unused, and the repeated offset assignment after
upward insertion is preserved.

Returning-output SHA256 (joined records, no final newline):
`013c5025c4b6192747e19df33a046090b3d0e2781f33f7a70d8824571a05625f`.

Both Debug/V ordinary and ReleaseSafe/V production pass with this hash and all
the counts above. The two i17 constructor adaptations were checked separately
in both modes. The excluded deinit-then-append observation aborts with no stdout
in both native modes; its failure category is not a parity requirement.
