# Public Screen cell comparison

`verify_screen_cells_reference.py` calls unchanged pinned `Screen.init`, `writeCell`, `readCell` and `clear`, and observes default construction. Both probes call public deinit after observation; Source freed buffers are not observed. The V consumer separately checks managed storage cleanup. The verifier hashes the complete Source `src` tree and the locked uucode package before copying them and generating the original dependency tables with `widgets_classic/source_build.py`. No Source body or visibility is modified.

From the repository root:

```sh
python3 vaxis/verify_screen_cells_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_screen_cells_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

The ordinary run uses native Debug; `--v-prod` uses native ReleaseSafe unless `--zig-mode` explicitly overrides it. `--timeout` is a positive returning-run deadline. Each record compares all backing cells, screen dimensions and metadata, optional read values, and state after backing-byte mutation and clear. Cell observations include text, borrowed addresses relative to the caller buffer, width, style, hyperlinks, image placement/options, packed scale, default and wrapped flags. Clearing an oversized backing buffer is observed independently of logical dimensions. Small and zero-area allocations cover creation; manually seeded buffers exercise dimensions up to 65,535 without giant allocations.

Strict isolated short-buffer assertions cover both public cell methods, including valid logical coordinates whose index exceeds signed 32-bit range. A trap requires nonzero exit, no ordinary stdout, an anchored panic header with the expected category, and no `UNEXPECTED` marker. Core dumps are disabled.

Final Debug/ordinary and ReleaseSafe/production results: **7,088 returning records and 12 strict isolated traps**, SHA256 `56a76ac5d4b010ce3cef8fa8f65b5ca92e30d99c440b5432027fac6bd46d983a`. Four focused consumer tests pass in both V modes.

Limits: V uses managed storage in place of caller allocators, and array allocation/index representation is `int` sized. The comparison does not claim allocation-failure parity or attempt a multi-billion-cell allocation. It proves checked indexing before narrowing using tiny backing arrays. Source post-deinit borrowed buffers are dangling; V deinit empties managed storage and that post-state is a language adaptation. This proof covers Screen cell APIs, not the complete Window or terminal renderer.
