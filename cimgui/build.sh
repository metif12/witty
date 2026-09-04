#!/bin/sh
set -eu

witty_cimgui_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
witty_cimgui_build=$(mktemp -d "${TMPDIR:-/tmp}/witty-cimgui.XXXXXX")
trap 'rm -rf "$witty_cimgui_build"' EXIT HUP INT TERM

witty_cimgui_cxx=${CXX:-clang++}
witty_cimgui_ar=${AR:-ar}
witty_cimgui_system=$(uname -s)
witty_cimgui_imgui="$witty_cimgui_root/vendor/imgui"
witty_cimgui_bindings="$witty_cimgui_root/vendor/dear_bindings"

case "$witty_cimgui_system" in
    Darwin)
        witty_cimgui_platform=darwin
        witty_cimgui_freetype_flags="-I/opt/homebrew/include/freetype2"
        witty_cimgui_extra_sources="$witty_cimgui_root/metal_backend.mm $witty_cimgui_root/metal_bridge.mm"
        ;;
    Linux)
        witty_cimgui_platform=linux
        witty_cimgui_freetype_flags=$(pkg-config --cflags freetype2)
        witty_cimgui_extra_sources="$witty_cimgui_imgui/backends/imgui_impl_opengl3.cpp"
        ;;
    *)
        echo "unsupported platform: $witty_cimgui_system" >&2
        exit 1
        ;;
esac

witty_cimgui_sources="
$witty_cimgui_imgui/imgui.cpp
$witty_cimgui_imgui/imgui_draw.cpp
$witty_cimgui_imgui/imgui_tables.cpp
$witty_cimgui_imgui/imgui_widgets.cpp
$witty_cimgui_imgui/imgui_demo.cpp
$witty_cimgui_imgui/misc/freetype/imgui_freetype.cpp
$witty_cimgui_bindings/dcimgui.cpp
$witty_cimgui_bindings/dcimgui_internal.cpp
$witty_cimgui_root/ext.cpp
$witty_cimgui_extra_sources
"

for witty_cimgui_source in $witty_cimgui_sources; do
    witty_cimgui_object="$witty_cimgui_build/$(basename "$witty_cimgui_source").o"
    "$witty_cimgui_cxx" \
        -std=c++17 \
        -Os \
        -fPIC \
        -Wno-macro-redefined \
        -DIMGUI_HAS_DOCK=1 \
        -DIMGUI_USE_WCHAR32=1 \
        -DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1 \
        -DIMGUI_ENABLE_FREETYPE=1 \
        -I"$witty_cimgui_imgui" \
        -I"$witty_cimgui_imgui/backends" \
        -I"$witty_cimgui_bindings" \
        $witty_cimgui_freetype_flags \
        -c "$witty_cimgui_source" \
        -o "$witty_cimgui_object"
done

mkdir -p "$witty_cimgui_root/lib"
witty_cimgui_output="$witty_cimgui_root/lib/libdcimgui_${witty_cimgui_platform}.a"
ZERO_AR_DATE=1 "$witty_cimgui_ar" rcs "$witty_cimgui_output" "$witty_cimgui_build"/*.o
echo "$witty_cimgui_output"
