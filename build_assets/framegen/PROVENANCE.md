`main.c` and all 235 `frames` files are reused byte-for-byte from
`src/build/framegen` at Ghostty commit
`6c0e02d1138d5376e4ac2f5e311b225494514a97`.

`build_support/frame_data.v` translates `GhosttyFrameData.zig`: the generator
uses the host target and locked ReleaseFast zlib, and its output is reused in
source archives and the `+boo` compilation. These files do not contain a new
compression algorithm.
