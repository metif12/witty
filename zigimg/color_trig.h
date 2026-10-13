#ifndef WITTY_COLOR_TRIG_H
#define WITTY_COLOR_TRIG_H

#include <math.h>

/* Match the paired intrinsic selected by pinned Zig ReleaseSafe on Darwin.
 * The SDK wrapper handles the platform's two-float return ABI. */
static inline void witty_color_sincosf(float angle, float *sine, float *cosine) {
#if defined(__APPLE__) && defined(_VPROD)
    __sincosf(angle, sine, cosine);
#else
    *sine = sinf(angle);
    *cosine = cosf(angle);
#endif
}

#endif
