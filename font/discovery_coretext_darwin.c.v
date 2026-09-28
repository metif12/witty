module font

// CoreText discovery (discovery.zig's CoreText and Descriptor.toCoreTextDescriptor),
// compiled only for Darwin where the CoreText font backend is selected.
import ascii
import log
import macos
import opentype

fn C.witty_ct_font_glyph_count(font_ptr voidptr) u64
fn C.witty_ct_descriptor_traits(desc_ptr voidptr) u32
fn C.witty_ct_descriptor_style_name(desc_ptr voidptr, buf &u8, len usize) int
fn C.witty_ct_font_copy_variation_axes(font_ptr voidptr) voidptr
fn C.witty_ct_font_copy_variation_values(font_ptr voidptr) voidptr
fn C.witty_ct_variation_count(axes_ptr voidptr) int
fn C.witty_ct_variation_get(axes_ptr voidptr, values_ptr voidptr, index int, name_buf &u8, name_len usize, value_out &f64) int

// to_core_text_descriptor converts the descriptor to a CoreText font
// descriptor for font lookup or conversion to a specific font.
//
// Builds a CTFontDescriptor from our fields (family, style, codepoint
// character set, size and symbolic traits) via the C shim. The returned
// descriptor is retained; callers must release it with macos.cf_release.
pub fn (d &Descriptor) to_core_text_descriptor() !&macos.CTFontDescriptor {
	family := d.family or { '' }
	style := d.style or { '' }
	ptr := C.witty_ct_build_descriptor(&char(family.str), &char(style.str), d.codepoint,
		f64(d.size), b2i(d.bold), b2i(d.italic), b2i(d.monospace))
	if isnil(ptr) {
		return error('CTFontDescriptorCreateWithAttributes failed')
	}
	return unsafe { &macos.CTFontDescriptor(ptr) }
}

// CoreTextDiscovery discovers fonts using Apple's CoreText framework (macOS).
pub struct CoreTextDiscovery {}

// init creates a new CoreTextDiscovery instance.
// Required for the "interface" but does nothing for CoreText.
pub fn CoreTextDiscovery.init() CoreTextDiscovery {
	return CoreTextDiscovery{}
}

// deinit releases resources (no-op for CoreText).
pub fn (mut ct CoreTextDiscovery) deinit() {
}

// discover finds fonts matching the descriptor. Returns an iterator
// that can be used to build up the deferred fonts.
pub fn (ct &CoreTextDiscovery) discover(desc Descriptor) !CtDiscoverIterator {
	// Build the CoreText descriptor we'll search for.
	ct_desc := desc.to_core_text_descriptor()!
	defer {
		macos.cf_release(voidptr(ct_desc))
	}

	// Build our collection and grab the matching descriptors (a CFArray).
	list := C.witty_ct_matching_descriptors(voidptr(ct_desc))
	if isnil(list) {
		return error('CoreText: failed to create matching font descriptors')
	}
	defer {
		C.witty_ct_release(list)
	}

	// Copy the matching descriptors into a V slice, retaining each so they
	// survive the release of the CFArray, then sort by score.
	mut zig_list := copy_matching_descriptors(list)
	sort_matching_descriptors(desc, mut zig_list)

	return CtDiscoverIterator{
		list:       zig_list
		variations: desc.variations
		i:          0
	}
}

// copy_matching_descriptors copies the CFArray of matching descriptors into a
// V slice, retaining each descriptor (the array releases its members when it
// is freed, so we must retain to keep them alive).
fn copy_matching_descriptors(list voidptr) []voidptr {
	if isnil(list) {
		return []voidptr{}
	}
	n := C.witty_cf_array_count(list)
	mut out := []voidptr{cap: n}
	for i in 0 .. n {
		d := C.witty_cf_array_get(list, i)
		if !isnil(d) {
			C.witty_ct_retain(d)
		}
		out << d
	}
	return out
}

// sort_matching_descriptors sorts the descriptor list so that the best
// matches (highest score) come first. This mirrors ghostty's
// sortMatchingDescriptors: a higher score is "less" (earlier).
fn sort_matching_descriptors(desc Descriptor, mut list []voidptr) {
	list.sort_with_compare(fn [desc] (a &voidptr, b &voidptr) int {
		lhs := Score.score(&desc, *a).int()
		rhs := Score.score(&desc, *b).int()
		// Higher score is earlier.
		if lhs > rhs {
			return -1
		}
		if lhs < rhs {
			return 1
		}
		return 0
	})
}

// score computes the sorting score for a candidate CoreText descriptor.
// The control flow and score precedence are a direct translation of
// discovery.zig's Score.score; the C shim only exposes primitive CoreText
// values that V's C interop cannot retrieve generically.
fn Score.score(desc &Descriptor, ct_desc voidptr) Score {
	descriptor := unsafe { &macos.CTFontDescriptor(ct_desc) }
	native_font := macos.CTFont.create_with_descriptor(descriptor, 12) or {
		return Score{}
	}
	defer { native_font.release() }
	font_ptr := voidptr(native_font)

	glyph_count_raw := C.witty_ct_font_glyph_count(font_ptr)
	glyph_count := if glyph_count_raw > u64(0xffff) { u16(0xffff) } else { u16(glyph_count_raw) }

	mut has_codepoint := false
	if desc.codepoint > 0 {
		mut unichars := []u16{len: 2}
		pair := macos.string_get_surrogate_pair_for_long_character(desc.codepoint,
			mut unichars)
		len := if pair { 2 } else { 1 }
		mut glyphs := []macos.CGGlyph{len: 2}
		has_codepoint = native_font.get_glyphs_for_characters(unichars[..len], glyphs[..len])
	}

	traits := C.witty_ct_descriptor_traits(ct_desc)
	mut is_bold := traits & 1 != 0
	mut is_italic := traits & 2 != 0
	monospace := traits & 4 != 0

	core_face := CoreTextFace{
		ct_font: font_ptr
	}
	if head := score_head_table(core_face) {
		is_bold = is_bold || head.mac_style & 1 == 1
		is_italic = is_italic || head.mac_style & 2 == 2
	}
	if os2 := score_os2_table(core_face) {
		is_bold = is_bold || os2.fs_selection.bold()
		is_italic = is_italic || os2.fs_selection.italic()
	}

	axes := C.witty_ct_font_copy_variation_axes(font_ptr)
	if !isnil(axes) {
		defer { C.witty_ct_release(axes) }
		values := C.witty_ct_font_copy_variation_values(font_ptr)
		if !isnil(values) {
			defer { C.witty_ct_release(values) }
			mut ital_seen := false
			for i in 0 .. C.witty_ct_variation_count(axes) {
				mut name_buf := []u8{len: 1024}
				mut value := f64(0)
				assert unsafe {
					C.witty_ct_variation_get(axes, values, i, &name_buf[0], usize(name_buf.len),
						&value)
				} != 0
				name := unsafe { cstring_to_vstring(&char(name_buf.data)) }
				if name == 'wght' {
					is_bold = value > 600
					continue
				}
				if name == 'ital' {
					is_italic = value > 0.5
					ital_seen = true
					continue
				}
				if !ital_seen && name == 'slnt' {
					is_italic = value <= -5.0
				}
			}
		}
	}

	mut style_buf := []u8{len: 128}
	style_str := if unsafe {
		C.witty_ct_descriptor_style_name(ct_desc, &style_buf[0], usize(style_buf.len))
	} != 0 {
		unsafe { cstring_to_vstring(&char(style_buf.data)) }
	} else {
		''
	}

	mut desired_styles := []string{}
	if style := desc.style {
		desired_styles << style
	} else if desc.bold {
		if desc.italic {
			desired_styles = ['bold italic', 'bold', 'italic', 'oblique']
		} else {
			desired_styles = ['bold', 'upright']
		}
	} else if desc.italic {
		desired_styles = ['italic', 'regular', 'oblique']
	} else {
		desired_styles = ['regular', 'upright']
	}

	exact_style := ascii.eql_ignore_case(style_str, desired_styles[0])
	mut fuzzy_style := u8(style_str.len)
	for desired in desired_styles {
		if ascii.index_of_ignore_case(style_str, desired) != none {
			fuzzy_style = if int(fuzzy_style) > desired.len {
				fuzzy_style - u8(desired.len)
			} else {
				u8(0)
			}
		}
	}
	fuzzy_style = u8(255) - fuzzy_style

	return Score.init(glyph_count, fuzzy_style, desc.bold == is_bold, desc.italic == is_italic,
		exact_style, monospace, has_codepoint)
}

fn score_head_table(face CoreTextFace) ?opentype.Head {
	data := face.copy_table('head') or { return none }
	return opentype.Head.init(data) or {
		log.warn('error parsing head table: ${err}')
		return none
	}
}

fn score_os2_table(face CoreTextFace) ?opentype.OS2 {
	data := face.copy_table('OS/2') or { return none }
	return opentype.OS2.init(data) or {
		log.warn('error parsing OS/2 table: ${err}')
		return none
	}
}

// discover_fallback finds fallback fonts for a codepoint.
pub fn (ct &CoreTextDiscovery) discover_fallback(mut collection Collection, desc Descriptor) !CtDiscoverIterator {
	// If we have a codepoint within the CJK unified ideographs block then we
	// fall back to macOS to find a font that supports it because there isn't
	// a better way manually with CoreText that properly takes into account
	// system locale.
	//
	// References:
	// - http://unicode.org/charts/PDF/U4E00.pdf
	// - https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/platform/fonts/LocaleInFonts.md#unified-han-ideographs
	if desc.codepoint >= 0x4E00 && desc.codepoint <= 0x9FFF {
		han := ct.discover_codepoint(mut collection, desc)!
		if han.has_value {
			return CtDiscoverIterator{
				list:       [han.descriptor]
				variations: desc.variations
				i:          0
			}
		}
	}

	mut it := ct.discover(desc)!

	// If our normal discovery doesn't find anything and we have a specific
	// codepoint, then fall back to CTFontCreateForString to find a matching
	// font that CoreText wants to use.
	// See: https://github.com/ghostty-org/ghostty/issues/2499
	if it.list.len == 0 && desc.codepoint > 0 {
		ct_desc := ct.discover_codepoint(mut collection, desc)!
		if ct_desc.has_value {
			return CtDiscoverIterator{
				list:       [ct_desc.descriptor]
				variations: desc.variations
				i:          0
			}
		}
	}

	return it
}

// CtDescriptorValue preserves Ghostty's fallible optional descriptor result.
// V cannot nest an Option inside a Result, so has_value represents the
// optional layer while the containing Result preserves face-load failures.
struct CtDescriptorValue {
	has_value  bool
	descriptor voidptr
}

// discover_codepoint discovers a font for a specific codepoint using the
// CoreText CTFontCreateForString API, starting from the active collection face
// that best matches the descriptor's requested style. Returns a retained
// descriptor or none.
fn (ct &CoreTextDiscovery) discover_codepoint(mut collection Collection, desc Descriptor) !CtDescriptorValue {
	_ = ct
	assert desc.codepoint > 0

	// The order matters: prefer an exact style, then progressively fall back
	// to the primary regular face.
	mut styles := []Style{}
	if desc.bold && desc.italic {
		styles << .bold_italic
	}
	if desc.bold {
		styles << .bold
	}
	if desc.italic {
		styles << .italic
	}
	styles << .regular

	mut seed_font := voidptr(unsafe { nil })
	for style in styles {
		if collection.face_count(style) == 0 {
			continue
		}
		// Ghostty uses `try collection.getFace` here. Once a requested style
		// has entries, failure to load its primary face must not silently fall
		// through to a different style.
		face := collection.get_face(Index.init(style, 0))!
		if !isnil(face.ct_font) {
			seed_font = face.ct_font
			break
		}
	}
	if isnil(seed_font) {
		return CtDescriptorValue{}
	}

	encoded := rune(desc.codepoint).str()
	str := macos.CFString.create_with_bytes(encoded.bytes(), .utf8, false)!
	defer { str.release() }

	mut unichars := []u16{len: 2}
	pair := macos.string_get_surrogate_pair_for_long_character(desc.codepoint,
		mut unichars)
	range_len := if pair { 2 } else { 1 }
	original := unsafe { &macos.CTFont(seed_font) }
	fallback := original.create_for_string(str, macos.CFRange.init(0, range_len)) or {
		return CtDescriptorValue{}
	}
	defer { fallback.release() }

	postscript_name := fallback.copy_post_script_name()!
	defer { postscript_name.release() }
	mut name_buf := []u8{len: 64}
	if name_ptr := postscript_name.cstring(mut name_buf, .utf8) {
		if unsafe { cstring_to_vstring(name_ptr) } == 'LastResort' {
			return CtDescriptorValue{}
		}
	}

	out := fallback.copy_descriptor()!
	return CtDescriptorValue{
		has_value:  true
		descriptor: voidptr(out)
	}
}

// CtDiscoverIterator iterates over CoreText discovery results.
pub struct CtDiscoverIterator {
pub mut:
	list       []voidptr // []&macos.CTFontDescriptor
	variations []Variation
	i          int
}

// deinit releases the iterator resources.
pub fn (mut it CtDiscoverIterator) deinit() {
	for d in it.list {
		if !isnil(d) {
			C.witty_ct_release(d)
		}
	}
	it.list = []voidptr{}
}

// next returns the next deferred face or an empty value when exhausted.
pub fn (mut it CtDiscoverIterator) next() !DeferredFaceValue {
	if it.i >= it.list.len {
		return DeferredFaceValue{}
	}
	src := it.list[it.i]

	// Get our descriptor. We remove the character-set limitation because we
	// may have used it to filter, but we don't want it anymore because it
	// would restrict the characters available on the loaded font.
	desc := C.witty_ct_descriptor_drop_charset(src)
	if isnil(desc) {
		return error('CoreText: failed to copy font descriptor')
	}
	defer { C.witty_ct_release(desc) }

	// Retain the discovered CTFont. File lookup is deferred until a
	// FreeType-backed render face is actually requested.
	descriptor := unsafe { &macos.CTFontDescriptor(desc) }
	font_ptr := voidptr(macos.CTFont.create_with_descriptor(descriptor, 12)!)
	it.i++
	return DeferredFaceValue{
		has_value: true
		face:      DeferredFace{
			coretext: CoreTextDeferredFace{
				ct_font:    font_ptr
				variations: it.variations.clone()
			}
		}
	}
}

// ============================================================
// Score (for CoreText result sorting)
// ============================================================
