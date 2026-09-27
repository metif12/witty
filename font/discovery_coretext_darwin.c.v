module font

// CoreText discovery (discovery.zig's CoreText and Descriptor.toCoreTextDescriptor),
// compiled only for Darwin where the CoreText font backend is selected.
import macos

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
	style_ptr := if s := desc.style { &char(s.str) } else { &char(unsafe { nil }) }
	style_len := if s := desc.style { usize(s.len) } else { usize(0) }
	list.sort_with_compare(fn [desc, style_ptr, style_len] (a &voidptr, b &voidptr) int {
		lhs := C.witty_ct_score(style_ptr, style_len, desc.codepoint, b2i(desc.bold),
			b2i(desc.italic), *a)
		rhs := C.witty_ct_score(style_ptr, style_len, desc.codepoint, b2i(desc.bold),
			b2i(desc.italic), *b)
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

	// Ask CoreText for a font that can render this codepoint (skipping the
	// LastResort font). Returns a retained descriptor.
	out := C.witty_ct_font_for_string(seed_font, desc.codepoint)
	if isnil(out) {
		return CtDescriptorValue{}
	}
	return CtDescriptorValue{
		has_value:  true
		descriptor: out
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
	font_ptr := C.witty_ct_font_from_descriptor(desc, 12.0)
	if isnil(font_ptr) {
		return error('CoreText: failed to create font')
	}
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
