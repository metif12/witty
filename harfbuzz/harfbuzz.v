module harfbuzz

// HarfBuzz text shaping library bindings.
//
// This module provides V bindings for the HarfBuzz text shaping library,
// used for converting Unicode text into positioned glyphs.
//
// HarfBuzz is the most commonly used text shaping engine. It handles
// complex text layout including ligatures, kerning, and right-to-left
// scripts.

// ContentType specifies the type of content in a buffer.
pub enum ContentType {
	invalid
	// Buffer contains Unicode codepoints (before shaping).
	unicode
	// Buffer contains glyph indices (after shaping).
	glyphs
}

// ClusterLevel controls the granularity of cluster tracking.
pub enum ClusterLevel {
	// Monotone graphemes: clusters merge across grapheme boundaries.
	monotone_graphemes
	// Monotone characters: clusters merge within grapheme boundaries.
	monotone_characters
	// Characters: each codepoint maintains its own cluster.
	// This gives the most granularity, matching CoreText behavior.
	characters
}

// Direction specifies the text direction.
pub enum Direction {
	invalid
	// Left to right.
	ltr
	// Right to left.
	rtl
	// Top to bottom.
	ttb
	// Bottom to top.
	btt
}

// Feature represents a single OpenType font feature setting for shaping.
pub struct Feature {
pub mut:
	// The 4-byte OpenType feature tag as a big-endian u32.
	tag u32
	// The value of the feature (0 = disabled, 1 = enabled, or higher).
	value u32
	// Start index in the buffer where this feature applies.
	start u32
	// End index in the buffer where this feature applies.
	end_ u32
}

// Global start constant: feature applies from the beginning of the buffer.
pub const feature_global_start = u32(0)

// Global end constant: feature applies to the end of the buffer.
pub const feature_global_end = u32(0xFFFFFFFF)

// GlyphInfo contains information about a glyph in the buffer.
// Before shaping, codepoint holds the Unicode codepoint.
// After shaping, codepoint holds the glyph index.
pub struct GlyphInfo {
pub mut:
	// Before shaping: Unicode codepoint. After shaping: glyph index.
	codepoint u32
	// Cluster value - used to map back to original codepoints.
	cluster u32
}

// GlyphPosition contains the positioning of a glyph in the buffer after shaping.
// All values are in font units (26.6 fixed point for FreeType/CoreText).
pub struct GlyphPosition {
pub mut:
	// How much the line advances after drawing this glyph (x direction).
	x_advance i32
	// How much the line advances after drawing this glyph (y direction).
	y_advance i32
	// How much the glyph moves on the x-axis before drawing.
	x_offset i32
	// How much the glyph moves on the y-axis before drawing.
	y_offset i32
}

// Font represents a HarfBuzz font object.
// Wraps an hb_font_t handle for use with the shaping API.
pub struct Font {
pub mut:
	handle voidptr
}

// Buffer is a HarfBuzz buffer for text shaping.
// The buffer holds Unicode codepoints before shaping and
// glyph indices with positions after shaping. It is reused
// across multiple shaping calls to avoid allocations.
pub struct Buffer {
pub mut:
	handle        voidptr
	content_type  ContentType
	cluster_level ClusterLevel
	direction     Direction
	infos         []GlyphInfo
	positions     []GlyphPosition
}

// create allocates a new HarfBuzz buffer.
pub fn Buffer.create() !Buffer {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_create).
	return Buffer{}
}

// destroy releases the buffer and all associated resources.
pub fn (mut b Buffer) destroy() {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_destroy).
	b.infos = []
	b.positions = []
}

// reset clears the buffer contents while retaining the buffer object.
// Unicode properties, segment properties, and flags are not cleared.
pub fn (mut b Buffer) reset() {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_reset).
	b.infos.clear()
	b.positions.clear()
}

// set_content_type sets the content type of the buffer.
pub fn (mut b Buffer) set_content_type(ct ContentType) {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_set_content_type).
	b.content_type = ct
}

// set_cluster_level sets the cluster level for the buffer.
// Setting to .characters gives the most granularity for cluster tracking.
pub fn (mut b Buffer) set_cluster_level(level ClusterLevel) {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_set_cluster_level).
	b.cluster_level = level
}

// set_direction sets the text direction for the buffer.
pub fn (mut b Buffer) set_direction(dir Direction) {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_set_direction).
	b.direction = dir
}

// add adds a single Unicode codepoint to the buffer with a cluster value.
// The cluster value is used to associate the codepoint with its source position.
pub fn (mut b Buffer) add(codepoint u32, cluster u32) {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_add).
	b.infos << GlyphInfo{
		codepoint: codepoint
		cluster: cluster
	}
}

// guess_segment_properties fills in missing buffer properties
// (direction, script, language) based on the buffer contents.
pub fn (mut b Buffer) guess_segment_properties() {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_guess_segment_properties).
}

// get_length returns the number of items in the buffer.
pub fn (b &Buffer) get_length() u32 {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_get_length).
	return u32(b.infos.len)
}

// get_glyph_infos returns the glyph information array from the buffer.
// Before shaping, codepoints are Unicode values. After shaping, they are glyph indices.
pub fn (b &Buffer) get_glyph_infos() []GlyphInfo {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_get_glyph_infos).
	return b.infos
}

// get_glyph_positions returns the glyph position array from the buffer.
// Returns none if positions are not available (e.g., before shaping).
pub fn (b &Buffer) get_glyph_positions() ?[]GlyphPosition {
	// XTODO: Needs actual HarfBuzz C library binding (hb_buffer_get_glyph_positions).
	if b.positions.len == 0 {
		return none
	}
	return b.positions
}

// shape performs text shaping on the buffer using the given font and features.
// After this call, the buffer's codepoints are replaced with glyph indices
// and positions become available via get_glyph_positions().
pub fn shape(font_ &Font, mut buf Buffer, features []Feature) {
	// XTODO: Needs actual HarfBuzz C library binding (hb_shape).
	// This function would:
	// 1. Call hb_shape(font_.handle, buf.handle, features.data, features.len)
	// 2. The buffer's codepoints get replaced with glyph indices
	// 3. Glyph positions become available via get_glyph_positions()

	// Stub: create empty positions matching infos length so that
	// downstream code can iterate info/pos pairs.
	buf.positions = []GlyphPosition{len: buf.infos.len}
}
