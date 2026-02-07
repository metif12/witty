module font

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
	mut state := u64(0)

	// Hash family string
	if f := d.family {
		for b in f.bytes() {
			state = state * 31 + u64(b)
		}
	}
	state = state * 31 + 1 // separator

	// Hash style string
	if s := d.style {
		for b in s.bytes() {
			state = state * 31 + u64(b)
		}
	}
	state = state * 31 + 2 // separator

	state = state * 31 + u64(d.codepoint)

	// Hash size as integer bits
	state = state * 31 + u64(u32(d.size * 1000.0))

	state = state * 31 + u64(if d.bold { 1 } else { 0 })
	state = state * 31 + u64(if d.italic { 1 } else { 0 })
	state = state * 31 + u64(if d.monospace { 1 } else { 0 })

	state = state * 31 + u64(d.variations.len)
	for v in d.variations {
		state = state * 31 + u64(v.id.value)
		// This is not correct, but we don't currently depend on the
		// hash value being different based on decimal values of variations.
		state = state * 31 + u64(i64(v.value))
	}
	return state
}

// clone creates a deep copy of the descriptor.
// In V, strings are value types so this is straightforward.
pub fn (d &Descriptor) clone() Descriptor {
	return Descriptor{
		family:     d.family
		style:      d.style
		codepoint:  d.codepoint
		size:       d.size
		bold:       d.bold
		italic:     d.italic
		monospace:  d.monospace
		variations: d.variations.clone()
	}
}

// to_fc_pattern converts the descriptor to a fontconfig pattern
// for font lookup. The pattern does not have defaults
// filled/substituted (fontconfig thing) so callers must still do this.
pub fn (d &Descriptor) to_fc_pattern() &fontconfig.Pattern {
	// XTODO: needs real fontconfig C bindings
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
pub fn (d &Descriptor) to_coretext_descriptor() !&macos.CTFontDescriptor {
	// XTODO: needs real CoreText bindings.
	// Build a CoreText font descriptor from our fields:
	// - family name
	// - style name
	// - codepoint (character set)
	// - size
	// - symbolic traits (bold, italic, monospace)
	return macos.CTFontDescriptor.create_with_attributes(
		&macos.CFDictionary{}
	)!
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
	// XTODO: needs real fontconfig C bindings
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
		config:     fd.fc_config
		pattern:    pat
		set:        res.fs
		fonts:      res.fs.fonts()
		variations: desc.variations
		i:          0
	}
}

// discover_fallback is like discover but for fallback font discovery.
pub fn (fd &FontconfigDiscovery) discover_fallback(desc Descriptor) !FcDiscoverIterator {
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
	if it.i >= it.fonts.len {
		return none
	}

	// XTODO: needs real fontconfig C bindings
	// Get the copied pattern from our fontset that has the
	// attributes configured for rendering.
	font_pattern := it.config.font_render_prepare(it.pattern, it.fonts[it.i]) or {
		return none
	}

	// Increment after we return
	defer {
		it.i += 1
	}

	// XTODO: populate DeferredFace from fontconfig pattern
	_ = font_pattern
	return DeferredFace{}
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
	// XTODO: needs real CoreText bindings.
	// Steps:
	// 1. Convert descriptor to CTFontDescriptor
	// 2. Create a font collection with that descriptor
	// 3. Get matching descriptors
	// 4. Sort by score
	// 5. Return iterator over the results
	return CtDiscoverIterator{
		list:       []
		variations: desc.variations
		i:          0
	}
}

// discover_fallback finds fallback fonts for a codepoint.
pub fn (ct &CoreTextDiscovery) discover_fallback(desc Descriptor) !CtDiscoverIterator {
	// XTODO: needs real CoreText bindings.
	// If we have a codepoint within the CJK unified ideographs block
	// then we fallback to macOS to find a font that supports it because
	// there isn't a better way manually with CoreText that I can find that
	// properly takes into account system locale.
	//
	// References:
	// - http://unicode.org/charts/PDF/U4E00.pdf
	// - https://chromium.googlesource.com/chromium/src/+/main/third_party/blink/renderer/platform/fonts/LocaleInFonts.md#unified-han-ideographs
	return ct.discover(desc)!
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
	// XTODO: release each CTFontDescriptor in the list
}

// next returns the next deferred face, or none if exhausted.
pub fn (mut it CtDiscoverIterator) next() ?DeferredFace {
	if it.i >= it.list.len {
		return none
	}

	// XTODO: needs real CoreText bindings.
	// Steps:
	// 1. Get descriptor from list[i], remove character set restriction
	// 2. Create CTFont from descriptor
	// 3. Build DeferredFace

	defer {
		it.i += 1
	}

	// XTODO: populate DeferredFace from CoreText descriptor
	return DeferredFace{}
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

// Note: DeferredFace is defined in face.v
