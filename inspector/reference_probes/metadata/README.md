# Native metadata type probe

`reference.zig` imports the unchanged pinned Ghostty `terminal/osc.zig`.
Copy it into the root of a temporary copy of Ghostty's `src` tree, then run
Zig 0.15.2 with `terminal_options` and `build_options` modules defining
`c_abi = false` and `simd = false` (native macOS: `-target aarch64-macos.14.0 -lc`).
The probe printed:

```
requests=segmented_list.SegmentedList(terminal.osc.parsers.color.Request,2)
list=array_list.Aligned(terminal.kitty.color.OSC.Request,null)
```

V stores those containers as arrays; inspector metadata retains the original
container type names rather than replacing them with counts. Command/field
selection uses V's compile-time sum-type/field reflection. Optional primitive
specializations avoid V 0.5.2's reuse of an option temporary across generic
instantiations; they retain the source's null and unwrapped-value branches.
