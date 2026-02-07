module harfbuzz

// HarfBuzz text shaping library bindings.
//
// This module provides V bindings for the HarfBuzz text shaping library,
// used for converting Unicode text into positioned glyphs.
//
// HarfBuzz is the most commonly used text shaping engine. It handles
// complex text layout including ligatures, kerning, and right-to-left
// scripts.

// C compiler flags for HarfBuzz library.
#flag darwin -I/opt/homebrew/include
#flag darwin -L/opt/homebrew/lib
#flag linux -I/usr/include/harfbuzz
#flag -lharfbuzz

#include <harfbuzz/hb.h>

// === Opaque C types ===

@[typedef]
struct C.hb_buffer_t {}

@[typedef]
struct C.hb_font_t {}

@[typedef]
struct C.hb_face_t {}

@[typedef]
struct C.hb_blob_t {}

// === C struct field declarations (only fields we access) ===
// The actual struct layouts come from the #include'd header.

struct C.hb_glyph_info_t {
	codepoint u32
	cluster   u32
}

struct C.hb_glyph_position_t {
	x_advance i32
	y_advance i32
	x_offset  i32
	y_offset  i32
}

struct C.hb_feature_t {
	tag   u32
	value u32
	start u32
	end   u32
}

// === C function declarations ===

// Buffer lifecycle
fn C.hb_buffer_create() &C.hb_buffer_t
fn C.hb_buffer_destroy(buffer &C.hb_buffer_t)
fn C.hb_buffer_reset(buffer &C.hb_buffer_t)

// Buffer properties
fn C.hb_buffer_set_content_type(buffer &C.hb_buffer_t, content_type u32)
fn C.hb_buffer_set_cluster_level(buffer &C.hb_buffer_t, cluster_level u32)
fn C.hb_buffer_set_direction(buffer &C.hb_buffer_t, direction u32)

// Buffer content
fn C.hb_buffer_add(buffer &C.hb_buffer_t, codepoint u32, cluster u32)
fn C.hb_buffer_guess_segment_properties(buffer &C.hb_buffer_t)

// Buffer results
fn C.hb_buffer_get_length(buffer &C.hb_buffer_t) u32
fn C.hb_buffer_get_glyph_infos(buffer &C.hb_buffer_t, length &u32) &C.hb_glyph_info_t
fn C.hb_buffer_get_glyph_positions(buffer &C.hb_buffer_t, length &u32) &C.hb_glyph_position_t
fn C.hb_buffer_has_positions(buffer &C.hb_buffer_t) int

// Shaping
fn C.hb_shape(font &C.hb_font_t, buffer &C.hb_buffer_t, features &C.hb_feature_t, num_features u32)

// Feature parsing
fn C.hb_feature_from_string(str &u8, len int, feature &C.hb_feature_t) int

// Font
fn C.hb_font_create(face &C.hb_face_t) &C.hb_font_t
fn C.hb_font_destroy(font &C.hb_font_t)

// Face
fn C.hb_face_create(blob &C.hb_blob_t, index u32) &C.hb_face_t
fn C.hb_face_destroy(face &C.hb_face_t)

// Blob
fn C.hb_blob_create_from_file_or_fail(file_name &u8) &C.hb_blob_t
fn C.hb_blob_destroy(blob &C.hb_blob_t)

// === V enums matching HarfBuzz C enum values ===

// ContentType specifies the type of content in a buffer.
pub enum ContentType {
	invalid = 0
	// Buffer contains Unicode codepoints (before shaping).
	unicode = 1
	// Buffer contains glyph indices (after shaping).
	glyphs = 2
}

// ClusterLevel controls the granularity of cluster tracking.
pub enum ClusterLevel {
	// Monotone graphemes: clusters merge across grapheme boundaries.
	monotone_graphemes = 0
	// Monotone characters: clusters merge within grapheme boundaries.
	monotone_characters = 1
	// Characters: each codepoint maintains its own cluster.
	// This gives the most granularity, matching CoreText behavior.
	characters = 2
}

// Direction specifies the text direction.
pub enum Direction {
	invalid = 0
	// Left to right.
	ltr = 4
	// Right to left.
	rtl = 5
	// Top to bottom.
	ttb = 6
	// Bottom to top.
	btt = 7
}

// === V wrapper types ===

// GlyphInfo contains information about a glyph in the buffer.
// Before shaping, codepoint holds the Unicode codepoint.
// After shaping, codepoint holds the glyph index.
pub struct GlyphInfo {
pub:
	// Before shaping: Unicode codepoint. After shaping: glyph index.
	codepoint u32
	// Cluster value - used to map back to original codepoints.
	cluster u32
}

// GlyphPosition contains the positioning of a glyph in the buffer after shaping.
// All values are in font units (26.6 fixed point for FreeType/CoreText).
pub struct GlyphPosition {
pub:
	// How much the line advances after drawing this glyph (x direction).
	x_advance i32
	// How much the line advances after drawing this glyph (y direction).
	y_advance i32
	// How much the glyph moves on the x-axis before drawing.
	x_offset i32
	// How much the glyph moves on the y-axis before drawing.
	y_offset i32
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
	end u32
}

// Global start constant: feature applies from the beginning of the buffer.
pub const feature_global_start = u32(0)

// Global end constant: feature applies to the end of the buffer.
pub const feature_global_end = u32(0xFFFFFFFF)

// === Buffer ===

// Buffer is a HarfBuzz buffer for text shaping.
// The buffer holds Unicode codepoints before shaping and
// glyph indices with positions after shaping. It is reused
// across multiple shaping calls to avoid allocations.
pub struct Buffer {
pub mut:
	ptr &C.hb_buffer_t = unsafe { nil }
}

// create allocates a new HarfBuzz buffer.
pub fn Buffer.create() !Buffer {
	p := C.hb_buffer_create()
	if p == unsafe { nil } {
		return error('failed to create HarfBuzz buffer')
	}
	return Buffer{ ptr: p }
}

// destroy releases the buffer and all associated resources.
pub fn (mut b Buffer) destroy() {
	if b.ptr != unsafe { nil } {
		C.hb_buffer_destroy(b.ptr)
		b.ptr = unsafe { nil }
	}
}

// reset clears the buffer contents while retaining the buffer object.
// Unicode properties, segment properties, and flags are not cleared.
pub fn (mut b Buffer) reset() {
	C.hb_buffer_reset(b.ptr)
}

// set_content_type sets the content type of the buffer.
pub fn (mut b Buffer) set_content_type(ct ContentType) {
	C.hb_buffer_set_content_type(b.ptr, u32(ct))
}

// set_cluster_level sets the cluster level for the buffer.
// Setting to .characters gives the most granularity for cluster tracking.
pub fn (mut b Buffer) set_cluster_level(level ClusterLevel) {
	C.hb_buffer_set_cluster_level(b.ptr, u32(level))
}

// set_direction sets the text direction for the buffer.
pub fn (mut b Buffer) set_direction(dir Direction) {
	C.hb_buffer_set_direction(b.ptr, u32(dir))
}

// add adds a single Unicode codepoint to the buffer with a cluster value.
// The cluster value is used to associate the codepoint with its source position.
pub fn (mut b Buffer) add(codepoint u32, cluster u32) {
	C.hb_buffer_add(b.ptr, codepoint, cluster)
}

// guess_segment_properties fills in missing buffer properties
// (direction, script, language) based on the buffer contents.
pub fn (mut b Buffer) guess_segment_properties() {
	C.hb_buffer_guess_segment_properties(b.ptr)
}

// get_length returns the number of items in the buffer.
pub fn (b &Buffer) get_length() u32 {
	return C.hb_buffer_get_length(b.ptr)
}

// get_glyph_infos returns the glyph information array from the buffer.
// Before shaping, codepoints are Unicode values. After shaping, they are glyph indices.
pub fn (b &Buffer) get_glyph_infos() []GlyphInfo {
	mut length := u32(0)
	ptr := C.hb_buffer_get_glyph_infos(b.ptr, &length)
	if ptr == unsafe { nil } || length == 0 {
		return []
	}
	mut result := []GlyphInfo{cap: int(length)}
	for i in 0 .. int(length) {
		ci := unsafe { ptr[i] }
		result << GlyphInfo{
			codepoint: ci.codepoint
			cluster: ci.cluster
		}
	}
	return result
}

// get_glyph_positions returns the glyph position array from the buffer.
// Returns none if positions are not available (e.g., before shaping).
pub fn (b &Buffer) get_glyph_positions() ?[]GlyphPosition {
	mut length := u32(0)
	ptr := C.hb_buffer_get_glyph_positions(b.ptr, &length)
	if ptr == unsafe { nil } || length == 0 {
		return none
	}
	mut result := []GlyphPosition{cap: int(length)}
	for i in 0 .. int(length) {
		cp := unsafe { ptr[i] }
		result << GlyphPosition{
			x_advance: cp.x_advance
			y_advance: cp.y_advance
			x_offset: cp.x_offset
			y_offset: cp.y_offset
		}
	}
	return result
}

// has_positions returns true if glyph positions are available in the buffer.
// Positions become available after a successful shape() call.
pub fn (b &Buffer) has_positions() bool {
	return C.hb_buffer_has_positions(b.ptr) != 0
}

// === Font ===

// Font represents a HarfBuzz font object.
// Wraps an hb_font_t handle for use with the shaping API.
pub struct Font {
pub mut:
	ptr &C.hb_font_t = unsafe { nil }
}

// create creates a HarfBuzz font from a face.
pub fn Font.create(face &Face) !Font {
	fnt := C.hb_font_create(face.ptr)
	if fnt == unsafe { nil } {
		return error('failed to create HarfBuzz font')
	}
	return Font{ ptr: fnt }
}

// destroy releases the font object.
pub fn (mut f Font) destroy() {
	if f.ptr != unsafe { nil } {
		C.hb_font_destroy(f.ptr)
		f.ptr = unsafe { nil }
	}
}

// === Face ===

// Face represents a HarfBuzz face object (a single font face from a font file).
pub struct Face {
pub mut:
	ptr &C.hb_face_t = unsafe { nil }
}

// create_from_file creates a HarfBuzz face from a font file path.
// Uses the first face in the file (index 0).
pub fn Face.create_from_file(path string) !Face {
	blob := C.hb_blob_create_from_file_or_fail(path.str)
	if blob == unsafe { nil } {
		return error('failed to load font file: ${path}')
	}
	face := C.hb_face_create(blob, 0)
	C.hb_blob_destroy(blob)
	if face == unsafe { nil } {
		return error('failed to create face from: ${path}')
	}
	return Face{ ptr: face }
}

// destroy releases the face object.
pub fn (mut f Face) destroy() {
	if f.ptr != unsafe { nil } {
		C.hb_face_destroy(f.ptr)
		f.ptr = unsafe { nil }
	}
}

// === Shaping ===

// shape performs text shaping on the buffer using the given font and features.
// After this call, the buffer's codepoints are replaced with glyph indices
// and positions become available via get_glyph_positions().
// If the font pointer is nil, the function is a no-op.
pub fn shape(fnt Font, buf Buffer, features []Feature) {
	if fnt.ptr == unsafe { nil } {
		return
	}
	if features.len == 0 {
		C.hb_shape(fnt.ptr, buf.ptr, unsafe { nil }, 0)
	} else {
		mut c_feats := []C.hb_feature_t{len: features.len}
		for i, f in features {
			c_feats[i] = C.hb_feature_t{
				tag: f.tag
				value: f.value
				start: f.start
				end: f.end
			}
		}
		unsafe { C.hb_shape(fnt.ptr, buf.ptr, &c_feats[0], u32(features.len)) }
	}
}

// === Feature parsing ===

// feature_from_string parses a feature string using HarfBuzz's built-in parser.
// Supported formats include: "liga", "+liga", "-liga", "kern=0", "aalt[3:5]=2".
// Returns none if the string cannot be parsed.
pub fn feature_from_string(s string) ?Feature {
	mut cf := C.hb_feature_t{}
	if C.hb_feature_from_string(s.str, int(s.len), &cf) != 0 {
		return Feature{
			tag: cf.tag
			value: cf.value
			start: cf.start
			end: cf.end
		}
	}
	return none
}
