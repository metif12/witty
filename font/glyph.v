module font

// Glyph is a single loaded glyph for a face.
// Translated from ghostty/src/font/Glyph.zig.
pub struct Glyph {
pub mut:
	// Width and height of the glyph in pixels.
	width  u32
	height u32
	// Left and top bearings.
	offset_x i32
	offset_y i32
	// Top-left coordinates in the atlas. These are normalized before shaders
	// consume them.
	atlas_x u32
	atlas_y u32
}
