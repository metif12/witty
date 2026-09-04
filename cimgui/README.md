# Pinned Dear ImGui dependency

These sources are the exact dependencies selected by Ghostty commit
`6c0e02d1138d5376e4ac2f5e311b225494514a97`:

- Dear ImGui `v1.92.5-docking`, source archive SHA-256
  `c816c20e8c75f3e15ae867350e79925502d1a6a85938bb1a73b8927e5f31f9cb`.
- Dear Bindings `v0.17` for ImGui `v1.92.5-docking`, Ghostty dependency
  archive SHA-256
  `8bfec500e00926f679853ee23d67cc392d3c3181733ca4704738651d3f70baa3`.
- `ext.cpp` is copied byte-for-byte from Ghostty's `pkg/dcimgui/ext.cpp` at
  the pinned commit.

`build.sh` reproduces Ghostty's dcimgui compile flags and source list, using
the Metal renderer backend on macOS and the OpenGL 3 renderer backend on
Linux. It writes a native static archive under `lib/`; rerun it when building
on a different architecture.

The checked-in macOS arm64 archive has SHA-256
`8e4a438f605ff75802029a31a7071773f75be528340d61ca8617f2682521cf8e`.
