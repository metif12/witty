module freetype

// Stub FreeType library bindings.
// XTODO: Replace with real FreeType C bindings when available.
//
// This module provides type stubs and default-returning functions
// to allow the font module to compile without the FreeType C library.

import math

// ============================================================
// Constants
// ============================================================

// Pixel modes
pub const pixel_mode_gray = u8(2)
pub const pixel_mode_bgra = u8(7)

// Glyph formats (FourCC tags)
pub const glyph_format_outline = u32(0x6F75746C) // 'outl'
pub const glyph_format_bitmap = u32(0x62697473) // 'bits'

// Face flags
pub const face_flag_scalable = i64(1 << 0)

// Name IDs
pub const tt_name_id_font_family = u16(1)

// Platform IDs
pub const tt_platform_microsoft = u16(3)

// Encoding IDs
pub const tt_ms_id_unicode_cs = u16(1)

// ============================================================
// Enums
// ============================================================

// Encoding specifies the character map encoding.
pub enum Encoding {
	unicode
}

// RenderMode specifies the glyph rendering target.
pub enum RenderMode {
	normal
	light
	mono
}

// SfntTag identifies SFNT table types.
pub enum SfntTag {
	head
	post
	os2
	hhea
}

// ============================================================
// Core structs (mirror FreeType C structs)
// ============================================================

// FaceRec mirrors the FreeType FT_FaceRec structure.
pub struct FaceRec {
pub mut:
	num_fixed_sizes i32
	available_sizes &BitmapSize = unsafe { nil }
	face_flags      i64
	units_per_em    u16
	glyph           &GlyphSlotRec = unsafe { nil }
	size            &SizeRec = unsafe { nil }
}

// BitmapSize describes a fixed bitmap strike size.
pub struct BitmapSize {
pub:
	width i16
}

// SizeRec holds the current size metrics.
pub struct SizeRec {
pub:
	metrics SizeMetrics
}

// SizeMetrics holds scalable size metrics (26.6 fixed-point).
pub struct SizeMetrics {
pub:
	x_ppem      u16
	y_ppem      u16
	x_scale     i64
	y_scale     i64
	ascender    i64
	descender   i64
	height      i64
	max_advance i64
}

// GlyphSlotRec holds glyph rendering data.
pub struct GlyphSlotRec {
pub mut:
	advance     Vector
	metrics     GlyphMetrics
	bitmap      Bitmap
	bitmap_left i32
	bitmap_top  i32
	outline     Outline
	format      u32
}

// Vector holds 2D coordinates (26.6 fixed-point).
pub struct Vector {
pub:
	x i64
	y i64
}

// GlyphMetrics holds metrics for a loaded glyph.
pub struct GlyphMetrics {
pub:
	width          i64
	height         i64
	hori_bearing_x i64
	hori_bearing_y i64
}

// Bitmap holds a rendered glyph bitmap.
pub struct Bitmap {
pub mut:
	width      u32
	rows       u32
	pitch      i32
	buffer     &u8 = unsafe { nil }
	pixel_mode u8
	num_grays  u16
}

// BBox holds a bounding box (26.6 fixed-point).
pub struct BBox {
pub mut:
	x_min i64
	y_min i64
	x_max i64
	y_max i64
}

// Outline holds glyph outline data.
pub struct Outline {
pub mut:
	n_points i32
	points   &OutlinePoint = unsafe { nil }
}

// OutlinePoint holds a single outline point (26.6 fixed-point).
pub struct OutlinePoint {
pub mut:
	x i32
	y i32
}

// ============================================================
// SFNT Name table entry
// ============================================================

// SfntName holds an entry from the SFNT name table.
pub struct SfntName {
pub:
	name_id     u16
	platform_id u16
	encoding_id u16
	string_data []u8
	string_len  u32
}

// ============================================================
// Multiple Master / Variation Axis
// ============================================================

// MMVar holds multiple master / OpenType variation info.
pub struct MMVar {
pub:
	num_axis u32
	axis     []MMAxis
}

// MMAxis describes a single variation axis.
pub struct MMAxis {
pub:
	tag     u64
	name    string
	minimum i64
	maximum i64
	def     i64
}

// ============================================================
// TrueType table structs
// ============================================================

// TT_Header mirrors the 'head' table.
pub struct TT_Header {
pub:
	units_per_em u16
}

// TT_Postscript mirrors the 'post' table.
pub struct TT_Postscript {
pub:
	underline_position  i16
	underline_thickness i16
}

// TT_OS2 mirrors the OS/2 table.
pub struct TT_OS2 {
pub:
	version              u16
	s_typo_ascender      i16
	s_typo_descender     i16
	s_typo_line_gap      i16
	fs_selection         u16
	us_win_ascent        u16
	us_win_descent       u16
	s_cap_height         i16
	sx_height            i16
	y_strikeout_size     i16
	y_strikeout_position i16
}

// TT_HoriHeader mirrors the 'hhea' table.
pub struct TT_HoriHeader {
pub:
	ascender  i16
	descender i16
	line_gap  i16
}

// ============================================================
// Utility types
// ============================================================

// LoadFlags controls FreeType glyph loading behavior.
pub struct LoadFlags {
pub:
	render         bool
	color          bool
	no_hinting     bool
	force_autohint bool
	no_autohint    bool
	no_svg         bool
	target         RenderMode = .normal
}

// Tag represents a 4-byte OpenType table tag.
pub struct Tag {
pub:
	value u32
}

// init creates a Tag from a 4-byte string.
pub fn Tag.init(s string) Tag {
	if s.len < 4 {
		return Tag{}
	}
	return Tag{
		value: (u32(s[0]) << 24) | (u32(s[1]) << 16) | (u32(s[2]) << 8) | u32(s[3])
	}
}

// F26Dot6 is a 26.6 fixed-point number used by FreeType.
pub struct F26Dot6 {
pub:
	value i32
}

// from_f64 converts an f64 to 26.6 fixed-point.
pub fn F26Dot6.from_f64(v f64) F26Dot6 {
	return F26Dot6{
		value: i32(math.round(v * 64.0))
	}
}

// to_f64 converts a 26.6 fixed-point number to f64.
pub fn (f F26Dot6) to_f64() f64 {
	return f64(f.value) / 64.0
}

// ============================================================
// Library (wraps FT_Library)
// ============================================================

// Library represents the FreeType library instance.
pub struct Library {
pub mut:
	handle voidptr
}

// init creates a new FreeType library instance.
// XTODO: needs real FreeType C binding (FT_Init_FreeType).
pub fn Library.init() !Library {
	return Library{}
}

// deinit destroys the FreeType library instance.
pub fn (mut l Library) deinit() {
	// XTODO: call FT_Done_FreeType
}

// init_face creates a new face from a file path.
pub fn (l Library) init_face(path string, index i32) !Face {
	// XTODO: call FT_New_Face
	return Face{}
}

// init_memory_face creates a new face from in-memory data.
pub fn (l Library) init_memory_face(data []u8, index i32) !Face {
	// XTODO: call FT_New_Memory_Face
	return Face{}
}

// done_mm_var frees a multiple master variation struct.
pub fn (l Library) done_mm_var(mm &MMVar) {
	// XTODO: call FT_Done_MM_Var
}

// ============================================================
// Face (wraps FT_Face)
// ============================================================

// Face represents a FreeType font face.
pub struct Face {
pub mut:
	handle &FaceRec = unsafe { nil }
}

// deinit destroys this font face.
pub fn (mut f Face) deinit() {
	// XTODO: call FT_Done_Face
}

// ref increases the reference count of this face.
pub fn (f Face) ref() {
	// XTODO: call FT_Reference_Face
}

// select_charmap selects a character map encoding.
pub fn (f Face) select_charmap(encoding Encoding) ! {
	// XTODO: call FT_Select_Charmap
}

// set_char_size sets the character size in 26.6 fractional points.
pub fn (f Face) set_char_size(width i32, height i32, h_res u32, v_res u32) ! {
	// XTODO: call FT_Set_Char_Size
}

// load_glyph loads a glyph into the glyph slot.
pub fn (f Face) load_glyph(glyph_index u32, flags LoadFlags) ! {
	// XTODO: call FT_Load_Glyph with converted flags
}

// render_glyph renders a loaded glyph to a bitmap.
pub fn (f Face) render_glyph(mode RenderMode) ! {
	// XTODO: call FT_Render_Glyph
}

// get_char_index returns the glyph index for a Unicode codepoint.
// Returns none if the codepoint is not in the font.
pub fn (f Face) get_char_index(code u32) ?u32 {
	// XTODO: call FT_Get_Char_Index, return none if 0
	return none
}

// has_color returns true if the font has color (e.g., emoji) glyphs.
pub fn (f Face) has_color() bool {
	// XTODO: check FT_HAS_COLOR flag
	return false
}

// is_scalable returns true if the font is in a scalable format.
pub fn (f Face) is_scalable() bool {
	if f.handle == unsafe { nil } {
		return true
	}
	return f.handle.face_flags & face_flag_scalable != 0
}

// has_multiple_masters returns true if the font supports OpenType variations.
pub fn (f Face) has_multiple_masters() bool {
	// XTODO: check FT_HAS_MULTIPLE_MASTERS flag
	return false
}

// get_mm_var returns the multiple master / variation data.
pub fn (f Face) get_mm_var() !MMVar {
	// XTODO: call FT_Get_MM_Var
	return error('no multiple masters')
}

// set_var_design_coordinates sets variation axis coordinates.
pub fn (f Face) set_var_design_coordinates(coords []i64) ! {
	// XTODO: call FT_Set_Var_Design_Coordinates
}

// get_var_design_coordinates gets current variation axis coordinates.
pub fn (f Face) get_var_design_coordinates(mut coords []i64) ! {
	// XTODO: call FT_Get_Var_Design_Coordinates
}

// get_sfnt_name_count returns the number of name table entries.
pub fn (f Face) get_sfnt_name_count() u32 {
	// XTODO: call FT_Get_Sfnt_Name_Count
	return 0
}

// get_sfnt_name returns the name table entry at the given index.
pub fn (f Face) get_sfnt_name(index u32) !SfntName {
	// XTODO: call FT_Get_Sfnt_Name
	return error('no sfnt name')
}

// get_sfnt_table returns a pointer to the specified SFNT table.
// The returned pointer type depends on the tag:
//   .head -> &TT_Header
//   .post -> &TT_Postscript
//   .os2  -> &TT_OS2
//   .hhea -> &TT_HoriHeader
pub fn (f Face) get_sfnt_table_head() ?&TT_Header {
	// XTODO: call FT_Get_Sfnt_Table(FT_SFNT_HEAD)
	return none
}

pub fn (f Face) get_sfnt_table_post() ?&TT_Postscript {
	// XTODO: call FT_Get_Sfnt_Table(FT_SFNT_POST)
	return none
}

pub fn (f Face) get_sfnt_table_os2() ?&TT_OS2 {
	// XTODO: call FT_Get_Sfnt_Table(FT_SFNT_OS2)
	return none
}

pub fn (f Face) get_sfnt_table_hhea() ?&TT_HoriHeader {
	// XTODO: call FT_Get_Sfnt_Table(FT_SFNT_HHEA)
	return none
}

// select_size selects a fixed bitmap strike by index.
pub fn (f Face) select_size(index i32) ! {
	// XTODO: call FT_Select_Size
}

// load_sfnt_table loads raw SFNT table data by tag.
pub fn (f Face) load_sfnt_table(tag Tag) ![]u8 {
	// XTODO: call FT_Load_Sfnt_Table
	return error('table not found')
}

// ============================================================
// Bitmap operations (stubs)
// ============================================================

// bitmap_init initializes a bitmap to empty.
pub fn bitmap_init(mut bm Bitmap) {
	bm = Bitmap{}
}

// bitmap_done frees bitmap data.
pub fn bitmap_done(lib Library, mut bm Bitmap) {
	// XTODO: call FT_Bitmap_Done
}

// bitmap_convert converts a bitmap to a different format.
pub fn bitmap_convert(lib Library, source &Bitmap, mut target Bitmap, alignment i32) ! {
	// XTODO: call FT_Bitmap_Convert
}

// bitmap_copy copies a bitmap.
pub fn bitmap_copy(lib Library, source &Bitmap, mut target Bitmap) ! {
	// XTODO: call FT_Bitmap_Copy
}

// ============================================================
// Outline operations (stubs)
// ============================================================

// outline_get_bbox computes the bounding box of an outline.
pub fn outline_get_bbox(outline &Outline, mut bbox BBox) {
	// XTODO: call FT_Outline_Get_BBox
}

// outline_embolden thickens an outline.
pub fn outline_embolden(mut outline Outline, strength i64) {
	// XTODO: call FT_Outline_Embolden
}

// glyph_slot_own_bitmap ensures the glyph slot owns its bitmap.
pub fn glyph_slot_own_bitmap(mut glyph GlyphSlotRec) ! {
	// XTODO: call FT_GlyphSlot_Own_Bitmap
}

// ============================================================
// Fixed-point math
// ============================================================

// mul_fix performs a 16.16 fixed-point multiply.
pub fn mul_fix(a i64, b i64) i64 {
	return (a * b + 0x8000) >> 16
}

// f26dot6_to_f64 converts a raw 26.6 fixed-point i64 to f64.
pub fn f26dot6_to_f64(v i64) f64 {
	return F26Dot6{ value: i32(v) }.to_f64()
}

// f26dot6_to_f32 converts a raw 26.6 fixed-point i64 to f32.
pub fn f26dot6_to_f32(v i64) f32 {
	return f32(v >> 6)
}
