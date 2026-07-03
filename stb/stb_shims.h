#ifndef WITTY_STB_SHIMS_H
#define WITTY_STB_SHIMS_H

// stb_image_resize implementation shim.
//
// The single-header stb_image_resize library requires the
// STB_IMAGE_RESIZE_IMPLEMENTATION macro to be defined in exactly one
// translation unit before the header is included, which emits the actual
// function bodies. V's `#define` directive is only permitted in `.c.v`
// files, so we do it here in a co-located C shim (matching the pattern used
// by the other C bindings in this project, e.g. freetype_shims.h).
//
// The header itself is vendored from ghostty (src/stb/stb_image_resize.h),
// which is the version whose public resize API ghostty binds against (see
// ghostty/src/stb/main.zig).

// ghostty builds stb without asserts (assert.h's assert() compiles to a
// no-op under NDEBUG in its release/library build). The default
// STBIR_ASSERT pulls in <assert.h> and aborts on internal invariant
// checks; make it a no-op here to match that build and avoid aborting the
// process on degenerate input.
#define STBIR_ASSERT(x) ((void)0)

#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize.h"

#endif
