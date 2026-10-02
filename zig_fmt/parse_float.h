#ifndef WITTY_ZIG_FMT_PARSE_FLOAT_H
#define WITTY_ZIG_FMT_PARSE_FLOAT_H

#include <locale.h>
#include <stdlib.h>
#if defined(__APPLE__)
#include <xlocale.h>
#endif

static inline int witty_zig_strtod(const char *text, char **end, double *value) {
#if defined(__EMSCRIPTEN__)
    /* Emscripten musl floatscan parses a literal decimal dot and does not
     * expose strtod_l/strtof_l; its unchanged parser is locale-independent. */
    *value = strtod(text, end);
#elif defined(_WIN32)
    _locale_t locale = _create_locale(LC_NUMERIC, "C");
    if (locale == (_locale_t)0) return 0;
    *value = _strtod_l(text, end, locale);
    _free_locale(locale);
#else
    locale_t locale = newlocale(LC_NUMERIC_MASK, "C", (locale_t)0);
    if (locale == (locale_t)0) return 0;
    *value = strtod_l(text, end, locale);
    freelocale(locale);
#endif
    return 1;
}

static inline int witty_zig_strtof(const char *text, char **end, float *value) {
#if defined(__EMSCRIPTEN__)
    *value = strtof(text, end);
#elif defined(_WIN32)
    _locale_t locale = _create_locale(LC_NUMERIC, "C");
    if (locale == (_locale_t)0) return 0;
    *value = _strtof_l(text, end, locale);
    _free_locale(locale);
#else
    locale_t locale = newlocale(LC_NUMERIC_MASK, "C", (locale_t)0);
    if (locale == (locale_t)0) return 0;
    *value = strtof_l(text, end, locale);
    freelocale(locale);
#endif
    return 1;
}

#endif
