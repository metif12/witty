The V probe uses the production streaming APIs. The Zig probe imports unchanged
`src/synthetic/{Bytes,Utf8,Osc,Generator}.zig` and their dependencies from the
pinned Ghostty checkout; copy/symlink that source tree into a temporary directory
and replace its `main.zig` with `reference.zig` to run it.

Run the native probe with Zig 0.15.2 and `-target aarch64-macos.14.0 -lc`; run the
V probe with the pinned V 0.5.2 compiler and a repository-first module path.
Compare 756 rows: three seeds, three generator types, and 84 caller capacities.
Each row records failure status, bytes written, and the next PRNG word, so the
comparison checks both partial output and random-consumption order.
