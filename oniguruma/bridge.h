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
    void **error_par_end
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
    }
    *out = regex;
    return result;
}

static inline int witty_onig_error_string(unsigned char *error_message, int code) {
    return onig_error_code_to_str(error_message, code);
}

// The return values match ErrorKind in errors.v. This is the direct C-macro
// equivalent of pkg/oniguruma/errors.zig:error_code_map.
static inline int witty_onig_error_kind(int code) {
    if (code == ONIG_MISMATCH) return 1;
    if (code == ONIG_NO_SUPPORT_CONFIG) return 2;
    if (code == ONIG_ABORT) return 3;
    if (code == ONIGERR_MEMORY) return 4;
    if (code == ONIGERR_TYPE_BUG) return 5;
    if (code == ONIGERR_PARSER_BUG) return 6;
    if (code == ONIGERR_STACK_BUG) return 7;
    if (code == ONIGERR_UNDEFINED_BYTECODE) return 8;
    if (code == ONIGERR_UNEXPECTED_BYTECODE) return 9;
    if (code == ONIGERR_MATCH_STACK_LIMIT_OVER) return 10;
    if (code == ONIGERR_PARSE_DEPTH_LIMIT_OVER) return 11;
    if (code == ONIGERR_RETRY_LIMIT_IN_MATCH_OVER) return 12;
    if (code == ONIGERR_RETRY_LIMIT_IN_SEARCH_OVER) return 13;
    if (code == ONIGERR_SUBEXP_CALL_LIMIT_IN_SEARCH_OVER) return 14;
    if (code == ONIGERR_DEFAULT_ENCODING_IS_NOT_SET) return 15;
    if (code == ONIGERR_SPECIFIED_ENCODING_CANT_CONVERT_TO_WIDE_CHAR) return 16;
    if (code == ONIGERR_FAIL_TO_INITIALIZE) return 17;
    if (code == ONIGERR_INVALID_ARGUMENT) return 18;
    if (code == ONIGERR_END_PATTERN_AT_LEFT_BRACE) return 19;
    if (code == ONIGERR_END_PATTERN_AT_LEFT_BRACKET) return 20;
    if (code == ONIGERR_EMPTY_CHAR_CLASS) return 21;
    if (code == ONIGERR_PREMATURE_END_OF_CHAR_CLASS) return 22;
    if (code == ONIGERR_END_PATTERN_AT_ESCAPE) return 23;
    if (code == ONIGERR_END_PATTERN_AT_META) return 24;
    if (code == ONIGERR_END_PATTERN_AT_CONTROL) return 25;
    if (code == ONIGERR_META_CODE_SYNTAX) return 26;
    if (code == ONIGERR_CONTROL_CODE_SYNTAX) return 27;
    if (code == ONIGERR_CHAR_CLASS_VALUE_AT_END_OF_RANGE) return 28;
    if (code == ONIGERR_CHAR_CLASS_VALUE_AT_START_OF_RANGE) return 29;
    if (code == ONIGERR_UNMATCHED_RANGE_SPECIFIER_IN_CHAR_CLASS) return 30;
    if (code == ONIGERR_TARGET_OF_REPEAT_OPERATOR_NOT_SPECIFIED) return 31;
    if (code == ONIGERR_TARGET_OF_REPEAT_OPERATOR_INVALID) return 32;
    if (code == ONIGERR_NESTED_REPEAT_OPERATOR) return 33;
    if (code == ONIGERR_UNMATCHED_CLOSE_PARENTHESIS) return 34;
    if (code == ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS) return 35;
    if (code == ONIGERR_END_PATTERN_IN_GROUP) return 36;
    if (code == ONIGERR_UNDEFINED_GROUP_OPTION) return 37;
    if (code == ONIGERR_INVALID_GROUP_OPTION) return 38;
    if (code == ONIGERR_INVALID_POSIX_BRACKET_TYPE) return 39;
    if (code == ONIGERR_INVALID_LOOK_BEHIND_PATTERN) return 40;
    if (code == ONIGERR_INVALID_REPEAT_RANGE_PATTERN) return 41;
    if (code == ONIGERR_TOO_BIG_NUMBER) return 42;
    if (code == ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE) return 43;
    if (code == ONIGERR_UPPER_SMALLER_THAN_LOWER_IN_REPEAT_RANGE) return 44;
    if (code == ONIGERR_EMPTY_RANGE_IN_CHAR_CLASS) return 45;
    if (code == ONIGERR_MISMATCH_CODE_LENGTH_IN_CLASS_RANGE) return 46;
    if (code == ONIGERR_TOO_MANY_MULTI_BYTE_RANGES) return 47;
    if (code == ONIGERR_TOO_SHORT_MULTI_BYTE_STRING) return 48;
    if (code == ONIGERR_TOO_BIG_BACKREF_NUMBER) return 49;
    if (code == ONIGERR_INVALID_BACKREF) return 50;
    if (code == ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED) return 51;
    if (code == ONIGERR_TOO_MANY_CAPTURES) return 52;
    if (code == ONIGERR_TOO_LONG_WIDE_CHAR_VALUE) return 53;
    if (code == ONIGERR_UNDEFINED_OPERATOR) return 54;
    if (code == ONIGERR_EMPTY_GROUP_NAME) return 55;
    if (code == ONIGERR_INVALID_GROUP_NAME) return 56;
    if (code == ONIGERR_INVALID_CHAR_IN_GROUP_NAME) return 57;
    if (code == ONIGERR_UNDEFINED_NAME_REFERENCE) return 58;
    if (code == ONIGERR_UNDEFINED_GROUP_REFERENCE) return 59;
    if (code == ONIGERR_MULTIPLEX_DEFINED_NAME) return 60;
    if (code == ONIGERR_MULTIPLEX_DEFINITION_NAME_CALL) return 61;
    if (code == ONIGERR_NEVER_ENDING_RECURSION) return 62;
    if (code == ONIGERR_GROUP_NUMBER_OVER_FOR_CAPTURE_HISTORY) return 63;
    if (code == ONIGERR_INVALID_CHAR_PROPERTY_NAME) return 64;
    if (code == ONIGERR_INVALID_IF_ELSE_SYNTAX) return 65;
    if (code == ONIGERR_INVALID_ABSENT_GROUP_PATTERN) return 66;
    if (code == ONIGERR_INVALID_ABSENT_GROUP_GENERATOR_PATTERN) return 67;
    if (code == ONIGERR_INVALID_CALLOUT_PATTERN) return 68;
    if (code == ONIGERR_INVALID_CALLOUT_NAME) return 69;
    if (code == ONIGERR_UNDEFINED_CALLOUT_NAME) return 70;
    if (code == ONIGERR_INVALID_CALLOUT_BODY) return 71;
    if (code == ONIGERR_INVALID_CALLOUT_TAG_NAME) return 72;
    if (code == ONIGERR_INVALID_CALLOUT_ARG) return 73;
    if (code == ONIGERR_INVALID_CODE_POINT_VALUE) return 74;
    if (code == ONIGERR_INVALID_WIDE_CHAR_VALUE) return 75;
    if (code == ONIGERR_TOO_BIG_WIDE_CHAR_VALUE) return 76;
    if (code == ONIGERR_NOT_SUPPORTED_ENCODING_COMBINATION) return 77;
    if (code == ONIGERR_INVALID_COMBINATION_OF_OPTIONS) return 78;
    if (code == ONIGERR_TOO_MANY_USER_DEFINED_OBJECTS) return 79;
    if (code == ONIGERR_TOO_LONG_PROPERTY_NAME) return 80;
    if (code == ONIGERR_VERY_INEFFICIENT_PATTERN) return 81;
    if (code == ONIGERR_LIBRARY_IS_NOT_INITIALIZED) return 82;
    return 83;
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
