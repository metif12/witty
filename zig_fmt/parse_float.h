#ifndef WITTY_ZIG_FMT_PARSE_FLOAT_H
#define WITTY_ZIG_FMT_PARSE_FLOAT_H

#include <locale.h>
#include <stdlib.h>
#if defined(__APPLE__)
#include <xlocale.h>
#endif

static inline int witty_zig_strtod(const char *text, char **end, double *value) {
    locale_t locale = newlocale(LC_NUMERIC_MASK, "C", (locale_t)0);
    if (locale == (locale_t)0) return 0;
    *value = strtod_l(text, end, locale);
    freelocale(locale);
    return 1;
}

static inline int witty_zig_strtof(const char *text, char **end, float *value) {
    locale_t locale = newlocale(LC_NUMERIC_MASK, "C", (locale_t)0);
    if (locale == (locale_t)0) return 0;
    *value = strtof_l(text, end, locale);
    freelocale(locale);
    return 1;
}

#endif
