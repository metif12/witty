These source lists, pnglibconf.h, and override headers come unchanged from
Ghostty 6c0e02d1138d5376e4ac2f5e311b225494514a97 pkg/*/build.zig and pkg/*/override.

packages.json retains the exact upstream package URLs and Zig package hashes.
Each raw archive SHA-256 was recorded only after Zig 0.15.2 fetch verified the
archive's original package hash. The V builder verifies that raw checksum before
extracting it. Native package compile flags translate the corresponding pinned
pkg/{zlib,libpng,freetype,harfbuzz,oniguruma,libxml2,fontconfig}/build.zig decisions.
