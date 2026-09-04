module font

// CodepointResolver maps a codepoint to a font. It is more dynamic
// than "Collection" since it supports mapping codepoint ranges to
// specific fonts, searching for fallback fonts, and more.
//
// To initialize the codepoint resolver, create it with struct literal
// syntax. Set the fields you want set, and begin using the resolver.
//
// Deinit must still be called on the resolver to free any memory
// allocated during use.
//
// Translated from ghostty/src/font/CodepointResolver.zig

// ============================================================
// StyleStatus
// ============================================================

// StyleStatus tracks which font styles are enabled.
// Packed array of booleans to indicate if a style is enabled or not.
pub struct StyleStatus {
pub mut:
	bold        bool = true
	italic      bool = true
	bold_italic bool = true
}

// init_fill creates a StyleStatus with all styles set to the given value.
pub fn StyleStatus.init_fill(val bool) StyleStatus {
	return StyleStatus{
		bold: val
		italic: val
		bold_italic: val
	}
}

// get returns whether the given style is enabled. Regular is always enabled.
pub fn (s &StyleStatus) get(style FontStyle) bool {
	return match style {
		.regular { true }
		.bold { s.bold }
		.italic { s.italic }
		.bold_italic { s.bold_italic }
	}
}

// set enables or disables a specific style.
pub fn (mut s StyleStatus) set(style FontStyle, val bool) {
	match style {
		.regular {} // Regular cannot be disabled
		.bold {
			s.bold = val
		}
		.italic {
			s.italic = val
		}
		.bold_italic {
			s.bold_italic = val
		}
	}
}

// ============================================================
// DescriptorCache
// ============================================================

// DescriptorCache maps descriptors to font indices. This is used with
// manual codepoint maps to ensure that we don't load the same font
// multiple times.
//
// Note that the current implementation will load the same font multiple
// times if the font used for a codepoint map is identical to a font used
// for a regular style. That's just an inefficient choice made now because
// the implementation is simpler and codepoint maps matching a regular
// font is a rare case.
struct DescriptorCache {
mut:
	// Map from descriptor hashcode to optional Index. A none value
	// means the descriptor was searched but no font was found,
	// which avoids expensive re-discovery later.
	entries map[u64]DescriptorCacheEntry
}

// DescriptorCacheEntry holds the cached result for a descriptor lookup.
// The index is optional because a none value means we searched for
// the descriptor but found nothing (negative cache entry).
struct DescriptorCacheEntry {
mut:
	has_index bool
	index     Index
}

fn (mut dc DescriptorCache) deinit() {
	dc.entries = map[u64]DescriptorCacheEntry{}
}

// get returns the cached index for a descriptor, or none if the descriptor
// is not in the cache. If the descriptor was cached as "not found",
// the returned DescriptorCacheEntry will have has_index == false.
fn (dc &DescriptorCache) get(desc Descriptor) ?DescriptorCacheEntry {
	// Note that this means its possible to have two different
	// descriptors match when there is a hash collision so we
	// should button this up later.
	key := desc.hashcode()
	if key in dc.entries {
		return dc.entries[key]
	}
	return none
}

// put stores a descriptor -> index mapping in the cache.
// If idx is none, stores a negative cache entry.
fn (mut dc DescriptorCache) put(desc Descriptor, idx ?Index) {
	key := desc.hashcode()
	if i := idx {
		dc.entries[key] = DescriptorCacheEntry{
			has_index: true
			index: i
		}
	} else {
		dc.entries[key] = DescriptorCacheEntry{
			has_index: false
		}
	}
}

// ============================================================
// SpriteFace
// ============================================================

// SpriteFace handles rendering of built-in sprite glyphs (box drawing
// characters, underlines, cursors, etc.) using 2D graphics APIs.
pub struct SpriteFace {
pub mut:
	metrics Metrics
}

// has_codepoint returns true if this sprite face can render the given
// codepoint with the optional presentation.
pub fn (sf &SpriteFace) has_codepoint(cp u32, p ?Presentation) bool {
	_ = p
	return sprite_face_has_codepoint(cp)
}

// render_glyph renders a sprite glyph into the given atlas.
//
// Faithful to Ghostty's sprite Face.renderGlyph. The dependency-neutral
// raster result is inserted into the font-owned atlas by the implementation.
pub fn (sf &SpriteFace) render_glyph(mut atlas Atlas, glyph_index u32, opts RenderOptions) !GlyphInfo {
	return sprite_face_render_glyph(mut atlas, glyph_index, sf.metrics, opts)
}

// ============================================================
// Default fallback adjustment
// ============================================================

// default_fallback_adjustment is the size adjustment used for
// fallback fonts discovered via font discovery.
pub const default_fallback_adjustment = SizeAdjustment.none_

// is_emoji_presentation is generated from the Emoji_Presentation property in
// the exact uucode/Unicode data revision pinned by the matching Ghostty
// commit. Adjacent ranges are coalesced without changing membership.
fn is_emoji_presentation(cp u32) bool {
	return match cp {
		0x231a...0x231b, 0x23e9...0x23ec, 0x23f0, 0x23f3, 0x25fd...0x25fe, 0x2614...0x2615, 0x2648...0x2653, 0x267f, 0x2693, 0x26a1, 0x26aa...0x26ab, 0x26bd...0x26be, 0x26c4...0x26c5, 0x26ce, 0x26d4, 0x26ea, 0x26f2...0x26f3, 0x26f5, 0x26fa, 0x26fd, 0x2705, 0x270a...0x270b, 0x2728, 0x274c, 0x274e, 0x2753...0x2755, 0x2757, 0x2795...0x2797, 0x27b0, 0x27bf, 0x2b1b...0x2b1c, 0x2b50, 0x2b55, 0x1f004, 0x1f0cf, 0x1f18e, 0x1f191...0x1f19a, 0x1f1e6...0x1f1ff, 0x1f201, 0x1f21a, 0x1f22f, 0x1f232...0x1f236, 0x1f238...0x1f23a, 0x1f250...0x1f251, 0x1f300...0x1f320, 0x1f32d...0x1f335, 0x1f337...0x1f37c, 0x1f37e...0x1f393, 0x1f3a0...0x1f3ca, 0x1f3cf...0x1f3d3, 0x1f3e0...0x1f3f0, 0x1f3f4, 0x1f3f8...0x1f43e, 0x1f440, 0x1f442...0x1f4fc, 0x1f4ff...0x1f53d, 0x1f54b...0x1f54e, 0x1f550...0x1f567, 0x1f57a, 0x1f595...0x1f596, 0x1f5a4, 0x1f5fb...0x1f64f, 0x1f680...0x1f6c5, 0x1f6cc, 0x1f6d0...0x1f6d2, 0x1f6d5...0x1f6d7, 0x1f6dc...0x1f6df, 0x1f6eb...0x1f6ec, 0x1f6f4...0x1f6fc, 0x1f7e0...0x1f7eb, 0x1f7f0, 0x1f90c...0x1f93a, 0x1f93c...0x1f945, 0x1f947...0x1f9ff, 0x1fa70...0x1fa7c, 0x1fa80...0x1fa89, 0x1fa8f...0x1fac6, 0x1face...0x1fadc, 0x1fadf...0x1fae9, 0x1faf0...0x1faf8 {
			true
		}
		else {
			false
		}
	}
}

// ============================================================
// CodepointResolver
// ============================================================

// CodepointResolver maps codepoints to fonts. It wraps a Collection
// and adds support for codepoint overrides, font discovery fallback,
// sprite rendering, and style status checking.
pub struct CodepointResolver {
pub mut:
	// The underlying collection of fonts. This will be modified as
	// new fonts are found via the resolver. The resolver takes ownership
	// of the collection and will deinit it when it is deinitialized.
	collection Collection

	// The set of statuses and whether they're enabled or not. This defaults
	// to true. This can be changed at runtime with no ill effect.
	styles StyleStatus = StyleStatus.init_fill(true)

	// If discovery is available, we'll look up fonts where we can't find
	// the codepoint. This can be set after initialization.
	discover &Discover = unsafe { nil }

	// A map of codepoints to font requests for codepoint-level overrides.
	// The memory associated with the map is owned by the caller and is not
	// modified or freed by Group.
	codepoint_map ?CodepointMap

	// The descriptor cache is used to cache the descriptor to font face
	// mapping for codepoint maps.
	descriptor_cache DescriptorCache

	// Set this to a non-null value to enable sprite glyph drawing. If this
	// isn't enabled we'll just fall through to trying to use regular fonts
	// to render sprite glyphs. But more than likely, if this isn't set then
	// terminal rendering will look wrong.
	sprite ?SpriteFace
}

// deinit releases all resources owned by the CodepointResolver.
pub fn (mut self CodepointResolver) deinit() {
	self.collection.deinit()
	self.descriptor_cache.deinit()
}

// get_index looks up the font that should be used for a specific codepoint.
// The font index is valid as long as font faces aren't removed. This
// isn't cached; it is expected that downstream users handle caching if
// that is important.
//
// Optionally, a presentation format can be specified. This presentation
// format will be preferred but if it can't be found in this format,
// any format will be accepted. If presentation is none, the UCD
// (Unicode Character Database) will be used to determine the default
// presentation for the codepoint.
//
// This logic is relatively complex so the exact algorithm is documented
// here. If this gets out of sync with the code, ask questions.
//
//   1. If a font style is requested that is disabled (i.e. bold),
//      we start over with the regular font style. The regular font style
//      cannot be disabled, but it can be replaced with a stylized font
//      face.
//
//   2. If there is a codepoint override for the codepoint, we satisfy
//      that requirement if we can, no matter what style or presentation.
//
//   3. If this is a sprite codepoint (such as an underline), then the
//      sprite font always is the result.
//
//   4. If the exact style and presentation request can be satisfied by
//      one of our loaded fonts, we return that value. We search loaded
//      fonts in the order they're added to the group, so the caller must
//      set the priority order.
//
//   5. If the style isn't regular, we restart this process at this point
//      but with the regular style. This lets us fall back to regular with
//      our loaded fonts before trying a fallback. We'd rather show a regular
//      version of a codepoint from a loaded font than find a new font in
//      the correct style because styles in other fonts often change
//      metrics like glyph widths.
//
//   6. If the style is regular, and font discovery is enabled, we look
//      for a fallback font to satisfy our request.
//
//   7. Finally, as a last resort, we fall back to restarting this whole
//      process with a regular font face satisfying ANY presentation for
//      the codepoint. If this fails, we return null.
//
pub fn (mut self CodepointResolver) get_index(cp u32, style FontStyle, p ?Presentation) ?Index {
	// If we've disabled a font style, then fall back to regular.
	if style != .regular && !self.styles.get(style) {
		return self.get_index(cp, .regular, p)
	}

	// Codepoint overrides.
	override_result := self.get_index_codepoint_override(cp)
	if idx := override_result {
		return idx
	}

	// If we have sprite drawing enabled, check if our sprite face can
	// handle this.
	if sprite := self.sprite {
		if sprite.has_codepoint(cp, p) {
			return Index.init_special(.sprite)
		}
	}

	// Build our presentation mode. If we don't have an explicit presentation
	// given then we use the UCD (Unicode Character Database) to determine
	// the default presentation. Note there is some inefficiency here because
	// we'll do this multiple times if we recurse, but this is a cached function
	// call higher up (GroupCache) so this should be rare.
	p_mode := if pr := p {
		PresentationMode.explicit(pr)
	} else {
		PresentationMode.default_(if is_emoji_presentation(cp) { .emoji } else { .text })
	}

	// If we can find the exact value, then return that.
	if value := self.collection.get_index(cp, style, p_mode) {
		return value
	}

	// If we're not a regular font style, try looking for a regular font
	// that will satisfy this request. Blindly looking for unmatched styled
	// fonts to satisfy one codepoint results in some ugly rendering.
	if style != .regular {
		if value := self.get_index(cp, .regular, p) {
			return value
		}
	}

	// If we are regular, try looking for a fallback using discovery.
	if style == .regular && self.discover != unsafe { nil } {
		if load_opts := self.collection.load_options {
			desc := Descriptor{
				codepoint: cp
				size: load_opts.size.points
				monospace: false
			}
			mut it := self.discover.discover_fallback(desc) or {
				return self.collection.get_index(cp, .regular, PresentationMode.any())
			}
			defer { it.deinit() }
			for {
				mut deferred := it.next() or { break }
				if !deferred.has_codepoint(cp, p_mode.requested()) {
					deferred.deinit()
					continue
				}
				idx := self.collection.add_deferred(deferred, AddOptions{
					style: style
					fallback: true
					size_adjustment: default_fallback_adjustment
				}) or {
					deferred.deinit()
					break
				}
				return idx
			}
		}
	}

	// If this is regular with any matching presentation, then we are done
	// there is nothing more we can do. Otherwise we fall through and do
	// an any presentation search.
	if style == .regular && p_mode.kind == .any {
		return none
	}

	// For non-regular fonts, we fall back to regular with any presentation
	return self.collection.get_index(cp, .regular, PresentationMode.any())
}

// get_index_codepoint_override checks if the codepoint is in the map of
// codepoint overrides, finds the override font, and returns it.
fn (mut self CodepointResolver) get_index_codepoint_override(cp u32) ?Index {
	if self.discover == unsafe { nil } {
		return none
	}

	// Get our codepoint map. If we have no map set then we have no
	// codepoint overrides and we're done.
	cmap := self.codepoint_map or { return none }

	// If the codepoint isn't in the map, then we don't have an override.
	// The map returns a descriptor that can be used with font discovery
	// to search for a matching font.
	desc := cmap.get(cp) or { return none }

	// Fast path: the descriptor is already loaded. This means that we
	// already did the search before and we have an exact font for this
	// codepoint.
	if cached := self.descriptor_cache.get(desc) {
		if !cached.has_index {
			// Negative cache entry: we searched but found nothing.
			return none
		}
		idx := cached.index

		// We need to verify that this index has the codepoint we want.
		if self.collection.has_codepoint(idx, cp, PresentationMode.any()) {
			return idx
		}
		return none
	}

	// Slow path: discover the requested family and retain the first result
	// that actually covers this codepoint.
	mut query := desc.clone()
	query.codepoint = cp
	mut it := self.discover.discover(query) or {
		self.descriptor_cache.put(desc, none)
		return none
	}
	defer { it.deinit() }
	for {
		mut deferred := it.next() or { break }
		if !deferred.has_codepoint(cp, none) {
			deferred.deinit()
			continue
		}
		idx := self.collection.add_deferred(deferred, AddOptions{
			style: .regular
			fallback: false
			size_adjustment: default_fallback_adjustment
		}) or {
			deferred.deinit()
			break
		}
		self.descriptor_cache.put(desc, idx)
		return idx
	}
	self.descriptor_cache.put(desc, none)
	return none
}

// get_presentation returns the presentation for a specific font index.
// This is useful for determining what atlas is needed.
pub fn (mut self CodepointResolver) get_presentation(index Index, glyph_index u32) !Presentation {
	if sp := index.special() {
		return match sp {
			.sprite { Presentation.text }
		}
	}

	face := self.collection.get_face(index)!
	return if face.is_color_glyph(glyph_index) { Presentation.emoji } else { Presentation.text }
}

// render_glyph renders a glyph by glyph index into the given font atlas
// and returns metadata about it.
//
// This performs no caching, it is up to the caller to cache calls to this
// if they want. This will also not resize the atlas if it is full.
//
// IMPORTANT: this renders by /glyph index/ and not by /codepoint/. The caller
// is expected to translate codepoints to glyph indexes in some way. The most
// trivial way to do this is to get the Face and call glyph_index. If you're
// doing text shaping, the text shaping library (i.e. HarfBuzz) will automatically
// determine glyph indexes for a text run.
pub fn (mut self CodepointResolver) render_glyph(mut atlas Atlas, index Index, glyph_index u32, opts RenderOptions) !GlyphInfo {
	// Special-case fonts are rendered directly.
	if sp := index.special() {
		match sp {
			.sprite {
				mut sprite := self.sprite or {
					return error('sprite face not set')
				}
				return sprite.render_glyph(mut atlas, glyph_index, opts)!
			}
		}
	}

	face := self.collection.get_face(index)!
	glyph := face.render_glyph(mut atlas, glyph_index, opts)!
	return glyph
}
