module font

// --- Original Ghostty Comments Start: src/font/discovery.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/font/discovery.zig
//
// Discover implementation for the compile options.
// Descriptor is used to search for fonts. The only required field
// is "family". The rest are ignored unless they're set to a non-zero
// value.
// Font family to search for. This can be a fully qualified font
// name such as "Fira Code", "monospace", "serif", etc. Memory is
// owned by the caller and should be freed when this descriptor
// is no longer in use. The discovery structs will never store the
// descriptor.
//
// On systems that use fontconfig (Linux), this can be a full
// fontconfig pattern, such as "Fira Code-14:bold".
// Specific font style to search for. This will filter the style
// string the font advertises. The "bold/italic" booleans later in this
// struct filter by the style trait the font has, not the string, so
// these can be used in conjunction or not.
// A codepoint that this font must be able to render.
// Font size in points that the font should support. For conversion
// to pixels, we will use 72 DPI for Mac and 96 DPI for everything else.
// (If pixel conversion is necessary, i.e. emoji fonts)
// True if we want to search specifically for a font that supports
// specific styles.
// Variation axes to apply to the font. This also impacts searching
// for fonts since fonts with the ability to set these variations
// will be preferred, but not guaranteed.
// Hash the descriptor with the given hasher.
// This is not correct, but we don't currently depend on the
// hash value being different based on decimal values of variations.
// Returns a hash code that can be used to uniquely identify this
// action.
// Deep copy of the struct. The given allocator is expected to
// be an arena allocator of some sort since the descriptor
// itself doesn't support fine-grained deallocation of fields.
// We can't do any errdefer cleanup in here. As documented we
// expect the allocator to be an arena so any errors should be
// cleaned up somewhere else.
// Convert to Fontconfig pattern to use for lookup. The pattern does
// not have defaults filled/substituted (Fontconfig thing) so callers
// must still do this.
// For fontconfig, we always add monospace in the pattern. Since
// fontconfig sorts by closeness to the pattern, this doesn't fully
// exclude non-monospace but helps prefer it.
// Convert to Core Text font descriptor to use for lookup or
// conversion to a specific font.
// Family
// Style
// Codepoint support
// Set our size attribute if set
// Build our traits. If we set any, then we store it in the attributes
// otherwise we do nothing. We determine this by setting up the packed
// struct, converting to an int, and checking if it is non-zero.
// Setting traits is a pain. We have to create a nested dictionary
// of the symbolic traits value, and set that in our attributes.
// safe to call multiple times and concurrently
// Discover fonts from a descriptor. This returns an iterator that can
// be used to build up the deferred fonts.
// Build our pattern that we'll search for
// Search
// Get the copied pattern from our fontset that has the
// attributes configured for rendering.
// Increment after we return
// Required for the "interface" but does nothing for CoreText.
// Discover fonts from a descriptor. This returns an iterator that can
// be used to build up the deferred fonts.
// Build our pattern that we'll search for
// Our descriptors have to be in an array
// Build our collection
// Sort our descriptors
// If we have a codepoint within the CJK unified ideographs block
// then we fallback to macOS to find a font that supports it because
// there isn't a better way manually with CoreText that I can find that
// properly takes into account system locale.
//
// References:
// - http://unicode.org/charts/PDF/U4E00.pdf
// - https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/platform/fonts/LocaleInFonts.md#unified-han-ideographs
// This is silly but our discover iterator needs a slice so
// we allocate here. This isn't a performance bottleneck but
// this is something we can optimize very easily...
// If our normal discovery doesn't find anything and we have a specific
// codepoint, then fallback to using CTFontCreateForString to find a
// matching font CoreText wants to use. See:
// https://github.com/ghostty-org/ghostty/issues/2499
// Discover a font for a specific codepoint using the CoreText
// CTFontCreateForString API.
// If we have freetype, we can't use CoreText to find a font
// that supports a specific codepoint because we need to
// have a CoreText font to be able to do so.
// Get our original font. This is dependent on the requested style
// from the descriptor.
// In all the styles below, we try to match it but if we don't
// we always fall back to some other option. The order matters
// here.
// We need it in utf8 format
// We need a CFString
// Get our range length for CTFontCreateForString. It looks like
// the range uses UTF-16 codepoints and not UTF-32 codepoints.
// Get our font
// Do not allow the last resort font to go through. This is the
// last font used by CoreText if it can't find anything else and
// only contains replacement characters.
// If the name doesn't fit in our buffer, then it can't
// be the last resort font so we break out.
// If the name is "LastResort" then we don't want to use it.
// Get the descriptor
// We need to retain because once the list is freed it will
// release all its members.
// Higher score is "less" (earlier)
// We represent our sorting score as a packed struct so that we
// can compare scores numerically but build scores symbolically.
//
// Note that packed structs store their fields from least to most
// significant, so the fields here are defined in increasing order
// of precedence.
// Number of glyphs in the font, if two fonts have identical
// scores otherwise then we prefer the one with more glyphs.
//
// (Number of glyphs clamped at u16 intmax)
// A fuzzy match on the style string, less important than
// an exact match, and less important than trait matches.
// Whether the bold-ness of the font matches the descriptor.
// This is less important than italic because a font that's italic
// when it shouldn't be or not italic when it should be is a bigger
// problem (subjectively) than being the wrong weight.
// Whether the italic-ness of the font matches the descriptor.
// This is less important than an exact match on the style string
// because we want users to be allowed to override trait matching
// for the bold/italic/bold italic styles if they want.
// An exact (case-insensitive) match on the style string.
// Whether the font is monospace, this is more important than any of
// the other fields unless we're looking for a specific codepoint,
// in which case that is the most important thing.
// If we're looking for a codepoint, whether this font has it.
// We always load the font if we can since some things can only be
// inspected on the font itself. Fonts that can't be loaded score
// 0 automatically because we don't want a font we can't load.
// We prefer fonts with more glyphs, all else being equal.
// If we're searching for a codepoint, then we
// prioritize fonts that have that codepoint.
// Turn UTF-32 into UTF-16 for CT API
// Get our glyphs
// Get our symbolic traits for the descriptor so we can
// compare boolean attributes like bold, monospace, etc.
// We try to derived data from the font itself, which is generally
// more reliable than only using the symbolic traits for this.
// We start with initial guesses based on the symbolic traits,
// but refine these with more information if we can get it.
// Read the 'head' table out of the font data if it's available.
// Read the 'OS/2' table out of the font data if it's available.
// Check if we have variation axes in our descriptor, if we
// do then we can derive weight italic-ness or both from them.
// Copy the variation values for this instance of the font.
// if there are none then we just break out immediately.
// If we see the 'ital' value then we ignore 'slnt'.
// Default value
// Value in this font
// Somewhat subjective threshold, we consider fonts
// bold if they have a 'wght' set greater than 600.
// Arbitrary threshold of anything more than a 5
// degree clockwise slant is considered italic.
// Get the style string from the font.
// The first string in this slice will be used for the exact match,
// and for the fuzzy match, all matching substrings will increase
// the rank.
// If we don't have an explicitly desired style name, we base
// it on the bold and italic properties, this isn't ideal since
// fonts may use style names other than these, but it helps in
// some edge cases.
// Our "fuzzy match" score is 0 if the desired style isn't present
// in the string, otherwise we give higher priority for styles that
// have fewer characters not in the desired_styles list.
// Get our descriptor. We need to remove the character set
// limitation because we may have used that to filter but we
// don't want it anymore because it'll restrict the characters
// available.
// We create a copy, overwriting the character set attribute.
// Create our font. We need a size to initialize it so we use size
// 12 but we will alter the size later.
// Increment after we return
// The first result should have the codepoint. Later ones may not
// because fontconfig returns all fonts sorted.
// Should have other codepoints too
// The first result should have the codepoint. Later ones may not
// because fontconfig returns all fonts sorted.
// Should have other codepoints too
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!//
// FIXME: Disabled for now because SF Pro is not available in CI
//        The solution likely involves directly testing that the
//        `sortMatchingDescriptors` function sorts a bundled test
//        font correctly, instead of relying on the system fonts.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!//
// We try to get a Regular, Italic, Bold, & Bold Italic version of SF Pro,
// which should be installed on all Macs, and has many styles which makes
// it a good test, since there will be many results for each discovery.
// Regular
// Regular Italic
//
// NOTE: This makes sure that we don't accidentally prefer "Thin Italic",
//       which we previously did, because it has a shorter name.
// Bold
// Bold Italic
//
// --- Original Ghostty Comments End: src/font/discovery.zig

// Font discovery system for finding fonts on the system.
//
// Supports two backends:
//   - Fontconfig (Linux): uses libfontconfig for font matching
//   - CoreText (macOS): uses Apple's CoreText framework
//
// The primary type is Descriptor, which specifies search criteria.
// Discovery implementations use the descriptor to find and iterate
// over matching fonts.
//
// Translated from ghostty/src/font/discovery.zig

import fontconfig
import math
import macos
import opentype as _

// CoreText discovery/scoring helpers implemented in the C shim header.
// See font/coretext_shims.h. These are only functional on macOS; on other
// platforms they return null/zero.
#include "coretext_shims.h"

fn C.witty_ct_release(ptr voidptr)

fn C.witty_ct_retain(ptr voidptr)

fn C.witty_ct_build_descriptor(family &char, style &char, codepoint u32, size f64, bold int, italic int, monospace int) voidptr

fn C.witty_ct_matching_descriptors(search_desc voidptr) voidptr

fn C.witty_cf_array_count(arr voidptr) int

fn C.witty_cf_array_get(arr voidptr, i int) voidptr

fn C.witty_ct_score(desired_style &char, desired_style_len usize, codepoint u32, want_bold int, want_italic int, candidate_desc voidptr) u64

fn C.witty_ascii_eql_ignore_case(lhs &char, lhs_len usize, rhs &char, rhs_len usize) int

fn C.witty_ascii_index_of_ignore_case(haystack &char, haystack_len usize, needle &char, needle_len usize) int

fn C.witty_ct_descriptor_drop_charset(desc voidptr) voidptr

fn C.witty_ct_descriptor_path(desc voidptr, buf &u8, len usize) int

fn C.witty_ct_font_from_descriptor(desc voidptr, size f64) voidptr

fn C.witty_coretext_copy_family_name(font_ptr voidptr, buf &u8, len usize) int

fn C.witty_coretext_copy_display_name(font_ptr voidptr, buf &u8, len usize) int

fn C.witty_ct_font_for_string(orig_font voidptr, codepoint u32) voidptr

fn C.witty_ct_descriptor_is_color(desc voidptr) int

fn C.witty_coretext_release(ptr voidptr)

// ============================================================
// Descriptor
// ============================================================

// Descriptor is used to search for fonts. The only required field
// is "family". The rest are ignored unless they're set to a non-zero
// value.
pub struct Descriptor {
pub mut:
	// Font family to search for. This can be a fully qualified font
	// name such as "Fira Code", "monospace", "serif", etc. Memory is
	// owned by the caller and should be freed when this descriptor
	// is no longer in use. The discovery structs will never store the
	// descriptor.
	//
	// On systems that use fontconfig (Linux), this can be a full
	// fontconfig pattern, such as "Fira Code-14:bold".
	family ?string

	// Specific font style to search for. This will filter the style
	// string the font advertises. The "bold/italic" booleans later in this
	// struct filter by the style trait the font has, not the string, so
	// these can be used in conjunction or not.
	style ?string

	// A codepoint that this font must be able to render.
	codepoint u32

	// Font size in points that the font should support. For conversion
	// to pixels, we will use 72 DPI for Mac and 96 DPI for everything else.
	// (If pixel conversion is necessary, i.e. emoji fonts)
	size f32

	// True if we want to search specifically for a font that supports
	// specific styles.
	bold      bool
	italic    bool
	monospace bool

	// Variation axes to apply to the font. This also impacts searching
	// for fonts since fonts with the ability to set these variations
	// will be preferred, but not guaranteed.
	variations []Variation
}

// hashcode returns a hash code that can be used to uniquely identify
// this descriptor.
pub fn (d &Descriptor) hashcode() u64 {
	mut hasher := SourceHash{}
	d.hash_into(mut hasher)
	return hasher.final()
}

// hash_into hashes every field in Ghostty's Descriptor.hash order.
fn (d &Descriptor) hash_into(mut hasher SourceHash) {
	hasher.put_optional_string(d.family)
	hasher.put_optional_string(d.style)
	hasher.put_u32(d.codepoint)
	hasher.put_f32(d.size)
	hasher.put_bool(d.bold)
	hasher.put_bool(d.italic)
	hasher.put_bool(d.monospace)
	hasher.put_u64(u64(d.variations.len))
	for variation in d.variations {
		hasher.put_u32(variation.id.value)

		// This intentionally matches Ghostty: decimal variation values are
		// truncated before hashing because callers don't depend on them.
		hasher.put_i64(i64(variation.value))
	}
}

// clone creates a deep copy of the descriptor.
// In V, strings are value types so this is straightforward.
pub fn (d &Descriptor) clone() Descriptor {
	return Descriptor{
		family: d.family
		style: d.style
		codepoint: d.codepoint
		size: d.size
		bold: d.bold
		italic: d.italic
		monospace: d.monospace
		variations: d.variations.clone()
	}
}

// to_fc_pattern converts the descriptor to a fontconfig pattern
// for font lookup. The pattern does not have defaults
// filled/substituted (fontconfig thing) so callers must still do this.
pub fn (d &Descriptor) to_fc_pattern() &fontconfig.Pattern {
	// Build the fontconfig pattern from our descriptor fields.
	pat := fontconfig.Pattern.create()
	if f := d.family {
		pat.add(.family, fontconfig.PatternValue{ string: f }, false)
	}
	if s := d.style {
		pat.add(.style, fontconfig.PatternValue{ string: s }, false)
	}
	if d.codepoint > 0 {
		cs := fontconfig.CharSet.create()
		defer { cs.destroy() }
		cs.add_char(d.codepoint)
		pat.add(.charset, fontconfig.PatternValue{ char_set: cs }, false)
	}
	if d.size > 0 {
		pat.add(
			.size,
			fontconfig.PatternValue{ integer: int(math.round(d.size)) },
			false,
		)
	}
	if d.bold {
		pat.add(
			.weight,
			fontconfig.PatternValue{ integer: int(fontconfig.Weight.bold) },
			false,
		)
	}
	if d.italic {
		pat.add(
			.slant,
			fontconfig.PatternValue{ integer: int(fontconfig.Slant.italic) },
			false,
		)
	}

	// For fontconfig, we always add monospace in the pattern. Since
	// fontconfig sorts by closeness to the pattern, this doesn't fully
	// exclude non-monospace but helps prefer it.
	pat.add(
		.spacing,
		fontconfig.PatternValue{ integer: int(fontconfig.Spacing.mono) },
		false,
	)

	return pat
}

// to_coretext_descriptor converts the descriptor to a CoreText font
// descriptor for font lookup or conversion to a specific font.
//
// Builds a CTFontDescriptor from our fields (family, style, codepoint
// character set, size and symbolic traits) via the C shim. The returned
// descriptor is retained; callers must release it with macos.cf_release.
pub fn (d &Descriptor) to_coretext_descriptor() !&macos.CTFontDescriptor {
	family := d.family or { '' }
	style := d.style or { '' }
	ptr := C.witty_ct_build_descriptor(&char(family.str), &char(style.str), d.codepoint, f64(d.size), b2i(d.bold), b2i(d.italic), b2i(d.monospace))
	if isnil(ptr) {
		return error('CTFontDescriptorCreateWithAttributes failed')
	}
	return unsafe { &macos.CTFontDescriptor(ptr) }
}

// b2i converts a bool to a C-style 0/1 int.
fn b2i(b bool) int {
	return if b { 1 } else { 0 }
}

// ============================================================
// FontconfigDiscovery
// ============================================================

// FontconfigDiscovery discovers fonts using the fontconfig library (Linux).
pub struct FontconfigDiscovery {
pub mut:
	fc_config fontconfig.Config
}

// init creates a new FontconfigDiscovery instance.
pub fn FontconfigDiscovery.init() FontconfigDiscovery {
	// safe to call multiple times and concurrently
	fontconfig.fc_init()
	return FontconfigDiscovery{
		fc_config: fontconfig.init_load_config_and_fonts()
	}
}

// deinit releases resources.
pub fn (mut fd FontconfigDiscovery) deinit() {
	fd.fc_config.destroy()
}

// discover finds fonts matching the descriptor. Returns an iterator
// that can be used to build up the deferred fonts.
pub fn (fd &FontconfigDiscovery) discover(desc Descriptor) !FcDiscoverIterator {
	// Build our pattern that we'll search for
	pat := desc.to_fc_pattern()

	fd.fc_config.substitute_with_pat(pat, .pattern)
	pat.default_substitute()

	// Search
	res := fd.fc_config.font_sort(pat, false, unsafe { nil })
	if res.result != .match_ {
		return error('fontconfig: font sort failed')
	}

	return FcDiscoverIterator{
		config: fd.fc_config
		pattern: pat
		set: res.fs
		fonts: res.fs.fonts()
		variations: desc.variations
		codepoint: desc.codepoint
		i: 0
	}
}

// discover_fallback is like discover but for fallback font discovery.

pub fn (fd &FontconfigDiscovery) discover_fallback(mut collection Collection, desc Descriptor) !FcDiscoverIterator {
	_ = collection
	return fd.discover(desc)!
}

// FcDiscoverIterator iterates over fontconfig discovery results.
pub struct FcDiscoverIterator {
pub mut:
	config     fontconfig.Config
	pattern    &fontconfig.Pattern = unsafe { nil }
	set        &fontconfig.FontSet = unsafe { nil }
	fonts      []&fontconfig.Pattern
	variations []Variation
	codepoint  u32
	i          int
}

// deinit releases the iterator resources.
pub fn (mut it FcDiscoverIterator) deinit() {
	if it.set != unsafe { nil } {
		it.set.destroy()
	}
	if it.pattern != unsafe { nil } {
		it.pattern.destroy()
	}
}

// next returns the next deferred face, or none if exhausted.
pub fn (mut it FcDiscoverIterator) next() ?DeferredFace {
	for it.i < it.fonts.len {
		candidate := it.fonts[it.i]
		it.i++
		font_pattern := it.config.font_render_prepare(it.pattern, candidate) or {
			continue
		}
		path := font_pattern.file() or {
			font_pattern.destroy()
			continue
		}
		family := font_pattern.get(.family, 0) or { fontconfig.PatternValue{} }
		full_name := font_pattern.get(.fullname, 0) or { fontconfig.PatternValue{} }
		idx := font_pattern.index()
		is_emoji := font_pattern.is_emoji()
		has_requested := it.codepoint == 0 || font_pattern.has_char(it.codepoint)
		font_pattern.destroy()

		mut coverage := map[u32]bool{}
		if it.codepoint > 0 {
			coverage[it.codepoint] = has_requested
		}
		return DeferredFace{
			family_name: family.string
			full_name: if full_name.string.len > 0 { full_name.string } else { family.string }
			path: path
			face_index: i32(idx)
			codepoints: coverage
			presentation: if is_emoji { Presentation.emoji } else { Presentation.text }
			variations: it.variations.clone()
		}
	}
	return none
}

// ============================================================
// CoreTextDiscovery
// ============================================================

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
	ct_desc := desc.to_coretext_descriptor()!
	defer {
		macos.cf_release(voidptr(ct_desc))
	}

	// Build our collection and grab the matching descriptors (a CFArray).
	list := C.witty_ct_matching_descriptors(voidptr(ct_desc))
	defer {
		if !isnil(list) {
			C.witty_ct_release(list)
		}
	}

	// Copy the matching descriptors into a V slice, retaining each so they
	// survive the release of the CFArray, then sort by score.
	mut zig_list := copy_matching_descriptors(list)
	sort_matching_descriptors(desc, mut zig_list)

	return CtDiscoverIterator{
		list: zig_list
		variations: desc.variations
		codepoint: desc.codepoint
		i: 0
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
		lhs := C.witty_ct_score(style_ptr, style_len, desc.codepoint, b2i(desc.bold), b2i(desc.italic), *a)
		rhs := C.witty_ct_score(style_ptr, style_len, desc.codepoint, b2i(desc.bold), b2i(desc.italic), *b)
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
		if han := ct.discover_codepoint(mut collection, desc) {
			return CtDiscoverIterator{
				list: [han]
				variations: desc.variations
				codepoint: desc.codepoint
				i: 0
			}
		}
	}

	mut it := ct.discover(desc)!

	// If our normal discovery doesn't find anything and we have a specific
	// codepoint, then fall back to CTFontCreateForString to find a matching
	// font that CoreText wants to use.
	// See: https://github.com/ghostty-org/ghostty/issues/2499
	if it.list.len == 0 && desc.codepoint > 0 {
		if ct_desc := ct.discover_codepoint(mut collection, desc) {
			return CtDiscoverIterator{
				list: [ct_desc]
				variations: desc.variations
				codepoint: desc.codepoint
				i: 0
			}
		}
	}

	return it
}

// discover_codepoint discovers a font for a specific codepoint using the
// CoreText CTFontCreateForString API, starting from the active collection face
// that best matches the descriptor's requested style. Returns a retained
// descriptor or none.
fn (ct &CoreTextDiscovery) discover_codepoint(mut collection Collection, desc Descriptor) ?voidptr {
	if desc.codepoint == 0 {
		return none
	}

	// The order matters: prefer an exact style, then progressively fall back
	// to the primary regular face.
	mut styles := []FontStyle{}
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
		face := collection.get_face(Index{
			style: style
			idx: 0
		}) or { continue }
		if !isnil(face.ct_font) {
			seed_font = face.ct_font
			break
		}
	}
	if isnil(seed_font) {
		return none
	}

	// Ask CoreText for a font that can render this codepoint (skipping the
	// LastResort font). Returns a retained descriptor.
	out := C.witty_ct_font_for_string(seed_font, desc.codepoint)
	if isnil(out) {
		return none
	}
	return out
}

// CtDiscoverIterator iterates over CoreText discovery results.
pub struct CtDiscoverIterator {
pub mut:
	list       []voidptr // []&macos.CTFontDescriptor
	variations []Variation
	codepoint  u32
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

// next returns the next deferred face, or none if exhausted.
pub fn (mut it CtDiscoverIterator) next() ?DeferredFace {
	for it.i < it.list.len {
		src := it.list[it.i]
		it.i++

		// Get our descriptor. We remove the character-set limitation because we
		// may have used it to filter, but we don't want it anymore because it
		// would restrict the characters available on the loaded font.
		desc := C.witty_ct_descriptor_drop_charset(src)
		if isnil(desc) {
			continue
		}

		// Ghostty stores the CTFont directly in the DeferredFace here. This V
		// port's DeferredFace is file-path based, so we resolve the descriptor's
		// font file path (and index defaults to 0 for CoreText descriptors).
		mut buf := []u8{len: 1024}
		if C.witty_ct_descriptor_path(desc, &u8(buf.data), usize(buf.len)) == 0 {
			// No file path available for this descriptor; skip to the next.
			C.witty_ct_release(desc)
			continue
		}
		path := unsafe { cstring_to_vstring(&char(buf.data)) }
		is_color := C.witty_ct_descriptor_is_color(desc) != 0
		family_name, full_name := coretext_descriptor_names(desc)
		C.witty_ct_release(desc)

		mut coverage := map[u32]bool{}
		if it.codepoint > 0 {
			coverage[it.codepoint] = true
		}
		return DeferredFace{
			family_name: family_name
			full_name: full_name
			path: path
			face_index: 0
			codepoints: coverage
			presentation: if is_color { Presentation.emoji } else { Presentation.text }
			variations: it.variations.clone()
		}
	}
	return none
}

fn coretext_descriptor_names(desc voidptr) (string, string) {
	font_ptr := C.witty_ct_font_from_descriptor(desc, 12.0)
	if isnil(font_ptr) {
		return '', ''
	}
	defer {
		C.witty_ct_release(font_ptr)
	}
	mut family_buf := []u8{len: 1024}
	mut display_buf := []u8{len: 1024}
	family := if C.witty_coretext_copy_family_name(font_ptr, &u8(family_buf.data), usize(family_buf.len)) != 0 {
		unsafe { cstring_to_vstring(&char(family_buf.data)) }
	} else {
		''
	}
	display := if C.witty_coretext_copy_display_name(font_ptr, &u8(display_buf.data), usize(display_buf.len)) != 0 {
		unsafe { cstring_to_vstring(&char(display_buf.data)) }
	} else {
		family
	}
	return family, display
}

// Discover selects the native discovery backend used by the target build.
pub struct Discover {
mut:
	backend DiscoverBackend
	fc      FontconfigDiscovery
	ct      CoreTextDiscovery
}

enum DiscoverBackend {
	fontconfig
	coretext
}

pub fn Discover.init() !Discover {
	$if macos {
		return Discover{
			backend: .coretext
			ct: CoreTextDiscovery.init()
		}
	} $else {
		return Discover{
			backend: .fontconfig
			fc: FontconfigDiscovery.init()
		}
	}
}

pub fn (mut d Discover) deinit() {
	match d.backend {
		.fontconfig { d.fc.deinit() }
		.coretext { d.ct.deinit() }
	}
}

pub fn (d &Discover) discover(desc Descriptor) !DiscoverIterator {
	return match d.backend {
		.fontconfig {
			DiscoverIterator{
				backend: .fontconfig
				fc: d.fc.discover(desc)!
			}
		}
		.coretext {
			DiscoverIterator{
				backend: .coretext
				ct: d.ct.discover(desc)!
			}
		}
	}
}

pub fn (d &Discover) discover_fallback(mut collection Collection, desc Descriptor) !DiscoverIterator {
	return match d.backend {
		.fontconfig {
			DiscoverIterator{
				backend: .fontconfig
				fc: d.fc.discover_fallback(mut collection, desc)!
			}
		}
		.coretext {
			DiscoverIterator{
				backend: .coretext
				ct: d.ct.discover_fallback(mut collection, desc)!
			}
		}
	}
}

pub struct DiscoverIterator {
mut:
	backend DiscoverBackend
	fc      FcDiscoverIterator
	ct      CtDiscoverIterator
}

pub fn (mut it DiscoverIterator) deinit() {
	match it.backend {
		.fontconfig { it.fc.deinit() }
		.coretext { it.ct.deinit() }
	}
}

pub fn (mut it DiscoverIterator) next() ?DeferredFace {
	return match it.backend {
		.fontconfig { it.fc.next() }
		.coretext { it.ct.next() }
	}
}

// ============================================================
// Score (for CoreText result sorting)
// ============================================================

// Score represents the sorting score for font discovery results.
// It is used as a packed integer so that scores can be compared
// numerically but built symbolically.
//
// The fields are defined in increasing order of precedence
// (least significant to most significant in the packed integer).
pub struct Score {
pub mut:
	// Number of glyphs in the font, if two fonts have identical
	// scores otherwise then we prefer the one with more glyphs.
	// (Number of glyphs clamped at u16 max)
	glyph_count u16
	// A fuzzy match on the style string, less important than
	// an exact match, and less important than trait matches.
	fuzzy_style u8
	// Whether the bold-ness of the font matches the descriptor.
	// This is less important than italic because a font that's italic
	// when it shouldn't be or not italic when it should be is a bigger
	// problem (subjectively) than being the wrong weight.
	bold bool
	// Whether the italic-ness of the font matches the descriptor.
	// This is less important than an exact match on the style string
	// because we want users to be allowed to override trait matching
	// for the bold/italic/bold italic styles if they want.
	italic bool
	// An exact (case-insensitive) match on the style string.
	exact_style bool
	// Whether the font is monospace, this is more important than any of
	// the other fields unless we're looking for a specific codepoint,
	// in which case that is the most important thing.
	monospace bool
	// If we're looking for a codepoint, whether this font has it.
	codepoint bool
}

// to_int converts the score to an integer for comparison.
// Higher scores are "better" (should sort earlier).
// Fields are packed from least to most significant.
pub fn (s Score) to_int() u64 {
	mut result := u64(s.glyph_count)
	result |= u64(s.fuzzy_style) << 16
	result |= u64(if s.bold { 1 } else { 0 }) << 24
	result |= u64(if s.italic { 1 } else { 0 }) << 25
	result |= u64(if s.exact_style { 1 } else { 0 }) << 26
	result |= u64(if s.monospace { 1 } else { 0 }) << 27
	result |= u64(if s.codepoint { 1 } else { 0 }) << 28
	return result
}

// from_int unpacks a packed integer score into a Score struct.
pub fn Score.from_int(v u64) Score {
	return Score{
		glyph_count: u16(v & 0xFFFF)
		fuzzy_style: u8((v >> 16) & 0xFF)
		bold: (v >> 24) & 1 == 1
		italic: (v >> 25) & 1 == 1
		exact_style: (v >> 26) & 1 == 1
		monospace: (v >> 27) & 1 == 1
		codepoint: (v >> 28) & 1 == 1
	}
}

// score computes the sorting Score for a candidate CoreText descriptor
// against the given search descriptor. This mirrors ghostty's Score.score():
// it loads the font (fonts that can't be loaded score 0), prefers more
// glyphs, prioritizes codepoint coverage, and matches bold/italic/monospace
// traits and the style string.
//
// The heavy lifting (loading the font, reading symbolic and OpenType traits,
// variation axes, glyph coverage, and style-string fuzzy matching) is done in
// the C shim since it needs the CoreText framework; here we unpack the packed
// score into its symbolic fields.
pub fn Score.score(desc &Descriptor, ct_desc voidptr) Score {
	style_ptr := if s := desc.style { &char(s.str) } else { &char(unsafe { nil }) }
	style_len := if s := desc.style { usize(s.len) } else { usize(0) }
	v := C.witty_ct_score(style_ptr, style_len, desc.codepoint, b2i(desc.bold), b2i(desc.italic), ct_desc)
	return Score.from_int(v)
}

// Note: DeferredFace is defined in face.v
