# Bundled libintl provenance

Source: gettext 0.24, unchanged C and header files from `gettext-runtime/intl`.
Upstream URL: https://deps.files.ghostty.org/gettext-0.24.tar.gz
Archive SHA256: `c918503d593d70daf4844d175a13d816afacb667c06fba1ec9dcd5002c1518b7`.
Zig package hash: `N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-`.

`config.h`, `libintl.h`, and `libgnuintl.h` are unchanged Ghostty
`pkg/libintl` files from `6c0e02d1138d5376e4ac2f5e311b225494514a97`.
`native_libintl/builder.v` translates that package's selected source list and defines.
Ghostty builds this bundled package only for Darwin. Other supported targets
provide gettext through the same system library selected by Ghostty.

These C sources retain their individual license notices; see COPYING.LIB.
