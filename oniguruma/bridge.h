#ifndef WITTY_ONIGURUMA_BRIDGE_H
#define WITTY_ONIGURUMA_BRIDGE_H

#include <stddef.h>
#include <oniguruma.h>

enum { WITTY_ONIG_ENCODING_COUNT = 31 };

static inline OnigEncoding witty_onig_encoding(int value) {
    switch (value) {
    case 0: return ONIG_ENCODING_ASCII;
    case 1: return ONIG_ENCODING_ISO_8859_1;
    case 2: return ONIG_ENCODING_ISO_8859_2;
    case 3: return ONIG_ENCODING_ISO_8859_3;
    case 4: return ONIG_ENCODING_ISO_8859_4;
    case 5: return ONIG_ENCODING_ISO_8859_5;
    case 6: return ONIG_ENCODING_ISO_8859_6;
    case 7: return ONIG_ENCODING_ISO_8859_7;
    case 8: return ONIG_ENCODING_ISO_8859_8;
    case 9: return ONIG_ENCODING_ISO_8859_9;
    case 10: return ONIG_ENCODING_ISO_8859_10;
    case 11: return ONIG_ENCODING_ISO_8859_11;
    case 12: return ONIG_ENCODING_ISO_8859_13;
    case 13: return ONIG_ENCODING_ISO_8859_14;
    case 14: return ONIG_ENCODING_ISO_8859_15;
    case 15: return ONIG_ENCODING_ISO_8859_16;
    case 16: return ONIG_ENCODING_UTF8;
    case 17: return ONIG_ENCODING_UTF16_BE;
    case 18: return ONIG_ENCODING_UTF16_LE;
    case 19: return ONIG_ENCODING_UTF32_BE;
    case 20: return ONIG_ENCODING_UTF32_LE;
    case 21: return ONIG_ENCODING_EUC_JP;
    case 22: return ONIG_ENCODING_EUC_TW;
    case 23: return ONIG_ENCODING_EUC_KR;
    case 24: return ONIG_ENCODING_EUC_CN;
    case 25: return ONIG_ENCODING_SJIS;
    // Ghostty's bundled build also omits koi8.c. The public value remains in
    // Encoding for API parity, but cannot be initialized by that library.
    case 26: return NULL;
    case 27: return ONIG_ENCODING_KOI8_R;
    case 28: return ONIG_ENCODING_CP1251;
    case 29: return ONIG_ENCODING_BIG5;
    case 30: return ONIG_ENCODING_GB18030;
    default: return NULL;
    }
}

static inline OnigSyntaxType *witty_onig_syntax(int value) {
    switch (value) {
    case 0: return ONIG_SYNTAX_ONIGURUMA;
    case 1: return ONIG_SYNTAX_ASIS;
    case 2: return ONIG_SYNTAX_POSIX_BASIC;
    case 3: return ONIG_SYNTAX_POSIX_EXTENDED;
    case 4: return ONIG_SYNTAX_EMACS;
    case 5: return ONIG_SYNTAX_GREP;
    case 6: return ONIG_SYNTAX_GNU_REGEX;
    case 7: return ONIG_SYNTAX_JAVA;
    case 8: return ONIG_SYNTAX_PERL;
    case 9: return ONIG_SYNTAX_PERL_NG;
    case 10: return ONIG_SYNTAX_RUBY;
    case 11: return ONIG_SYNTAX_ONIGURUMA;
    default: return NULL;
    }
}

static inline int witty_onig_initialize(const int *encoding_ids, size_t count) {
    OnigEncoding encodings[WITTY_ONIG_ENCODING_COUNT];
    size_t i;
    if (count > WITTY_ONIG_ENCODING_COUNT) return ONIGERR_INVALID_ARGUMENT;
    for (i = 0; i < count; ++i) {
        encodings[i] = witty_onig_encoding(encoding_ids[i]);
        if (encodings[i] == NULL) return ONIGERR_INVALID_ARGUMENT;
    }
    return onig_initialize(count == 0 ? NULL : encodings, (int)count);
}

static inline int witty_onig_new(
    void **out,
    const unsigned char *pattern,
    size_t pattern_len,
    unsigned int options,
    int encoding_id,
    int syntax_id,
    void **error_par,
    void **error_par_end,
    unsigned char *error_message
) {
    OnigEncoding encoding = witty_onig_encoding(encoding_id);
    OnigSyntaxType *syntax = witty_onig_syntax(syntax_id);
    OnigRegex regex = NULL;
    OnigErrorInfo info = {0};
    int result;
    if (encoding == NULL || syntax == NULL) return ONIGERR_INVALID_ARGUMENT;
    result = onig_new(
        &regex,
        pattern,
        pattern + pattern_len,
        options,
        encoding,
        syntax,
        &info
    );
    if (result < 0) {
        if (error_par != NULL) *error_par = info.par;
        if (error_par_end != NULL) *error_par_end = info.par_end;
        if (error_message != NULL) onig_error_code_to_str(error_message, result, &info);
    }
    *out = regex;
    return result;
}

static inline int witty_onig_error_string(unsigned char *error_message, int code) {
    return onig_error_code_to_str(error_message, code);
}

static inline int witty_onig_search(
    void *regex,
    const unsigned char *string,
    size_t string_len,
    size_t start,
    size_t end,
    void *region,
    unsigned int options
) {
    return onig_search(
        (OnigRegex)regex,
        string,
        string + string_len,
        string + start,
        string + end,
        (OnigRegion *)region,
        options
    );
}

static inline int witty_onig_region_count(const void *region) {
    return ((const OnigRegion *)region)->num_regs;
}

static inline int witty_onig_region_start(const void *region, int index) {
    return ((const OnigRegion *)region)->beg[index];
}

static inline int witty_onig_region_end(const void *region, int index) {
    return ((const OnigRegion *)region)->end[index];
}

#endif
