#ifndef WITTY_ONIGURUMA_BRIDGE_H
#define WITTY_ONIGURUMA_BRIDGE_H

#include <stddef.h>
#include <oniguruma.h>

#define WITTY_ONIG_GET_ENCODING(name, value) \
    static inline void *witty_onig_encoding_##name(void) { return (void *)(value); }

WITTY_ONIG_GET_ENCODING(ascii, ONIG_ENCODING_ASCII)
WITTY_ONIG_GET_ENCODING(iso_8859_1, ONIG_ENCODING_ISO_8859_1)
WITTY_ONIG_GET_ENCODING(iso_8859_2, ONIG_ENCODING_ISO_8859_2)
WITTY_ONIG_GET_ENCODING(iso_8859_3, ONIG_ENCODING_ISO_8859_3)
WITTY_ONIG_GET_ENCODING(iso_8859_4, ONIG_ENCODING_ISO_8859_4)
WITTY_ONIG_GET_ENCODING(iso_8859_5, ONIG_ENCODING_ISO_8859_5)
WITTY_ONIG_GET_ENCODING(iso_8859_6, ONIG_ENCODING_ISO_8859_6)
WITTY_ONIG_GET_ENCODING(iso_8859_7, ONIG_ENCODING_ISO_8859_7)
WITTY_ONIG_GET_ENCODING(iso_8859_8, ONIG_ENCODING_ISO_8859_8)
WITTY_ONIG_GET_ENCODING(iso_8859_9, ONIG_ENCODING_ISO_8859_9)
WITTY_ONIG_GET_ENCODING(iso_8859_10, ONIG_ENCODING_ISO_8859_10)
WITTY_ONIG_GET_ENCODING(iso_8859_11, ONIG_ENCODING_ISO_8859_11)
WITTY_ONIG_GET_ENCODING(iso_8859_13, ONIG_ENCODING_ISO_8859_13)
WITTY_ONIG_GET_ENCODING(iso_8859_14, ONIG_ENCODING_ISO_8859_14)
WITTY_ONIG_GET_ENCODING(iso_8859_15, ONIG_ENCODING_ISO_8859_15)
WITTY_ONIG_GET_ENCODING(iso_8859_16, ONIG_ENCODING_ISO_8859_16)
WITTY_ONIG_GET_ENCODING(utf8, ONIG_ENCODING_UTF8)
WITTY_ONIG_GET_ENCODING(utf16_be, ONIG_ENCODING_UTF16_BE)
WITTY_ONIG_GET_ENCODING(utf16_le, ONIG_ENCODING_UTF16_LE)
WITTY_ONIG_GET_ENCODING(utf32_be, ONIG_ENCODING_UTF32_BE)
WITTY_ONIG_GET_ENCODING(utf32_le, ONIG_ENCODING_UTF32_LE)
WITTY_ONIG_GET_ENCODING(euc_jp, ONIG_ENCODING_EUC_JP)
WITTY_ONIG_GET_ENCODING(euc_tw, ONIG_ENCODING_EUC_TW)
WITTY_ONIG_GET_ENCODING(euc_kr, ONIG_ENCODING_EUC_KR)
WITTY_ONIG_GET_ENCODING(euc_cn, ONIG_ENCODING_EUC_CN)
WITTY_ONIG_GET_ENCODING(sjis, ONIG_ENCODING_SJIS)
WITTY_ONIG_GET_ENCODING(koi8, ONIG_ENCODING_KOI8)
WITTY_ONIG_GET_ENCODING(koi8_r, ONIG_ENCODING_KOI8_R)
WITTY_ONIG_GET_ENCODING(cp1251, ONIG_ENCODING_CP1251)
WITTY_ONIG_GET_ENCODING(big5, ONIG_ENCODING_BIG5)
WITTY_ONIG_GET_ENCODING(gb18030, ONIG_ENCODING_GB18030)

#undef WITTY_ONIG_GET_ENCODING

#define WITTY_ONIG_GET_SYNTAX(name, value) \
    static inline void *witty_onig_syntax_##name(void) { return (void *)(value); }

WITTY_ONIG_GET_SYNTAX(default_, ONIG_SYNTAX_ONIGURUMA)
WITTY_ONIG_GET_SYNTAX(asis, ONIG_SYNTAX_ASIS)
WITTY_ONIG_GET_SYNTAX(posix_basic, ONIG_SYNTAX_POSIX_BASIC)
WITTY_ONIG_GET_SYNTAX(posix_extended, ONIG_SYNTAX_POSIX_EXTENDED)
WITTY_ONIG_GET_SYNTAX(emacs, ONIG_SYNTAX_EMACS)
WITTY_ONIG_GET_SYNTAX(grep, ONIG_SYNTAX_GREP)
WITTY_ONIG_GET_SYNTAX(gnu_regex, ONIG_SYNTAX_GNU_REGEX)
WITTY_ONIG_GET_SYNTAX(java, ONIG_SYNTAX_JAVA)
WITTY_ONIG_GET_SYNTAX(perl, ONIG_SYNTAX_PERL)
WITTY_ONIG_GET_SYNTAX(perl_ng, ONIG_SYNTAX_PERL_NG)
WITTY_ONIG_GET_SYNTAX(ruby, ONIG_SYNTAX_RUBY)
WITTY_ONIG_GET_SYNTAX(oniguruma, ONIG_SYNTAX_ONIGURUMA)

#undef WITTY_ONIG_GET_SYNTAX

static inline int witty_onig_initialize(void *const *encodings, size_t count) {
    return onig_initialize((OnigEncoding *)encodings, (int)count);
}

static inline int witty_onig_new(
    void **out,
    const unsigned char *pattern,
    size_t pattern_len,
    unsigned int options,
    void *encoding,
    void *syntax,
    void **error_par,
    void **error_par_end
) {
    OnigRegex regex = NULL;
    OnigErrorInfo info = {0};
    int result;
    result = onig_new(
        &regex,
        pattern,
        pattern + pattern_len,
        options,
        (OnigEncoding)encoding,
        (OnigSyntaxType *)syntax,
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

#endif
