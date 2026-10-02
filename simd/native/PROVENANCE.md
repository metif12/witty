The files in `simd/` are unchanged from Ghostty commit
`6c0e02d1138d5376e4ac2f5e311b225494514a97`, `src/simd/`.

`simdutf/simdutf.{h,cpp}` are unchanged from that checkout's
`pkg/simdutf/vendor/` (5.2.8).

Highway is the exact dependency archive in `pkg/highway/build.zig.zon`:
https://deps.files.ghostty.org/highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz
with Zig content hash `N-V-__8AAGmZhABbsPJLfbqrh6JTHsXhY6qCaLAQyx25e0XE`.
Headers and library sources are reused unchanged; upstream tests/contrib files
are not needed to build the native library. The small `.cpp` include adapters
let V's object builder compile the package's original `.cc` sources.

`utfcpp/source/` is the unchanged 4.0.5 dependency from
`pkg/utfcpp/build.zig.zon`, with its upstream license. The locked archive
has Zig content hash `N-V-__8AAHffAgDU0YQmynL8K35WzkcnMUmBVQHQ0jlcKpjH`.

Native builds select the original optimized entry points. `-d no_simd` selects
the translated scalar fallback, as does the source Wasm configuration.
