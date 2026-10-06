# Spinner source comparison

The runner hashes and copies the unchanged classic Vaxis source tree and its
locked Unicode dependency, using `widgets_classic/source_build.py`. Every public
`Spinner` method and its type-erased event/draw callbacks compile and run with
Zig 0.15.2 on the native ARM macOS host; no atomic API compatibility patch is
needed.

Both Source Debug/V ordinary and Source ReleaseSafe/V `-prod` match **15,183
returning records**, **six strict checked-trap pairs**, **one measured integer
representation boundary**, and **three source-only allocator-error cases**.
The returning-record SHA256 is
`91e0cf4dd5aee36836a99662a3271b4f9c38b8dfdbb044a88e193e69d1f74acc`.
Eight focused V consumers also pass in both modes.

```sh
python3 vaxis/verify_spinner_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_spinner_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

`--v-prod` selects Zig ReleaseSafe by default. `--workdir` retains builds, source
copies, input records, compiler arguments, outputs and diagnostics in a new
directory. Core dumps are disabled. Trap validation requires the actual panic
header and expected overflow/bounds category, and rejects returned errors or
`UNEXPECTED` markers on either output stream. The constructor measurement
requires an ordinary Source compiler diagnostic and separately builds/runs the
accepted V constructor.

Coverage includes all sixteen Source-valid mutable frame values; start's atomic
old-value test and u16 wraparound; stop's saturating load/subtract/store; direct
and erased callbacks; context flags/phases and an existing command prefix;
stopped ticks clearing remembered state exactly once; active ticks preserving
redraw while appending an 83ms rearm; frame cycling and 8–14 resetting to zero;
all draw glyphs; custom styles/default cell metadata; empty/max-zero constraints;
large valid surface dimensions; independent value copies; and four concurrent
start workers around count wraparound. Tick deadlines are compared against
before/after wall-clock brackets rather than absolute timestamps. Six traps
cover direct/erased u4 increments at 15, direct/erased out-of-range draw frames,
and Surface area overflow both while stopped and before an invalid frame read.

The V atomic fields are embedded so ordinary widget copies preserve independent
values, matching Source `std.atomic.Value`. Their V API is `load`, `store`, and
`add`, rather than Source `.raw` initializers and explicit memory-order arguments;
this is a representation/API adaptation, not an atomic ABI claim. Pinned V's
`stdatomic` uses sequentially consistent operations on this host, which are
stronger than Source unordered/monotonic operations. The deterministic concurrent
start results are compared; arbitrary concurrent interleavings are not claimed
to match. Source stop remains its original separate load and store, with no
new atomic read-modify-write semantics. Copy tests run without concurrent mutation.

Source frame is u4; V uses u8 and accepts an explicit `frame: 16` constructor that
Source ordinarily rejects. Returning comparisons use only Source-valid 0–15
states. Source checked increment and indexing traps remain explicit in V
production builds. GC replaces Source allocation: the three Source-only failing
allocator probes establish that frame 7 advances to 0 before a rearm allocation
error, whereas active and stopped draw allocation errors retain frame/count/
remembered state. V has no corresponding allocator-failure injection contract.
Source draw never clears remembered spinning state; it clears only on a stopped
tick, despite the original field comment describing draw.
