module font

// --- Original Ghostty Comments Start: src/font/Collection.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/font/Collection.zig
//
// A font collection is a list of faces of different styles. The list is
// ordered by priority (per style). All fonts in a collection share the same
// size so they can be used interchangeably in cases a glyph is missing in one
// and present in another.
//
// The purpose of a collection is to store a list of fonts by style
// and priority order. A collection does not handle searching for font
// callbacks, rasterization, etc. For this, see CodepointResolver.
//
// The collection can contain both loaded and deferred faces. Deferred faces
// typically use less memory while still providing some necessary information
// such as codepoint support, presentation, etc. This is useful for looking
// for fallback fonts as efficiently as possible. For example, when the glyph
// "X" is not found, we can quickly search through deferred fonts rather
// than loading the font completely.
// The available faces we have. This shouldn't be modified manually.
// Instead, use the functions available on Collection.
// The metric modifiers to use for this collection. The memory
// for this is owned by the user and is not freed by the collection.
//
// Call `Collection.updateMetrics` to recompute the
// collection's metrics after making changes to these.
// Metrics for this collection. Call `Collection.updateMetrics` to (re)compute
// these after adding a primary font or making changes to `metric_modifiers`.
// The face metrics for the primary face in the collection.
//
// We keep this around so we don't need to re-compute it when calculating
// the scale factor for additional fonts added to the collection.
// The load options for deferred faces in the face list. If this
// is not set, then deferred faces will not be loaded. Attempting to
// add a deferred face will result in an error.
// Initialize an empty collection.
// Initialize our styles array, preallocating some space that is
// likely to be used.
// Deinit all entries, aliases can be ignored.
// Options for adding a face to the collection.
// What style this face is.
// What size adjustment to use.
// Whether this is a fallback face.
// There's no more room in the collection.
// The call to `face.setSize` failed.
// Add a face to the collection. This face will be added next in priority if
// others exist already, i.e. it'll be the _last_ to be searched for a glyph
// in that list.
//
// If no error is encountered then the collection takes ownership of the face,
// in which case face will be deallocated when the collection is deallocated.
//
// When added, the size of the face will be adjusted to match `load_options`.
//
// Returns the index for the added face.
// We have some special indexes so we must never pass those.
// Scale factor to adjust the size of the added face.
// If we have load options, we update the size to ensure
// it's matches and is normalized to the primary if possible.
// There's no more room in the collection.
// `load_options` is null, can't do deferred loading.
// Add a deferred face to the collection.
//
// Returns the index for the added face.
// We have some special indexes so we must never pass those.
// Return the Face represented by a given Index. The returned pointer
// is only valid as long as this collection is not modified.
//
// This will initialize the face if it is deferred and not yet loaded,
// which can fail.
// Index represents a special font (built-in) and these don't
// have an associated face. This should be caught upstream and use
// alternate logic.
// Invalid index.
// Get the unaliased entry from an index
// Get the face from an entry.
//
// This entry must not be an alias.
// Load the face.
// Calculate the scale factor for this
// entry now that we have a loaded face.
// If our scale factor is something other
// than 1.0 then we need to resize the face.
// Deinit the deferred face now that we have
// loaded it and are past any possible errors.
// Set the loaded face on the entry.
// Return the pointer to it.
// Return the index of the font in this collection that contains
// the given codepoint, style, and presentation. If no font is found,
// null is returned.
//
// This does not trigger font loading; deferred fonts can be
// searched for codepoints.
// Not found
// Check if a specific font index has a specific codepoint. This does not
// necessarily force the font to load. The presentation value "p" will
// verify the Emoji representation matches if it is non-null. If "p" is
// null then any presentation will be accepted.
// Ensure we have an option for all styles in the collection, such
// as italic and bold by synthesizing them if necessary from the
// first regular face that has text glyphs.
//
// If there is no regular face that has text glyphs, then this
// does nothing.
// If every style has at least one entry then we're done!
// This is the most common case.
// Find the first regular face that has non-colorized text glyphs.
// This is the font we want to fallback to. This may not be index zero
// if a user configures something like an Emoji font first.
// Find our first regular face that has text glyphs.
// Load our face. If we fail to load it, we just skip it and
// continue on to try the next one.
// We have two conditionals here. The color check is obvious:
// we want to auto-italicize a normal text font. The second
// check is less obvious... for mixed color/non-color fonts, we
// accept the regular font if it has basic ASCII. This may not
// be strictly correct (especially with international fonts) but
// it's a reasonable heuristic and the first case will match 99%
// of the time.
// No regular text face found. We can't provide any fallback.
// If we don't have italic, attempt to create a synthetic italic face.
// If we can't create a synthetic italic face, we'll just use the regular
// face for italic.
// If we don't have bold, use the regular font.
// If we don't have bold italic, we attempt to synthesize a bold variant
// of the italic font. If we can't do that, we'll use the italic font.
// Prefer to synthesize on top of the face we already had. If we
// have bold then we try to synthesize italic on top of bold.
// If synthesizing italic failed, then we try to synthesize
// bold on whatever italic font we have.
// Create a synthetic bold font face from the given entry and return it.
// Not all font backends support synthetic bold.
// We require loading options to create a synthetic bold face.
// Try to bold it.
// Inherit size from regular; it may be different than opts.size
// due to scaling adjustments
// Create a synthetic italic font face from the given entry and return it.
// Not all font backends support synthetic italicization.
// We require loading options to create a synthetic italic face.
// Try to italicize it.
// Inherit size from regular; it may be different than opts.size
// due to scaling adjustments
// `self.load_options` is `null`.
// The call to `face.setSize` failed.
// Update the size of all faces in the collection. This will
// also update the size in the load options for future deferred
// face loading.
//
// This requires load options to be set.
// Get a pointer to our options so we can modify the size.
// Resize all our faces that are loaded
// Resize all faces. We skip entries that are aliases, since
// the underlying face will have a non-alias entry somewhere.
// If this isn't our primary face, we scale
// the size appropriately before setting it.
//
// If we don't have a primary face we also don't.
// Options for adjusting the size of a face relative to the primary face.
// Don't adjust the size for this face, use the original point size.
// Match ideograph character width with the primary face.
// Match ex height with the primary face.
// Match cap height with the primary face.
// Match line height with the primary face.
// Calculate a factor by which to scale the provided face to match
// it with the primary face, depending on the specified adjustment.
//
// If this encounters any problems loading the primary face or its
// metrics then it just returns `1.0`.
//
// This functions very much like the `font-size-adjust` CSS property.
// ref: https://developer.mozilla.org/en-US/docs/Web/CSS/font-size-adjust
// If there's no adjustment, the scale is 1.0
// If we haven't calculated our primary face metrics yet, do so now.
// If we can't load the primary face, just use 1.0 as the scale factor.
// We normalize the metrics values which are expressed in px to instead
// be in ems, so that it doesn't matter what size the faces actually are.
// We get the target metrics from the primary face and this face depending
// on the specified `adjustment`. If this face doesn't explicitly define a
// metric, or if the value it defines is invalid, we fall through to other
// options in the order below.
//
// In order to make sure the value is valid, we compare it with the result
// of the estimator function, which rules out both null and invalid values.
// Update the cell metrics for this collection, based on
// the primary font and the modifiers in `metric_modifiers`.
//
// This requires a primary font (index `0`) to be present.
// Packed array of all Style enum cases mapped to a growable list of faces.
//
// We use this data structure because there aren't many styles and all
// styles are typically loaded for a terminal session. The overhead per
// style even if it is not used or barely used is minimal given the
// small style count.
//
// We use a segmented list because the entry values must be pointer-stable
// to support aliases.
//
// WARNING: We cannot use any prealloc yet for the segmented list because
// the collection is copied around by value and pointers aren't stable.
// Load options are used to configure all the details a Collection
// needs to load deferred faces.
// The library to use for loading faces. This is not owned by
// the collection and can be used by multiple collections. When
// deinitializing the collection, the library is not deinitialized.
// The desired font size for all loaded faces.
// Freetype Load Flags to use when loading glyphs. This is a list of
// bitfield constants that controls operations to perform during glyph
// loading. Only a subset is exposed for configuration, for the whole set
// of flags see `pkg.freetype.face.LoadFlags`.
// The options to use for loading faces.
// A entry in a collection can be deferred or loaded. A deferred face
// is not yet fully loaded and only represents the font descriptor
// and usually uses less resources. A loaded face is fully parsed,
// ready to rasterize, and usually uses more resources than a
// deferred version.
//
// A face can also be a "fallback" variant that is still either
// deferred or loaded. Today, there is only one difference between
// fallback and non-fallback (or "explicit") faces: the handling
// of emoji presentation.
//
// For explicit faces, when an explicit emoji presentation is
// not requested, we will use any glyph for that codepoint found
// even if the font presentation does not match the UCD
// (Unicode Character Database) value. When an explicit presentation
// is requested (via either VS15/V16), that is always honored.
// The reason we do this is because we assume that if a user
// explicitly chosen a font face (hence it is "explicit" and
// not "fallback"), they want to use any glyphs possible within that
// font face. Fallback fonts on the other hand are picked as a
// last resort, so we should prefer exactness if possible.
// Not yet loaded.
// Loaded.
// Whether this face is a fallback face, see
// main doc comment on Entry for more info.
// Factor to multiply the collection size by for this face, or
// else the size adjustment that should be used to calculate
// once the face is loaded.
//
// This is computed when the face is loaded, based on a scale
// factor computed for an adjustment from the primary face to
// this one, which allows fallback fonts to be harmonized with
// the primary font by matching one of the metrics between them.
// If this face is loaded, then this returns the `Face`,
// otherwise returns null.
// True if the entry is deferred.
// True if this face satisfies the given codepoint and presentation.
// Fallback fonts require explicit presentation matching.
// Non-fallback fonts do not.
// An alias to another entry. This is used to share the same face,
// avoid memory duplication. An alias must point to a non-alias entry.
// Get a pointer to the underlying entry.
// Get a const pointer to the underlying entry.
// The requested presentation for a codepoint.
// The codepoint has an explicit presentation that is required,
// i.e. VS15/V16.
// The codepoint has no explicit presentation and we should use
// the presentation from the UCD.
// The codepoint can be any presentation.
// This represents a specific font in the collection.
//
// The backing size of this packed struct represents the total number
// of possible usable fonts in a collection. And the number of bits
// used for the index and not the style represents the total number
// of possible usable fonts for a given style.
//
// The goal is to keep the size of this struct as small as practical. We
// accept the limitations that this imposes so long as they're reasonable.
// At the time of writing this comment, this is a 16-bit struct with 13
// bits used for the index, supporting up to 8192 fonts per style. This
// seems more than reasonable. There are synthetic scenarios where this
// could be a limitation but I can't think of any that are practical.
//
// If you somehow need more fonts per style, you can increase the size of
// the Backing type and everything should just work fine.
// The number of bits we use for the index.
// The special-case fonts that we support.
// We start all special fonts at this index so they can be detected.
// Sprite drawing, this is rendered JIT using 2D graphics APIs.
// Initialize a special font index.
// Convert to int
// Returns true if this is a "special" index which doesn't map to
// a real font face. We can still render it but there is no face for
// this font.
// We never want to take up more than a byte since font indexes are
// everywhere so if we increase the size of this we'll dramatically
// increase our memory usage.
// Just so we're aware when this changes. The current maximum number
// of fonts for a style is 13 bits or 8192 fonts.
// This test is way too slow to run under Valgrind, unfortunately.
// We have to deinit it manually since the
// collection doesn't do it if adding fails.
// This can be undefined because it should never be accessed.
// Should find all visible ASCII
// Should not find emoji
// TODO(fontmem): test explicit/implicit
// The cell height is 17 px because the calculation is
//
//  ascender - descender + gap
//
// which, for inconsolata is
//
//  859 - -190 + 0
//
// font units, at 1000 units per em that works out to 1.049 em,
// and 1em should be the point size * dpi scale, so 12 * (96/72)
// which is 16, and 16 * 1.049 = 16.784, which finally is rounded
// to 17.
//
// The icon height is (2 * cap_height + face_height) / 3
// = (2 * 623 + 1049) / 3 = 765, and 16 * 0.765 = 12.24.
// Resize should change metrics
// TODO: Also test CJK fallback sizing, we don't currently have a CJK test font.
// Add our primary face.
// Add the fallback face with the chosen adjustment metric.
// The chosen metric should match.
// We accept anything within half a pixel.
// Resize should keep that relationship.
// We accept anything within half a pixel.
// Reset size for the next iteration
// A reference metric of "none" should leave the size unchanged.
// Resize should keep that.
// Reset collection size
// Add the symbol face.
// Test fallback to lineHeight() (ex_height and cap_height not defined in symbols font).
// We accept anything within half a pixel.
// The web canvas backend doesn't calculate face metrics, only cell metrics
// Verify provided/measured metrics. Measured
// values are backend-dependent due to hinting.
// Verify estimated metrics. icWidth() should equal the smaller of
// 2 * cell_width and ascii_height. For a narrow (wide) font, the
// smaller quantity is the former (latter).
//
// --- Original Ghostty Comments End: src/font/Collection.zig

// A font collection is a list of faces of different styles. The list is
// ordered by priority (per style). All fonts in a collection share the same
// size so they can be used interchangeably in cases a glyph is missing in one
// and present in another.
//
// The purpose of a collection is to store a list of fonts by style
// and priority order. A collection does not handle searching for font
// callbacks, rasterization, etc. For this, see CodepointResolver.
//
// The collection can contain both loaded and deferred faces. Deferred faces
// typically use less memory while still providing some necessary information
// such as codepoint support, presentation, etc. This is useful for looking
// for fallback fonts as efficiently as possible.
//
// Translated from ghostty/src/font/Collection.zig

// ============================================================
// SizeAdjustment
// ============================================================

// SizeAdjustment specifies how to adjust the size of a face relative
// to the primary face. This functions like the CSS font-size-adjust property.
pub enum SizeAdjustment as u8 {
	// Don't adjust the size for this face, use the original point size.
	none_
	// Match ideograph character width with the primary face.
	ic_width
	// Match ex height with the primary face.
	ex_height
	// Match cap height with the primary face.
	cap_height
	// Match line height with the primary face.
	line_height
}

// ============================================================
// PresentationMode
// ============================================================

// PresentationModeKind identifies the type of presentation matching.
pub enum PresentationModeKind as u8 {
	// The codepoint has an explicit presentation (VS15/VS16).
	explicit_
	// The codepoint has no explicit presentation; use UCD default.
	default_
	// The codepoint can be any presentation.
	any
}

// PresentationMode describes the requested presentation for a codepoint.
pub struct PresentationMode {
pub:
	kind         PresentationModeKind
	presentation Presentation = .text
}

// explicit creates a PresentationMode requiring an explicit presentation.
pub fn PresentationMode.explicit(p Presentation) PresentationMode {
	return PresentationMode{
		kind: .explicit_
		presentation: p
	}
}

// default_ creates a PresentationMode using the UCD default presentation.
pub fn PresentationMode.default_(p Presentation) PresentationMode {
	return PresentationMode{
		kind: .default_
		presentation: p
	}
}

// any creates a PresentationMode accepting any presentation.
pub fn PresentationMode.any() PresentationMode {
	return PresentationMode{
		kind: .any
	}
}

// requested returns the presentation constraint represented by this mode.
pub fn (p PresentationMode) requested() ?Presentation {
	return match p.kind {
		.explicit_, .default_ { p.presentation }
		.any { none }
	}
}

// ============================================================
// Index
// ============================================================

// Index represents a specific font in the collection.
//
// The three low bits store the style and the upper 13 bits store the
// priority within that style (lower = higher priority).
//
// Special indices (>= index_special_start) represent built-in fonts
// that don't have an associated face (e.g., sprite drawing).
pub struct Index {
	value u16
}

// The starting index for special (built-in) fonts.
pub const index_special_start = u16(8191)

// Special enumerates special built-in font indices.
pub enum Special as u16 {
	// Sprite drawing, rendered JIT using 2D graphics APIs.
	sprite = 8191
}

// init packs a style and its face-list index into Ghostty's u16 layout.
pub fn Index.init(style Style, idx u16) Index {
	assert u8(style) <= 0x7
	assert idx <= 0x1fff
	return Index{
		value: (idx << 3) | u16(style)
	}
}

// init_special creates an Index for a special built-in font.
pub fn Index.init_special(v Special) Index {
	return Index.init(.regular, u16(v))
}

// style returns the style stored in the low three bits.
pub fn (i Index) style() Style {
	return unsafe { Style(i.value & 0x7) }
}

// idx returns the 13-bit index within the style's face list.
pub fn (i Index) idx() u16 {
	return i.value >> 3
}

// int_val returns the index as a packed integer.
pub fn (i Index) int_val() u16 {
	return i.value
}

// special returns the Special value if this is a special index,
// or none for normal font indices.
pub fn (i Index) special() ?Special {
	idx := i.idx()
	if idx < index_special_start {
		return none
	}
	if idx == u16(Special.sprite) {
		return .sprite
	}
	return none
}

// ============================================================
// Entry
// ============================================================

// Entry represents a font face in the collection, which can be
// either deferred (not yet loaded) or fully loaded.
//
// A face can also be a "fallback" variant. For explicit faces,
// when an explicit emoji presentation is not requested, we use
// any glyph found even if the presentation doesn't match the UCD.
// Fallback fonts require exact presentation matching.
@[heap]
pub struct Entry {
pub mut:
	// Whether the face is loaded (true) or deferred (false).
	is_loaded bool
	// The deferred face (valid when !is_loaded).
	deferred_face DeferredFace
	// The loaded face (valid when is_loaded).
	loaded_face Face
	// Whether this face is a fallback face.
	fallback bool
	// Whether to use the scale value or the adjustment enum.
	use_scale bool = true
	// Size adjustment to compute once the face is loaded.
	adjustment SizeAdjustment = .none_
	// Computed scale factor for this face.
	scale f64 = 1.0
}

// deinit releases the face resources.
pub fn (mut self Entry) deinit() {
	if self.is_loaded {
		self.loaded_face.deinit()
	} else {
		self.deferred_face.deinit()
	}
}

// get_loaded returns the loaded Face if available, or none if deferred.
pub fn (mut self Entry) get_loaded() ?&Face {
	if !self.is_loaded {
		return none
	}
	return unsafe { &self.loaded_face }
}

// is_deferred returns true if this entry is not yet loaded.
pub fn (self Entry) is_deferred() bool {
	return !self.is_loaded
}

// has_codepoint returns true if this face contains the given codepoint
// with the specified presentation mode.
pub fn (self Entry) has_codepoint(cp u32, p_mode PresentationMode) bool {
	match p_mode.kind {
		.default_ {
			if self.fallback {
				// Fallback fonts require explicit presentation matching.
				return self.has_codepoint_explicit(cp, p_mode.presentation)
			}
			// Non-fallback fonts accept any presentation.
			return self.has_codepoint_any(cp)
		}
		.explicit_ {
			return self.has_codepoint_explicit(cp, p_mode.presentation)
		}
		.any {
			return self.has_codepoint_any(cp)
		}
	}
}

// has_codepoint_explicit checks for a codepoint with a specific presentation.
fn (self Entry) has_codepoint_explicit(cp u32, p Presentation) bool {
	if self.is_loaded {
		index := self.loaded_face.glyph_index(cp) or { return false }
		return match p {
			.text { !self.loaded_face.is_color_glyph(index) }
			.emoji { self.loaded_face.is_color_glyph(index) }
		}
	}
	return self.deferred_face.has_codepoint(cp, p)
}

// has_codepoint_any checks for a codepoint with any presentation.
fn (self Entry) has_codepoint_any(cp u32) bool {
	if self.is_loaded {
		return self.loaded_face.glyph_index(cp) != none
	}
	return self.deferred_face.has_codepoint(cp, none)
}

// ============================================================
// EntryOrAlias
// ============================================================

// EntryOrAlias wraps either a real Entry or an alias pointer to
// another Entry. Aliases are used to share the same face across
// styles (e.g., using the regular face for italic when no italic
// face is available), avoiding memory duplication.
pub struct EntryOrAlias {
pub mut:
	// Whether this is an alias (true) or a real entry (false).
	is_alias bool
	// The actual entry data (valid when !is_alias).
	entry Entry
	// Pointer to the aliased entry (valid when is_alias).
	alias_entry &Entry = unsafe { nil }
}

// new_entry creates a heap-allocated EntryOrAlias containing an entry.
pub fn EntryOrAlias.new_entry(e Entry) &EntryOrAlias {
	return &EntryOrAlias{
		entry: e
	}
}

// new_alias creates a heap-allocated EntryOrAlias as an alias.
// The alias must point to a non-alias entry.
pub fn EntryOrAlias.new_alias(target &Entry) &EntryOrAlias {
	return &EntryOrAlias{
		is_alias: true
		alias_entry: target
	}
}

// get_entry returns a pointer to the underlying Entry,
// resolving aliases transparently.
pub fn (eoa &EntryOrAlias) get_entry() &Entry {
	if eoa.is_alias {
		return eoa.alias_entry
	}
	return unsafe { &eoa.entry }
}

// get_const_entry is the read-only counterpart to get_entry in the source.
// V does not encode constness in pointer types, but retaining this entry point
// keeps read-only call sites explicit and preserves the source API surface.
pub fn (eoa &EntryOrAlias) get_const_entry() &Entry {
	if eoa.is_alias {
		return eoa.alias_entry
	}
	return unsafe { &eoa.entry }
}

// ============================================================
// LoadOptions
// ============================================================

// LoadOptions configures how deferred faces are loaded.
pub struct LoadOptions {
pub mut:
	// The library to use for loading faces. Not owned by the collection.
	library Library
	// The desired font size for all loaded faces.
	size DesiredSize = DesiredSize{
		points: 12
	}
	// Freetype load flags to use when loading glyphs.
	freetype_load_flags FreetypeLoadFlags = freetype_load_flags_default
}

// deinit releases load options resources.
pub fn (mut self LoadOptions) deinit() {
	// no-op in V (no allocator to free)
}

// face_options returns the FaceOptions derived from these load options.
pub fn (self &LoadOptions) face_options() FaceOptions {
	return FaceOptions{
		size: self.size
		freetype_load_flags: self.freetype_load_flags
	}
}

// Note: MetricsModifierSet is defined in shared_grid_set.v

// ============================================================
// AddOptions
// ============================================================

// AddOptions configures how a face is added to the collection.
pub struct AddOptions {
pub:
	// What style this face is.
	style Style
	// What size adjustment to use.
	size_adjustment SizeAdjustment
	// Whether this is a fallback face.
	fallback bool
}

// ============================================================
// FontSyntheticStyle (from config)
// ============================================================

// FontSyntheticStyle controls which synthetic styles are enabled.
pub struct FontSyntheticStyle {
	value u8 = 0x07
}

pub fn FontSyntheticStyle.init(bold bool, italic bool, bold_italic bool) FontSyntheticStyle {
	mut value := u8(0)
	if bold {
		value |= 0x01
	}
	if italic {
		value |= 0x02
	}
	if bold_italic {
		value |= 0x04
	}
	return FontSyntheticStyle{
		value: value
	}
}

pub fn (style FontSyntheticStyle) bold() bool {
	return style.value & 0x01 != 0
}

pub fn (style FontSyntheticStyle) italic() bool {
	return style.value & 0x02 != 0
}

pub fn (style FontSyntheticStyle) bold_italic() bool {
	return style.value & 0x04 != 0
}

pub fn (style FontSyntheticStyle) int_val() u8 {
	return style.value
}

// format_entry preserves Config.FontSyntheticStyle's packed-field order.
pub fn (s FontSyntheticStyle) format_entry() string {
	return [if s.bold() { 'bold' } else { 'no-bold' },
		if s.italic() { 'italic' } else { 'no-italic' },
		if s.bold_italic() { 'bold-italic' } else { 'no-bold-italic' }].join(',')
}

// ============================================================
// Collection
// ============================================================

// Collection is a list of faces of different styles, ordered by priority.
pub struct Collection {
pub mut:
	// Face lists per style.
	regular_faces     []&EntryOrAlias
	bold_faces        []&EntryOrAlias
	italic_faces      []&EntryOrAlias
	bold_italic_faces []&EntryOrAlias
	// The metric modifiers to use for this collection.
	// Call update_metrics() to recompute after making changes.
	metric_modifiers MetricsModifierSet
	// Metrics for this collection.
	// Call update_metrics() to (re)compute these.
	metrics ?Metrics
	// The face metrics for the primary face in the collection.
	// Kept around to avoid re-computing when calculating scale factors.
	primary_face_metrics ?FaceMetrics
	// Load options for deferred faces.
	// If not set, deferred faces will not be loaded.
	load_options ?LoadOptions
}

// init creates an empty collection.
pub fn Collection.init() Collection {
	return Collection{}
}

// deinit releases all faces and resources in the collection.
pub fn (mut self Collection) deinit() {
	// Deinit all entries. Aliases can be ignored.
	for list in [self.regular_faces, self.bold_faces, self.italic_faces, self.bold_italic_faces] {
		for item in list {
			if !item.is_alias {
				unsafe {
					mut e := &item.entry
					e.deinit()
				}
			}
		}
	}
	self.regular_faces = []
	self.bold_faces = []
	self.italic_faces = []
	self.bold_italic_faces = []

	if mut lo := self.load_options {
		lo.deinit()
	}
}

// faces_for returns the face list for the given style.
fn (self &Collection) faces_for(style Style) []&EntryOrAlias {
	return match style {
		.regular { self.regular_faces }
		.bold { self.bold_faces }
		.italic { self.italic_faces }
		.bold_italic { self.bold_italic_faces }
	}
}

// face_count returns the number of faces for a given style.
fn (self &Collection) face_count(style Style) int {
	return self.faces_for(style).len
}

// face_at returns the EntryOrAlias at the given index for the given style.
fn (self &Collection) face_at(style Style, idx int) &EntryOrAlias {
	return self.faces_for(style)[idx]
}

// append_face appends a face to the given style's list.
fn (mut self Collection) append_face(style Style, item &EntryOrAlias) {
	match style {
		.regular { self.regular_faces << item }
		.bold { self.bold_faces << item }
		.italic { self.italic_faces << item }
		.bold_italic { self.bold_italic_faces << item }
	}
}

// add adds a loaded face to the collection. This face will be added next
// in priority if others exist already, i.e. it'll be the _last_ to be
// searched for a glyph in that list.
//
// If no error is encountered then the collection takes ownership of the face.
// When added, the size of the face will be adjusted to match load_options.
//
// Returns the index for the added face.
pub fn (mut self Collection) add(face Face, opts AddOptions) !Index {
	count := self.face_count(opts.style)

	// We have some special indexes so we must never pass those.
	if count >= int(index_special_start) - 1 {
		return error('collection full')
	}

	mut owned_face := face

	// Scale factor to adjust the size of the added face.
	scale_factor := self.scale_factor(owned_face.get_metrics(), opts.size_adjustment)

	// If we have load options, we update the size to ensure
	// it matches and is normalized to the primary if possible.
	if lo := self.load_options {
		mut new_opts := lo
		new_opts.size.points *= f32(scale_factor)
		owned_face.set_face_size(new_opts.face_options()) or {
			return error('set size failed')
		}
	}

	self.append_face(opts.style, EntryOrAlias.new_entry(Entry{
		is_loaded: true
		loaded_face: owned_face
		fallback: opts.fallback
		use_scale: true
		scale: scale_factor
	}))

	return Index.init(opts.style, u16(count))
}

// add_deferred adds a deferred face to the collection.
// Returns the index for the added face.
pub fn (mut self Collection) add_deferred(face DeferredFace, opts AddOptions) !Index {
	if self.load_options == none {
		return error('deferred loading unavailable')
	}

	count := self.face_count(opts.style)

	// We have some special indexes so we must never pass those.
	if count >= int(index_special_start) - 1 {
		return error('collection full')
	}

	self.append_face(opts.style, EntryOrAlias.new_entry(Entry{
		deferred_face: face
		fallback: opts.fallback
		use_scale: false
		adjustment: opts.size_adjustment
	}))

	return Index.init(opts.style, u16(count))
}

// get_face returns the Face for the given Index. The returned pointer
// is only valid as long as this collection is not modified.
//
// This will load the face if it is deferred and not yet loaded.
pub fn (mut self Collection) get_face(index Index) !&Face {
	mut entry := self.get_entry(index)!
	return self.get_face_from_entry(mut entry)
}

// get_entry returns the unaliased entry for the given index.
pub fn (mut self Collection) get_entry(index Index) !&Entry {
	if _ := index.special() {
		return error('special has no face')
	}
	list := self.faces_for(index.style())
	if int(index.idx()) >= list.len {
		return error('index out of bounds')
	}
	return list[int(index.idx())].get_entry()
}

// get_face_from_entry loads a face from an entry if needed and returns it.
fn (mut self Collection) get_face_from_entry(mut entry Entry) !&Face {
	if entry.is_loaded {
		return unsafe { &entry.loaded_face }
	}

	// Entry is deferred — load it.
	lo := self.load_options or {
		return error('deferred loading unavailable')
	}

	// Load the face.
	mut face := entry.deferred_face.load(lo.library, lo.face_options())!

	// Calculate the scale factor for this entry now that we have a loaded face.
	if !entry.use_scale {
		factor := self.scale_factor(face.get_metrics(), entry.adjustment)
		entry.use_scale = true
		entry.scale = factor
	}

	// If our scale factor is something other than 1.0
	// then we need to resize the face.
	if entry.scale != 1.0 {
		mut scaled_opts := lo
		scaled_opts.size.points *= f32(entry.scale)
		face.set_face_size(scaled_opts.face_options())!
	}

	// Deinit the deferred face now that we have loaded it.
	entry.deferred_face.deinit()

	// Set the loaded face on the entry.
	entry.is_loaded = true
	entry.loaded_face = face

	return unsafe { &entry.loaded_face }
}

// get_index returns the index of the font in this collection that contains
// the given codepoint, style, and presentation. If no font is found,
// none is returned.
//
// This does not trigger font loading; deferred fonts can be
// searched for codepoints.
pub fn (self &Collection) get_index(cp u32, style Style, p_mode PresentationMode) ?Index {
	list := self.faces_for(style)
	for i, item in list {
		if item.get_entry().has_codepoint(cp, p_mode) {
			return Index.init(style, u16(i))
		}
	}
	// Not found.
	return none
}

// has_codepoint checks if a specific font index has a specific codepoint.
// This does not necessarily force the font to load.
pub fn (self &Collection) has_codepoint(index Index, cp u32, p_mode PresentationMode) bool {
	list := self.faces_for(index.style())
	if int(index.idx()) >= list.len {
		return false
	}
	return list[int(index.idx())].get_entry().has_codepoint(cp, p_mode)
}

// complete_styles ensures we have an option for all styles in the collection,
// such as italic and bold by synthesizing them if necessary from the
// first regular face that has text glyphs.
//
// If there is no regular face that has text glyphs, then this
// does nothing.
pub fn (mut self Collection) complete_styles(synthetic_config FontSyntheticStyle) ! {
	// If every style has at least one entry then we're done!
	// This is the most common case.
	if self.regular_faces.len > 0 && self.bold_faces.len > 0
		&& self.italic_faces.len > 0 && self.bold_italic_faces.len > 0 {
		return
	}

	// Find the first regular face that has non-colorized text glyphs.
	if self.regular_faces.len == 0 {
		return
	}

	mut regular_entry := &Entry(unsafe { nil })
	for item in self.regular_faces {
		mut entry := item.get_entry()
		face := self.get_face_from_entry(mut entry) or { continue }

		// We want a normal text font (not color-only).
		// For mixed color/non-color fonts, accept if it has basic ASCII.
		if !face.has_color() || face.glyph_index(u32(`A`)) != none {
			regular_entry = entry
			break
		}
	}

	if regular_entry == unsafe { nil } {
		// No regular text face found.
		return error('default unavailable')
	}

	// --- Italic ---
	// If we don't have italic, attempt to create a synthetic italic face.
	// If we can't create a synthetic italic face, we'll just use the regular
	// face for italic.
	have_italic := self.italic_faces.len > 0
	if !have_italic {
		if !synthetic_config.italic() {
			// italic style not available and synthetic italic disabled
			self.italic_faces << EntryOrAlias.new_alias(regular_entry)
		} else if synthetic := self.create_synthetic_italic(regular_entry) {
			// synthetic italic face created
			self.italic_faces << EntryOrAlias.new_entry(Entry{
				is_loaded: true
				loaded_face: synthetic
				fallback: false
			})
		} else {
			// Failed to create synthetic italic; italic style will not be
			// available, so fall back to aliasing the regular face.
			self.italic_faces << EntryOrAlias.new_alias(regular_entry)
		}
	}

	// --- Bold ---
	// If we don't have bold, use the regular font (or a synthetic bold).
	have_bold := self.bold_faces.len > 0
	if !have_bold {
		if !synthetic_config.bold() {
			// bold style not available and synthetic bold disabled
			self.bold_faces << EntryOrAlias.new_alias(regular_entry)
		} else if synthetic := self.create_synthetic_bold(regular_entry) {
			// synthetic bold face created
			self.bold_faces << EntryOrAlias.new_entry(Entry{
				is_loaded: true
				loaded_face: synthetic
				fallback: false
			})
		} else {
			// Failed to create synthetic bold; bold style will not be
			// available, so fall back to aliasing the regular face.
			self.bold_faces << EntryOrAlias.new_alias(regular_entry)
		}
	}

	// --- Bold Italic ---
	// If we don't have bold italic, we attempt to synthesize a bold variant
	// of the italic font. If we can't do that, we'll use the italic font.
	if self.bold_italic_faces.len == 0 {
		if !synthetic_config.bold_italic() {
			// bold italic style not available and synthetic bold italic disabled
			self.bold_italic_faces << EntryOrAlias.new_alias(regular_entry)
			return
		}

		// Prefer to synthesize on top of the face we already had. If we have
		// bold then we try to synthesize italic on top of bold.
		if have_bold {
			mut bold_base := self.bold_faces[0].get_entry()
			if synthetic := self.create_synthetic_italic(bold_base) {
				// synthetic bold italic face created from bold
				self.bold_italic_faces << EntryOrAlias.new_entry(Entry{
					is_loaded: true
					loaded_face: synthetic
					fallback: false
				})
				return
			}
			// If synthesizing italic failed, then we try to synthesize bold
			// on whatever italic font we have.
		}

		mut italic_base := self.italic_faces[0].get_entry()
		if synthetic := self.create_synthetic_bold(italic_base) {
			// synthetic bold italic face created from italic
			self.bold_italic_faces << EntryOrAlias.new_entry(Entry{
				is_loaded: true
				loaded_face: synthetic
				fallback: false
			})
			return
		}

		// bold italic style not available, using italic font
		self.bold_italic_faces << EntryOrAlias.new_alias(italic_base)
	}
}

// create_synthetic_bold creates a synthetic bold font face from the given entry.
fn (mut self Collection) create_synthetic_bold(entry &Entry) !Face {
	// We require loading options to create a synthetic bold face.
	lo := self.load_options or {
		return error('deferred loading unavailable')
	}

	// Try to bold it.
	mut e := unsafe { entry }
	regular := self.get_face_from_entry(mut e)!

	// Inherit size from regular; it may be different than opts.size
	// due to scaling adjustments.
	mut face_opts := lo.face_options()
	face_opts.size = regular.size
	face := regular.synthetic_bold_face(face_opts)!

	return face
}

// create_synthetic_italic creates a synthetic italic font face from the given entry.
fn (mut self Collection) create_synthetic_italic(entry &Entry) !Face {
	// We require loading options to create a synthetic italic face.
	lo := self.load_options or {
		return error('deferred loading unavailable')
	}

	// Try to italicize it.
	mut e := unsafe { entry }
	regular := self.get_face_from_entry(mut e)!

	// Inherit size from regular; it may be different than opts.size
	// due to scaling adjustments.
	mut face_opts := lo.face_options()
	face_opts.size = regular.size
	face := regular.synthetic_italic_face(face_opts)!

	return face
}

// set_collection_size updates the size of all faces in the collection.
// This will also update the size in the load options for future
// deferred face loading.
//
// This requires load options to be set.
pub fn (mut self Collection) set_collection_size(size DesiredSize) ! {
	// Get a pointer to our options so we can modify the size.
	mut lo := self.load_options or {
		return error('deferred loading unavailable')
	}
	lo.size = size
	self.load_options = lo

	// Get the primary entry (index 0) for scale comparisons.
	primary_entry_ptr := self.get_entry(Index{}) or { &Entry(unsafe { nil }) }

	// Resize all our faces that are loaded.
	// We skip entries that are aliases, since the underlying face
	// will have a non-alias entry somewhere.
	for list in [self.regular_faces, self.bold_faces, self.italic_faces, self.bold_italic_faces] {
		for item in list {
			if item.is_alias {
				continue
			}
			mut entry := item.get_entry()
			if mut face := entry.get_loaded() {
				// If this isn't our primary face, we scale
				// the size appropriately before setting it.
				mut new_opts := lo
				if primary_entry_ptr != unsafe { nil }
					&& entry != primary_entry_ptr {
					new_opts.size.points *= f32(entry.scale)
				}
				face.set_face_size(new_opts.face_options()) or {
					return error('set size failed')
				}
			}
		}
	}

	self.update_metrics()!
}

// scale_factor calculates a factor by which to scale the provided face
// to match it with the primary face, depending on the specified adjustment.
//
// If this encounters any problems loading the primary face or its
// metrics then it just returns 1.0.
//
// This functions very much like the font-size-adjust CSS property.
// ref: https://developer.mozilla.org/en-US/docs/Web/CSS/font-size-adjust
fn (mut self Collection) scale_factor(face_metrics FaceMetrics, adjustment SizeAdjustment) f64 {
	// If there's no adjustment, the scale is 1.0.
	if adjustment == .none_ {
		return 1.0
	}

	// If we haven't calculated our primary face metrics yet, do so now.
	if self.primary_face_metrics == none {
		// If we can't load the primary face, just use 1.0.
		mut primary_face := self.get_face(Index{}) or { return 1.0 }
		self.primary_face_metrics = primary_face.get_metrics()
	}

	primary_metrics := self.primary_face_metrics or { return 1.0 }

	// We normalize the metrics values which are expressed in px to instead
	// be in ems, so that it doesn't matter what size the faces actually are.
	primary_scale := 1.0 / primary_metrics.px_per_em
	face_scale := 1.0 / face_metrics.px_per_em

	// We get the target metrics from the primary face and this face
	// depending on the specified adjustment. If this face doesn't explicitly
	// define a metric, or if the value it defines is invalid, we fall through
	// to other options in the order below.
	//
	// In order to make sure the value is valid, we compare it with the result
	// of the estimator function, which rules out both null and invalid values.
	// In Zig this is `face_metrics.ic_width != face_metrics.icWidth()`, which
	// is true (fall through) exactly when the raw optional is null or not
	// positive.
	primary_metric, face_metric := self.scale_factor_for(adjustment, primary_metrics, face_metrics, primary_scale, face_scale)

	if face_metric == 0.0 {
		return 1.0
	}
	return primary_metric / face_metric
}

// scale_factor_for returns primary_metric and face_metric for the given
// adjustment level, falling through to the next level (ic_width -> ex_height
// -> cap_height -> line_height) if the face doesn't provide a valid value.
fn (self &Collection) scale_factor_for(adjustment SizeAdjustment, primary_metrics FaceMetrics, face_metrics FaceMetrics, primary_scale f64, face_scale f64) (f64, f64) {
	match adjustment {
		.ic_width {
			// Valid iff the raw ic_width is present and positive (i.e. the
			// getter returns the raw value rather than an estimate).
			if !metric_is_valid(face_metrics.ic_width) {
				return self.scale_factor_for(.ex_height, primary_metrics, face_metrics, primary_scale, face_scale)
			}
			return primary_metrics.ic_width() * primary_scale, face_metrics.ic_width() * face_scale
		}
		.ex_height {
			if !metric_is_valid(face_metrics.ex_height) {
				return self.scale_factor_for(.cap_height, primary_metrics, face_metrics, primary_scale, face_scale)
			}
			return primary_metrics.ex_height() * primary_scale, face_metrics.ex_height() * face_scale
		}
		.cap_height {
			if !metric_is_valid(face_metrics.cap_height) {
				// Fall through to line_height.
				return primary_metrics.line_height() * primary_scale, face_metrics.line_height() * face_scale
			}
			return primary_metrics.cap_height() * primary_scale, face_metrics.cap_height() * face_scale
		}
		.line_height {
			return primary_metrics.line_height() * primary_scale, face_metrics.line_height() * face_scale
		}
		.none_ {
			// unreachable
			return 1.0, 1.0
		}
	}
}

// metric_is_valid returns true if the optional metric value is present and
// positive, matching Zig's `raw == getter()` validity check.
fn metric_is_valid(v ?f64) bool {
	if value := v {
		return value > 0
	}
	return false
}

// update_metrics recomputes the cell metrics for this collection,
// based on the primary font and the modifiers in metric_modifiers.
//
// This requires a primary font (index 0) to be present.
pub fn (mut self Collection) update_metrics() ! {
	mut primary_face := self.get_face(Index{}) or {
		return error('cannot load primary font')
	}

	self.primary_face_metrics = primary_face.get_metrics()

	face_metrics := self.primary_face_metrics or {
		return error('cannot load primary font')
	}

	mut metrics := Metrics.calc(face_metrics)
	metrics.apply(self.metric_modifiers)

	self.metrics = metrics
}
