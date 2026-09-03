module fontconfig

// Fontconfig bindings (Linux/Unix font discovery).
//
// Fontconfig is a library for configuring and customizing font access on
// Linux/Unix systems. It provides font matching, pattern-based font
// specification, and font set management.
//
// Translated from ghostty/pkg/fontconfig. The V wrapper structs each hold
// a single raw fontconfig `handle` pointer; the actual C entry points are
// declared as `fn C.Fc*` below.

// C compiler flags for the fontconfig library.
#flag darwin -I/opt/homebrew/include

#flag darwin -L/opt/homebrew/lib

#flag linux -I/usr/include

#flag -lfontconfig

#include <fontconfig/fontconfig.h>

#include "fontconfig_shims.h"

// === C function declarations ===

fn C.FcInit() int

fn C.FcInitLoadConfigAndFonts() voidptr

fn C.FcConfigDestroy(config voidptr)

fn C.FcConfigSubstitute(config voidptr, pat voidptr, kind int) int

fn C.FcDefaultSubstitute(pat voidptr)

fn C.FcFontSort(config voidptr, pat voidptr, trim int, csp &voidptr, result &int) voidptr

fn C.FcFontRenderPrepare(config voidptr, pat voidptr, font voidptr) voidptr

fn C.FcPatternCreate() voidptr

fn C.FcPatternDestroy(pat voidptr)

fn C.FcPatternAddString(pat voidptr, object &char, s &char) int

fn C.FcPatternAddInteger(pat voidptr, object &char, i int) int

fn C.FcPatternAddCharSet(pat voidptr, object &char, cs voidptr) int

fn C.FcPatternGetString(pat voidptr, object &char, n int, s &&char) int

fn C.FcPatternGetInteger(pat voidptr, object &char, n int, i &int) int

fn C.FcPatternGetCharSet(pat voidptr, object &char, n int, cs &voidptr) int

fn C.FcPatternGetLangSet(pat voidptr, object &char, n int, ls &voidptr) int

fn C.FcFontSetDestroy(fs voidptr)

fn C.FcCharSetCreate() voidptr

fn C.FcCharSetDestroy(cs voidptr)

fn C.FcCharSetAddChar(cs voidptr, ucs4 u32) int

fn C.FcCharSetHasChar(cs voidptr, ucs4 u32) int

fn C.FcLangSetHasLang(ls voidptr, lang &char) int

// vt_fontconfig_fontset_fonts and vt_fontconfig_fontset_nfont read the
// `fonts`/`nfont` fields out of the opaque FcFontSet struct without us
// having to hard-code the struct layout on the V side.
fn C.vt_fontconfig_fontset_nfont(fs voidptr) int

fn C.vt_fontconfig_fontset_font(fs voidptr, idx int) voidptr

// FcResult values (from fontconfig.h). FcResultMatch is 0.
const fc_result_match = 0

// FcMatchKind values.
const fc_match_pattern = 0
const fc_match_font = 1

// ============================================================
// Config
// ============================================================

// Config represents a fontconfig configuration.
pub struct Config {
	handle voidptr = unsafe { nil }
}

// init_load_config_and_fonts initializes fontconfig and loads the default
// configuration and system fonts.
pub fn init_load_config_and_fonts() Config {
	return Config{
		handle: C.FcInitLoadConfigAndFonts()
	}
}

// destroy releases the fontconfig configuration.
pub fn (c Config) destroy() {
	if !isnil(c.handle) {
		C.FcConfigDestroy(c.handle)
	}
}

// font_sort sorts fonts matching a pattern by closeness.
pub fn (c Config) font_sort(pat &Pattern, trim bool, csp voidptr) FontSortResult {
	mut result := int(0)
	fs := C.FcFontSort(c.handle, pat.handle, if trim { 1 } else { 0 }, &voidptr(unsafe { nil }), &result)
	return FontSortResult{
		result: match result {
			fc_result_match { MatchResult.match_ }
			else { MatchResult.no_match }
		}
		fs: &FontSet{
			handle: fs
		}
	}
}

// substitute_with_pat performs pattern substitution.
pub fn (c Config) substitute_with_pat(pat &Pattern, kind SubstituteKind) bool {
	fc_kind := match kind {
		.pattern { fc_match_pattern }
		.font { fc_match_font }
	}
	return C.FcConfigSubstitute(c.handle, pat.handle, fc_kind) != 0
}

// font_render_prepare prepares a pattern for rendering, producing a new
// pattern that combines the search pattern with the matched font.
pub fn (c Config) font_render_prepare(pat &Pattern, font_pat &Pattern) !&Pattern {
	ptr := C.FcFontRenderPrepare(c.handle, pat.handle, font_pat.handle)
	if isnil(ptr) {
		return error('FcFontRenderPrepare failed')
	}
	return &Pattern{
		handle: ptr
	}
}

// ============================================================
// Pattern
// ============================================================

// Pattern represents a fontconfig pattern for font matching.
pub struct Pattern {
	handle voidptr = unsafe { nil }
}

// create creates an empty fontconfig pattern.
pub fn Pattern.create() &Pattern {
	return &Pattern{
		handle: C.FcPatternCreate()
	}
}

// destroy releases the pattern.
pub fn (p &Pattern) destroy() {
	if !isnil(p.handle) {
		C.FcPatternDestroy(p.handle)
	}
}

// add adds a property to the pattern. The `append` flag is accepted for API
// compatibility; fontconfig's typed adders always append.
pub fn (p &Pattern) add(prop Property, val PatternValue, append bool) bool {
	object := prop.cval()
	return match prop {
		.family, .style {
			C.FcPatternAddString(p.handle, &char(object.str), &char(val.string.str)) != 0
		}
		.charset {
			mut cs_handle := voidptr(unsafe { nil })
			if !isnil(val.char_set) {
				cs_handle = val.char_set.handle
			}
			C.FcPatternAddCharSet(p.handle, &char(object.str), cs_handle) != 0
		}
		.size, .weight, .slant, .spacing {
			C.FcPatternAddInteger(p.handle, &char(object.str), val.integer) != 0
		}
		.lang {
			C.FcPatternAddString(p.handle, &char(object.str), &char(val.string.str)) != 0
		}
	}
}

// default_substitute fills in default values for the pattern.
pub fn (p &Pattern) default_substitute() {
	C.FcDefaultSubstitute(p.handle)
}

// get retrieves a property value from the pattern at the given index.
pub fn (p &Pattern) get(prop Property, idx int) !PatternValue {
	object := prop.cval()
	return match prop {
		.family, .style, .lang {
			mut sptr := &char(unsafe { nil })
			if C.FcPatternGetString(p.handle, &char(object.str), idx, &sptr) != fc_result_match {
				return error('FcPatternGetString(${object}) failed')
			}
			PatternValue{
				string: unsafe { cstring_to_vstring(sptr) }
			}
		}
		.size, .weight, .slant, .spacing, .charset {
			mut ival := int(0)
			if C.FcPatternGetInteger(p.handle, &char(object.str), idx, &ival) != fc_result_match {
				return error('FcPatternGetInteger(${object}) failed')
			}
			PatternValue{
				integer: ival
			}
		}
	}
}

// file returns the font file path stored in this pattern (FC_FILE), if any.
pub fn (p &Pattern) file() ?string {
	mut sptr := &char(unsafe { nil })
	if C.FcPatternGetString(p.handle, c'file', 0, &sptr) != fc_result_match {
		return none
	}
	if isnil(sptr) {
		return none
	}
	return unsafe { cstring_to_vstring(sptr) }
}

// index returns the face index stored in this pattern (FC_INDEX), or 0.
pub fn (p &Pattern) index() int {
	mut ival := int(0)
	if C.FcPatternGetInteger(p.handle, c'index', 0, &ival) != fc_result_match {
		return 0
	}
	return ival
}

// has_char reports whether the pattern's character set contains cp.
pub fn (p &Pattern) has_char(cp u32) bool {
	mut charset := voidptr(unsafe { nil })
	if C.FcPatternGetCharSet(p.handle, c'charset', 0, &charset) != fc_result_match
		|| isnil(charset) {
		return false
	}
	return C.FcCharSetHasChar(charset, cp) != 0
}

// is_emoji reports whether Fontconfig marks this font with the emoji
// presentation language (`und-zsye`).
pub fn (p &Pattern) is_emoji() bool {
	mut langset := voidptr(unsafe { nil })
	if C.FcPatternGetLangSet(p.handle, c'lang', 0, &langset) != fc_result_match
		|| isnil(langset) {
		return false
	}
	// FcLangEqual (0) and FcLangDifferentCountry (1) are matches;
	// FcLangDifferentLang is 2.
	return C.FcLangSetHasLang(langset, c'und-zsye') < 2
}

// ============================================================
// FontSet
// ============================================================

// FontSet holds a set of font patterns.
pub struct FontSet {
	handle voidptr = unsafe { nil }
}

// destroy releases the font set.
pub fn (fs &FontSet) destroy() {
	if !isnil(fs.handle) {
		C.FcFontSetDestroy(fs.handle)
	}
}

// fonts returns the font patterns in this set.
pub fn (fs &FontSet) fonts() []&Pattern {
	if isnil(fs.handle) {
		return []&Pattern{}
	}
	n := C.vt_fontconfig_fontset_nfont(fs.handle)
	mut out := []&Pattern{cap: n}
	for i in 0 .. n {
		ptr := C.vt_fontconfig_fontset_font(fs.handle, i)
		out << &Pattern{
			handle: ptr
		}
	}
	return out
}

// ============================================================
// CharSet
// ============================================================

// CharSet represents a set of Unicode codepoints.
pub struct CharSet {
	handle voidptr = unsafe { nil }
}

// create creates an empty character set.
pub fn CharSet.create() &CharSet {
	return &CharSet{
		handle: C.FcCharSetCreate()
	}
}

// destroy releases the character set.
pub fn (cs &CharSet) destroy() {
	if !isnil(cs.handle) {
		C.FcCharSetDestroy(cs.handle)
	}
}

// add_char adds a codepoint to the character set.
pub fn (cs &CharSet) add_char(cp u32) bool {
	return C.FcCharSetAddChar(cs.handle, cp) != 0
}

// ============================================================
// LangSet
// ============================================================

// LangSet represents a set of languages.
pub struct LangSet {
	handle voidptr = unsafe { nil }
}

// ============================================================
// Enums and types
// ============================================================

// Property identifies a fontconfig pattern property.
pub enum Property {
	family
	style
	charset
	size
	weight
	slant
	spacing
	lang
}

// cval returns the fontconfig object string for this property.
pub fn (p Property) cval() string {
	return match p {
		.family { 'family' }
		.style { 'style' }
		.charset { 'charset' }
		.size { 'size' }
		.weight { 'weight' }
		.slant { 'slant' }
		.spacing { 'spacing' }
		.lang { 'lang' }
	}
}

// PatternValue holds a typed value from a fontconfig pattern.
pub struct PatternValue {
pub:
	string   string
	integer  int
	char_set &CharSet = unsafe { nil }
	lang_set &LangSet = unsafe { nil }
}

// SubstituteKind identifies the type of substitution.
pub enum SubstituteKind {
	pattern
	font
}

// Weight constants for fontconfig (matching FC_WEIGHT_* values).
pub enum Weight {
	thin    = 0
	light   = 50
	regular = 80
	medium  = 100
	bold    = 200
	black   = 215
}

// Slant constants for fontconfig (matching FC_SLANT_* values).
pub enum Slant {
	roman   = 0
	italic  = 100
	oblique = 110
}

// Spacing constants for fontconfig (matching FC_* spacing values).
pub enum Spacing {
	proportional = 0
	dual         = 90
	mono         = 100
	charcell     = 110
}

// FontSortResult holds the result of a font sort operation.
pub struct FontSortResult {
pub:
	result MatchResult
	fs     &FontSet = unsafe { nil }
}

// MatchResult indicates the outcome of a font match.
pub enum MatchResult {
	match_
	no_match
	type_mismatch
}

// fc_init initializes the fontconfig library.
// Safe to call multiple times and concurrently.
pub fn fc_init() bool {
	return C.FcInit() != 0
}
