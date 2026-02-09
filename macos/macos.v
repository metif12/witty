module macos

// Translated from:
// - ghostty/pkg/macos/foundation/base.zig
// - ghostty/pkg/macos/foundation/type.zig
// - ghostty/pkg/macos/foundation/string.zig
// - ghostty/pkg/macos/foundation/number.zig
// - ghostty/pkg/macos/foundation/dictionary.zig
// - ghostty/pkg/macos/foundation/array.zig
// - ghostty/pkg/macos/foundation/attributed_string.zig
// - ghostty/pkg/macos/text/typesetter.zig
// - ghostty/pkg/macos/text/line.zig
// - ghostty/pkg/macos/text/run.zig
// - ghostty/pkg/macos/text/font_descriptor.zig
// - ghostty/pkg/macos/text/font.zig

#flag darwin -framework CoreFoundation
#flag darwin -framework CoreText
#flag darwin -framework CoreGraphics
#include <CoreFoundation/CoreFoundation.h>
#include <CoreText/CoreText.h>
#include <CoreGraphics/CoreGraphics.h>

fn C.CFRelease(obj voidptr)
fn C.CFRetain(obj voidptr) voidptr
fn C.CFStringCreateWithBytes(alloc voidptr, bytes voidptr, bytes_len isize, encoding u32, external bool) voidptr
fn C.CFStringCreateWithCharactersNoCopy(alloc voidptr, chars voidptr, chars_len isize, deallocator voidptr) voidptr
fn C.CFStringGetSurrogatePairForLongCharacter(cp u32, surrogates voidptr) int
fn C.CFNumberCreate(alloc voidptr, number_type int, value_ptr voidptr) voidptr
fn C.CFDictionaryCreate(alloc voidptr, keys voidptr, values voidptr, count isize, key_cb voidptr, value_cb voidptr) voidptr
fn C.CFArrayCreateMutable(alloc voidptr, cap isize, callbacks voidptr) voidptr
fn C.CFArrayAppendValue(arr voidptr, value voidptr)
fn C.CFArrayGetCount(arr voidptr) isize
fn C.CFArrayGetValueAtIndex(arr voidptr, idx isize) voidptr
fn C.CFAttributedStringCreate(alloc voidptr, str voidptr, attrs voidptr) voidptr
fn C.CTTypesetterCreateWithAttributedStringAndOptions(str voidptr, opts voidptr) voidptr
fn C.CTLineGetGlyphCount(line voidptr) isize
fn C.CTLineGetGlyphRuns(line voidptr) voidptr
fn C.CTRunGetStatus(run voidptr) u32
fn C.CTRunGetGlyphCount(run voidptr) isize
fn C.CTFontDescriptorCreateWithAttributes(attrs voidptr) voidptr
fn C.CTFontDescriptorCreateWithNameAndSize(name voidptr, size f64) voidptr
fn C.CTFontDescriptorCreateCopyWithAttributes(original voidptr, attrs voidptr) voidptr
fn C.CTFontDescriptorCreateCopyWithVariation(original voidptr, id voidptr, value f64) voidptr
fn C.CTFontCreateWithFontDescriptor(desc voidptr, size f64, matrix voidptr) voidptr
fn C.CTFontCreateCopyWithAttributes(font voidptr, size f64, matrix voidptr, desc voidptr) voidptr
fn C.vt_ct_typesetter_create_line(typesetter voidptr, location isize, length isize) voidptr
fn C.vt_ctrun_get_glyphs_all(run voidptr, out_glyphs voidptr)
fn C.vt_ctrun_get_advances_all(run voidptr, out_advances voidptr)
fn C.vt_ctrun_get_positions_all(run voidptr, out_positions voidptr)
fn C.vt_ctrun_get_string_indices_all(run voidptr, out_indices voidptr)

// Exposed by appkit.m for CF callback structs and CF/CoreText constants.
fn C.vt_cf_allocator_null() voidptr
fn C.vt_cf_type_dictionary_key_callbacks() voidptr
fn C.vt_cf_type_dictionary_value_callbacks() voidptr
fn C.vt_cf_type_array_callbacks() voidptr
fn C.vt_k_ct_font_open_type_feature_tag() voidptr
fn C.vt_k_ct_font_open_type_feature_value() voidptr
fn C.vt_k_ct_font_feature_settings_attribute() voidptr
fn C.vt_k_ct_typesetter_option_forced_embedding_level() voidptr

@[inline]
fn cast_cf_ref[T](ptr voidptr) &T {
	return unsafe { &T(ptr) }
}

@[inline]
fn require_cf_ref[T](ptr voidptr, name string) !&T {
	if isnil(ptr) {
		return error('${name} failed')
	}
	return cast_cf_ref[T](ptr)
}

// ============================================================
// CoreFoundation base
// ============================================================

// CFRelease releases a CoreFoundation object.
pub fn cf_release(obj voidptr) {
	if !isnil(obj) {
		C.CFRelease(obj)
	}
}

// CFRetain retains a CoreFoundation object.
pub fn cf_retain(obj voidptr) voidptr {
	if isnil(obj) {
		return unsafe { nil }
	}
	return C.CFRetain(obj)
}

// ============================================================
// foundation.String
// ============================================================

pub struct CFString {}

// Create a CFString from a slice of UTF-16 characters (no-copy).
pub fn CFString.create_with_characters_no_copy(unichars []u16) &CFString {
	mut chars_ptr := voidptr(unsafe { nil })
	if unichars.len > 0 {
		chars_ptr = voidptr(unichars.data)
	}
	ptr := C.CFStringCreateWithCharactersNoCopy(unsafe { nil }, chars_ptr, isize(unichars.len),
		C.vt_cf_allocator_null())
	if isnil(ptr) {
		// Maintain prior non-error API: return a null-like pointer on failure.
		return unsafe { &CFString(nil) }
	}
	return cast_cf_ref[CFString](ptr)
}

// Create a CFString from bytes with the given encoding.
pub fn CFString.create_with_bytes(bytes []u8, encoding Encoding, external_rep bool) !&CFString {
	mut bytes_ptr := voidptr(unsafe { nil })
	if bytes.len > 0 {
		bytes_ptr = voidptr(bytes.data)
	}
	ptr := C.CFStringCreateWithBytes(unsafe { nil }, bytes_ptr, isize(bytes.len), u32(encoding),
		external_rep)
	return require_cf_ref[CFString](ptr, 'CFStringCreateWithBytes')
}

pub fn (s &CFString) release() {
	cf_release(voidptr(s))
}

pub enum Encoding {
	invalid = 0xffffffff
	ascii   = 0x0600
	utf16   = 0x0100
	utf8    = 0x08000100
}

// SurrogatePair holds the result of UTF-16 surrogate pair encoding.
pub struct SurrogatePair {
pub:
	hi      u16
	lo      u16
	is_pair bool
}

// Get a surrogate pair for a character > U+FFFF.
// Returns the high/low surrogates and whether the character required a pair.
pub fn get_surrogate_pair(cp u32) SurrogatePair {
	mut pair := [u16(0), 0]!
	if C.CFStringGetSurrogatePairForLongCharacter(cp, voidptr(&pair[0])) != 0 {
		return SurrogatePair{
			hi:      pair[0]
			lo:      pair[1]
			is_pair: true
		}
	}
	return SurrogatePair{
		hi:      u16(cp)
		lo:      0
		is_pair: false
	}
}

// ============================================================
// foundation.Number
// ============================================================

pub struct CFNumber {}

pub fn CFNumber.create(num_type NumberType, value_ptr voidptr) !&CFNumber {
	ptr := C.CFNumberCreate(unsafe { nil }, int(num_type), value_ptr)
	return require_cf_ref[CFNumber](ptr, 'CFNumberCreate')
}

pub fn (n &CFNumber) release() {
	cf_release(voidptr(n))
}

pub enum NumberType {
	int_type = 9
}

// ============================================================
// foundation.Dictionary
// ============================================================

pub struct CFDictionary {}

pub fn CFDictionary.create(keys []voidptr, values []voidptr) !&CFDictionary {
	if keys.len != values.len {
		return error('CFDictionaryCreate: keys/values length mismatch')
	}
	mut keys_ptr := voidptr(unsafe { nil })
	if keys.len > 0 {
		keys_ptr = voidptr(&keys[0])
	}
	mut values_ptr := voidptr(unsafe { nil })
	if values.len > 0 {
		values_ptr = voidptr(&values[0])
	}
	ptr := C.CFDictionaryCreate(unsafe { nil }, keys_ptr, values_ptr, isize(keys.len),
		C.vt_cf_type_dictionary_key_callbacks(), C.vt_cf_type_dictionary_value_callbacks())
	return require_cf_ref[CFDictionary](ptr, 'CFDictionaryCreate')
}

pub fn (d &CFDictionary) release() {
	cf_release(voidptr(d))
}

// ============================================================
// foundation.MutableArray
// ============================================================

pub struct CFMutableArray {}

pub fn CFMutableArray.create() !&CFMutableArray {
	ptr := C.CFArrayCreateMutable(unsafe { nil }, 0, C.vt_cf_type_array_callbacks())
	return require_cf_ref[CFMutableArray](ptr, 'CFArrayCreateMutable')
}

pub fn (mut a CFMutableArray) append_value(val voidptr) {
	C.CFArrayAppendValue(voidptr(&a), val)
}

pub fn (a &CFMutableArray) release() {
	cf_release(voidptr(a))
}

// ============================================================
// foundation.AttributedString
// ============================================================

pub struct CFAttributedString {}

pub fn CFAttributedString.create(str &CFString, attrs &CFDictionary) !&CFAttributedString {
	ptr := C.CFAttributedStringCreate(unsafe { nil }, voidptr(str), voidptr(attrs))
	return require_cf_ref[CFAttributedString](ptr, 'CFAttributedStringCreate')
}

pub fn (s &CFAttributedString) release() {
	cf_release(voidptr(s))
}

// ============================================================
// text.Typesetter
// ============================================================

pub struct CTTypesetter {}

pub fn CTTypesetter.create_with_attributed_string_and_options(attr_str &CFAttributedString, opts &CFDictionary) !&CTTypesetter {
	ptr := C.CTTypesetterCreateWithAttributedStringAndOptions(voidptr(attr_str), voidptr(opts))
	return require_cf_ref[CTTypesetter](ptr, 'CTTypesetterCreateWithAttributedStringAndOptions')
}

pub fn (t &CTTypesetter) create_line(range CFRange) &CTLine {
	ptr := C.vt_ct_typesetter_create_line(voidptr(t), range.location, range.length)
	if isnil(ptr) {
		return unsafe { &CTLine(nil) }
	}
	return cast_cf_ref[CTLine](ptr)
}

pub fn (t &CTTypesetter) release() {
	cf_release(voidptr(t))
}

pub struct CFRange {
pub:
	location isize
	length   isize
}

// ============================================================
// text.Line
// ============================================================

pub struct CTLine {
}

pub fn (l &CTLine) get_glyph_count() int {
	return int(C.CTLineGetGlyphCount(voidptr(l)))
}

pub fn (l &CTLine) get_glyph_runs() &CFArray {
	ptr := C.CTLineGetGlyphRuns(voidptr(l))
	if isnil(ptr) {
		return unsafe { &CFArray(nil) }
	}
	return cast_cf_ref[CFArray](ptr)
}

pub fn (l &CTLine) release() {
	cf_release(voidptr(l))
}

// ============================================================
// text.Run
// ============================================================

pub struct CTRun {
}

pub fn (r &CTRun) get_status() CTRunStatus {
	raw := C.CTRunGetStatus(voidptr(r))
	return CTRunStatus{
		right_to_left: (raw & u32(1)) != 0
		non_monotonic: (raw & u32(2)) != 0
	}
}

pub fn (r &CTRun) get_glyphs() []u32 {
	count := r.get_glyph_count()
	if count <= 0 {
		return []u32{}
	}

	mut buf := []u16{len: count}
	C.vt_ctrun_get_glyphs_all(voidptr(r), voidptr(buf.data))

	mut out := []u32{len: count}
	for i in 0 .. count {
		out[i] = u32(buf[i])
	}
	return out
}

pub fn (r &CTRun) get_advances() []CGSize {
	count := r.get_glyph_count()
	if count <= 0 {
		return []CGSize{}
	}
	mut out := []CGSize{len: count}
	C.vt_ctrun_get_advances_all(voidptr(r), voidptr(out.data))
	return out
}

pub fn (r &CTRun) get_positions() []CGPoint {
	count := r.get_glyph_count()
	if count <= 0 {
		return []CGPoint{}
	}
	mut out := []CGPoint{len: count}
	C.vt_ctrun_get_positions_all(voidptr(r), voidptr(out.data))
	return out
}

pub fn (r &CTRun) get_string_indices() []int {
	count := r.get_glyph_count()
	if count <= 0 {
		return []int{}
	}
	mut tmp := []isize{len: count}
	C.vt_ctrun_get_string_indices_all(voidptr(r), voidptr(tmp.data))
	mut out := []int{len: count}
	for i in 0 .. count {
		out[i] = int(tmp[i])
	}
	return out
}

pub fn (r &CTRun) get_glyph_count() int {
	return int(C.CTRunGetGlyphCount(voidptr(r)))
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
	ptr := C.CTFontDescriptorCreateWithAttributes(voidptr(attrs))
	return require_cf_ref[CTFontDescriptor](ptr, 'CTFontDescriptorCreateWithAttributes')
}

pub fn CTFontDescriptor.create_with_name_and_size(name &CFString, size f64) !&CTFontDescriptor {
	ptr := C.CTFontDescriptorCreateWithNameAndSize(voidptr(name), size)
	return require_cf_ref[CTFontDescriptor](ptr, 'CTFontDescriptorCreateWithNameAndSize')
}

pub fn (d &CTFontDescriptor) copy_with_attributes(attrs &CFDictionary) !&CTFontDescriptor {
	ptr := C.CTFontDescriptorCreateCopyWithAttributes(voidptr(d), voidptr(attrs))
	return require_cf_ref[CTFontDescriptor](ptr, 'CTFontDescriptorCreateCopyWithAttributes')
}

pub fn (d &CTFontDescriptor) copy_with_variation(id &CFNumber, value f64) !&CTFontDescriptor {
	ptr := C.CTFontDescriptorCreateCopyWithVariation(voidptr(d), voidptr(id), value)
	return require_cf_ref[CTFontDescriptor](ptr, 'CTFontDescriptorCreateCopyWithVariation')
}

pub fn (d &CTFontDescriptor) release() {
	cf_release(voidptr(d))
}

// ============================================================
// text.Font (CTFont)
// ============================================================

pub struct CTFont {}

pub fn (f &CTFont) copy_with_attributes(size f64, matrix voidptr, desc &CTFontDescriptor) !&CTFont {
	ptr := C.CTFontCreateCopyWithAttributes(voidptr(f), size, matrix, voidptr(desc))
	return require_cf_ref[CTFont](ptr, 'CTFontCreateCopyWithAttributes')
}

pub fn CTFont.create_with_descriptor(desc &CTFontDescriptor, size f64) !&CTFont {
	ptr := C.CTFontCreateWithFontDescriptor(voidptr(desc), size, unsafe { nil })
	return require_cf_ref[CTFont](ptr, 'CTFontCreateWithFontDescriptor')
}

pub fn (f &CTFont) release() {
	cf_release(voidptr(f))
}

// ============================================================
// text.StringAttribute
// ============================================================

pub enum StringAttribute {
	font
}

pub fn (a StringAttribute) key() voidptr {
	match a {
		.font {
			return ct_font_attribute_name()
		}
	}
}

// ============================================================
// CoreText constants
// ============================================================

// kCTFontOpenTypeFeatureTag
pub fn k_ct_font_open_type_feature_tag() voidptr {
	return C.vt_k_ct_font_open_type_feature_tag()
}

// kCTFontOpenTypeFeatureValue
pub fn k_ct_font_open_type_feature_value() voidptr {
	return C.vt_k_ct_font_open_type_feature_value()
}

// kCTFontFeatureSettingsAttribute
pub fn k_ct_font_feature_settings_attribute() voidptr {
	return C.vt_k_ct_font_feature_settings_attribute()
}

// kCTTypesetterOptionForcedEmbeddingLevel
pub fn k_ct_typesetter_option_forced_embedding_level() voidptr {
	return C.vt_k_ct_typesetter_option_forced_embedding_level()
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
}

pub fn (a &CFArray) get_count() int {
	return int(C.CFArrayGetCount(voidptr(a)))
}

pub fn (a &CFArray) get_value_at_index(idx int) voidptr {
	if idx < 0 || idx >= a.get_count() {
		return unsafe { nil }
	}
	return C.CFArrayGetValueAtIndex(voidptr(a), isize(idx))
}

// ============================================================
// CFReleaseThread — dedicated thread for releasing CF objects
// ============================================================

pub struct CFReleaseThread {
}

pub fn CFReleaseThread.init() !CFReleaseThread {
	return CFReleaseThread{}
}

pub fn (mut t CFReleaseThread) deinit() {
	_ = t
}

pub fn (mut t CFReleaseThread) stop() {
	_ = t
}

// Push a batch of objects to release.
pub fn (mut t CFReleaseThread) push(refs []voidptr) bool {
	_ = t
	for ref in refs {
		cf_release(ref)
	}
	return true
}

// Notify the release thread to wake up and process.
pub fn (mut t CFReleaseThread) notify_wakeup() {
	_ = t
}
