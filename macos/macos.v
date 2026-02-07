module macos

// Stub module for macOS CoreText / CoreFoundation bindings.
// These types mirror the Zig macos bindings used by the Ghostty
// CoreText shaper.

// ============================================================
// CoreFoundation base
// ============================================================

// CFRelease releases a CoreFoundation object.
pub fn cf_release(obj voidptr) {
	// XTODO: call CFRelease(obj)
}

// ============================================================
// foundation.String
// ============================================================

pub struct CFString {
mut:
	chars []u16
}

// Create a CFString from a slice of UTF-16 characters (no-copy).
pub fn CFString.create_with_characters_no_copy(unichars []u16) &CFString {
	// XTODO: call CFStringCreateWithCharactersNoCopy
	return &CFString{
		chars: unichars
	}
}

// Create a CFString from bytes with the given encoding.
pub fn CFString.create_with_bytes(bytes []u8, encoding Encoding, external_rep bool) !&CFString {
	// XTODO: call CFStringCreateWithBytes
	return &CFString{}
}

pub fn (s &CFString) release() {
	// XTODO: call CFRelease
}

pub enum Encoding {
	ascii
	utf8
	utf16
}

// SurrogatePair holds the result of UTF-16 surrogate pair encoding.
pub struct SurrogatePair {
pub:
	hi     u16
	lo     u16
	is_pair bool
}

// Get a surrogate pair for a character > U+FFFF.
// Returns the high/low surrogates and whether the character required a pair.
pub fn get_surrogate_pair(cp u32) SurrogatePair {
	if cp > 0xFFFF {
		return SurrogatePair{
			hi: u16(0xD800 + ((cp - 0x10000) >> 10))
			lo: u16(0xDC00 + ((cp - 0x10000) & 0x3FF))
			is_pair: true
		}
	}
	return SurrogatePair{
		hi: u16(cp)
		lo: 0
		is_pair: false
	}
}

// ============================================================
// foundation.Number
// ============================================================

pub struct CFNumber {
	value int
}

pub fn CFNumber.create(num_type NumberType, value_ptr voidptr) !&CFNumber {
	// XTODO: call CFNumberCreate
	return &CFNumber{}
}

pub fn (n &CFNumber) release() {
	// XTODO: call CFRelease
}

pub enum NumberType {
	int_type
}

// ============================================================
// foundation.Dictionary
// ============================================================

pub struct CFDictionary {
mut:
	keys   []voidptr
	values []voidptr
}

pub fn CFDictionary.create(keys []voidptr, values []voidptr) !&CFDictionary {
	// XTODO: call CFDictionaryCreate
	return &CFDictionary{
		keys: keys.clone()
		values: values.clone()
	}
}

pub fn (d &CFDictionary) release() {
	// XTODO: call CFRelease
}

// ============================================================
// foundation.MutableArray
// ============================================================

pub struct CFMutableArray {
mut:
	items []voidptr
}

pub fn CFMutableArray.create() !&CFMutableArray {
	// XTODO: call CFArrayCreateMutable
	return &CFMutableArray{}
}

pub fn (mut a CFMutableArray) append_value(val voidptr) {
	a.items << val
}

pub fn (a &CFMutableArray) release() {
	// XTODO: call CFRelease
}

// ============================================================
// foundation.AttributedString
// ============================================================

pub struct CFAttributedString {}

pub fn CFAttributedString.create(str &CFString, attrs &CFDictionary) !&CFAttributedString {
	// XTODO: call CFAttributedStringCreate
	return &CFAttributedString{}
}

pub fn (s &CFAttributedString) release() {
	// XTODO: call CFRelease
}

// ============================================================
// text.Typesetter
// ============================================================

pub struct CTTypesetter {}

pub fn CTTypesetter.create_with_attributed_string_and_options(attr_str &CFAttributedString, opts &CFDictionary) !&CTTypesetter {
	// XTODO: call CTTypesetterCreateWithAttributedStringAndOptions
	return &CTTypesetter{}
}

pub fn (t &CTTypesetter) create_line(range CFRange) &CTLine {
	// XTODO: call CTTypesetterCreateLine
	return &CTLine{}
}

pub fn (t &CTTypesetter) release() {
	// XTODO: call CFRelease
}

pub struct CFRange {
pub:
	location int
	length   int
}

// ============================================================
// text.Line
// ============================================================

pub struct CTLine {
mut:
	glyphs []CTRun
}

pub fn (l &CTLine) get_glyph_count() int {
	// XTODO: call CTLineGetGlyphCount
	return 0
}

pub fn (l &CTLine) get_glyph_runs() &CFArray {
	// XTODO: call CTLineGetGlyphRuns
	return &CFArray{}
}

pub fn (l &CTLine) release() {
	// XTODO: call CFRelease
}

// ============================================================
// text.Run
// ============================================================

pub struct CTRun {
pub:
	glyphs_data   []u32
	advances_data []CGSize
	positions_data []CGPoint
	indices_data   []int
}

pub fn (r &CTRun) get_status() CTRunStatus {
	// XTODO: call CTRunGetStatus
	return CTRunStatus{}
}

pub fn (r &CTRun) get_glyphs() []u32 {
	// XTODO: call CTRunGetGlyphs
	return r.glyphs_data
}

pub fn (r &CTRun) get_advances() []CGSize {
	// XTODO: call CTRunGetAdvances
	return r.advances_data
}

pub fn (r &CTRun) get_positions() []CGPoint {
	// XTODO: call CTRunGetPositions
	return r.positions_data
}

pub fn (r &CTRun) get_string_indices() []int {
	// XTODO: call CTRunGetStringIndices
	return r.indices_data
}

pub fn (r &CTRun) get_glyph_count() int {
	return r.glyphs_data.len
}

pub struct CTRunStatus {
pub:
	non_monotonic bool
	right_to_left bool
}

// ============================================================
// text.FontDescriptor
// ============================================================

pub struct CTFontDescriptor {}

pub fn CTFontDescriptor.create_with_attributes(attrs &CFDictionary) !&CTFontDescriptor {
	// XTODO: call CTFontDescriptorCreateWithAttributes
	return &CTFontDescriptor{}
}

pub fn (d &CTFontDescriptor) release() {
	// XTODO: call CFRelease
}

// ============================================================
// text.Font (CTFont)
// ============================================================

pub struct CTFont {}

pub fn (f &CTFont) copy_with_attributes(size f64, matrix voidptr, desc &CTFontDescriptor) !&CTFont {
	// XTODO: call CTFontCreateCopyWithAttributes
	return &CTFont{}
}

pub fn (f &CTFont) release() {
	// XTODO: call CFRelease
}

// ============================================================
// text.StringAttribute
// ============================================================

pub enum StringAttribute {
	font
}

pub fn (a StringAttribute) key() voidptr {
	// XTODO: return kCTFontAttributeName etc.
	return unsafe { nil }
}

// ============================================================
// CoreText constants
// ============================================================

// kCTFontOpenTypeFeatureTag
pub fn k_ct_font_open_type_feature_tag() voidptr {
	// XTODO: return kCTFontOpenTypeFeatureTag
	return unsafe { nil }
}

// kCTFontOpenTypeFeatureValue
pub fn k_ct_font_open_type_feature_value() voidptr {
	// XTODO: return kCTFontOpenTypeFeatureValue
	return unsafe { nil }
}

// kCTFontFeatureSettingsAttribute
pub fn k_ct_font_feature_settings_attribute() voidptr {
	// XTODO: return kCTFontFeatureSettingsAttribute
	return unsafe { nil }
}

// kCTTypesetterOptionForcedEmbeddingLevel
pub fn k_ct_typesetter_option_forced_embedding_level() voidptr {
	// XTODO: return kCTTypesetterOptionForcedEmbeddingLevel
	return unsafe { nil }
}

// ============================================================
// graphics.Point / Size
// ============================================================

pub struct CGPoint {
pub:
	x f64
	y f64
}

pub struct CGSize {
pub:
	width  f64
	height f64
}

// ============================================================
// CFArray (generic array wrapper)
// ============================================================

pub struct CFArray {
mut:
	items []voidptr
}

pub fn (a &CFArray) get_count() int {
	return a.items.len
}

pub fn (a &CFArray) get_value_at_index(idx int) voidptr {
	if idx < a.items.len {
		return a.items[idx]
	}
	return unsafe { nil }
}

// ============================================================
// CFReleaseThread — dedicated thread for releasing CF objects
// ============================================================

pub struct CFReleaseThread {
mut:
	running bool
}

pub fn CFReleaseThread.init() !CFReleaseThread {
	return CFReleaseThread{
		running: true
	}
}

pub fn (mut t CFReleaseThread) deinit() {
	t.running = false
}

pub fn (mut t CFReleaseThread) stop() {
	t.running = false
}

// Push a batch of objects to release.
pub fn (mut t CFReleaseThread) push(refs []voidptr) bool {
	// XTODO: implement thread-safe queue push
	_ = refs
	return true
}

// Notify the release thread to wake up and process.
pub fn (mut t CFReleaseThread) notify_wakeup() {
	// XTODO: signal the release thread condition variable
}
