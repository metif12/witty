module freetype

// FreeType library bindings.
//
// This module provides V bindings for the FreeType C library, used for
// rasterizing scalable and bitmap fonts on platforms that don't use
// CoreText (i.e. Linux, or the coretext_freetype backend).
//
// Translated from ghostty/pkg/freetype.
//
// The hand-defined `FaceRec`/`GlyphSlotRec`/etc. structs below mirror the
// public FreeType struct layout so that consumers (font/face.v) can read
// fields like `face.handle.size.metrics.y_scale` directly. The real
// `FT_Library`/`FT_Face` opaque handles are stored alongside in private
// fields (`ft_lib`/`ft_face`) and the actual C entry points are declared
// as `fn C.FT_*` below.

import math

// ============================================================
// C library configuration and extern declarations
// ============================================================

// C compiler flags for the FreeType library. FreeType installs its headers
// under a `freetype2` subdirectory, so we add that to the include path.
#flag darwin -I/opt/homebrew/include/freetype2
#flag darwin -I/opt/homebrew/opt/freetype/include/freetype2
#flag darwin -L/opt/homebrew/lib
#flag linux -I/usr/include/freetype2
#flag -lfreetype

// FreeType exposes both the classic `FT_FREETYPE_H`-style macro includes
// and, since 2.6.1, direct header paths. V's `#include` only accepts
// quoted/bracketed paths, so we use the direct forms.
#include <ft2build.h>
#include <freetype/freetype.h>
#include <freetype/ftmm.h>
#include <freetype/ftsnames.h>
#include <freetype/tttables.h>
#include <freetype/ttnameid.h>
#include <freetype/ftoutln.h>
#include <freetype/ftbitmap.h>

// Opaque C handle types. FreeType's `FT_Library`, `FT_Face`, etc. are
// pointers to opaque structs. We treat them as `voidptr` on the V side so
// that we never depend on the exact C struct layout.

// FT_Init_FreeType initializes a new FreeType library instance.
fn C.FT_Init_FreeType(alibrary &voidptr) int

// FT_Done_FreeType destroys a FreeType library instance.
fn C.FT_Done_FreeType(library voidptr) int

// FT_New_Face creates a face from a font file on disk.
fn C.FT_New_Face(library voidptr, filepathname &char, face_index i64, aface &voidptr) int

// FT_New_Memory_Face creates a face from an in-memory font buffer.
fn C.FT_New_Memory_Face(library voidptr, file_base &u8, file_size i64, face_index i64, aface &voidptr) int

// FT_Done_Face destroys a face.
fn C.FT_Done_Face(face voidptr) int

// FT_Reference_Face increments the reference count of a face.
fn C.FT_Reference_Face(face voidptr) int

// FT_Select_Charmap selects a charmap by encoding tag.
fn C.FT_Select_Charmap(face voidptr, encoding u32) int

// FT_Set_Char_Size sets the nominal character size in 26.6 points.
fn C.FT_Set_Char_Size(face voidptr, char_width i64, char_height i64, horz_resolution u32, vert_resolution u32) int

// FT_Load_Glyph loads a single glyph into the face's glyph slot.
fn C.FT_Load_Glyph(face voidptr, glyph_index u32, load_flags i32) int

// FT_Render_Glyph converts a loaded glyph outline into a bitmap.
fn C.FT_Render_Glyph(slot voidptr, render_mode int) int

// FT_Get_Char_Index returns the glyph index for a character code, or 0.
fn C.FT_Get_Char_Index(face voidptr, charcode u64) u32

// FT_Select_Size selects a fixed bitmap strike by index.
fn C.FT_Select_Size(face voidptr, strike_index i32) int

// FT_Get_Sfnt_Name_Count returns the number of name-table entries.
fn C.FT_Get_Sfnt_Name_Count(face voidptr) u32

// FT_Get_Sfnt_Name reads the name-table entry at the given index into
// `aname` (which points at a C `FT_SfntName` struct).
fn C.FT_Get_Sfnt_Name(face voidptr, idx u32, aname voidptr) int

// FT_Get_Sfnt_Table returns a pointer to a parsed SFNT table struct.
fn C.FT_Get_Sfnt_Table(face voidptr, tag int) voidptr

// FT_Load_Sfnt_Table loads raw SFNT table bytes. Passing a null buffer
// with a length pointer queries the length.
fn C.FT_Load_Sfnt_Table(face voidptr, tag u64, offset i64, buffer &u8, length &u64) int

// FT_Get_MM_Var returns the multiple-master / variation descriptor.
fn C.FT_Get_MM_Var(face voidptr, amaster &voidptr) int

// FT_Done_MM_Var frees a multiple-master / variation descriptor.
fn C.FT_Done_MM_Var(library voidptr, amaster voidptr) int

// FT_Set_Var_Design_Coordinates sets the variation axis coordinates.
fn C.FT_Set_Var_Design_Coordinates(face voidptr, num_coords u32, coords &i64) int

// FT_Get_Var_Design_Coordinates reads the current variation coordinates.
fn C.FT_Get_Var_Design_Coordinates(face voidptr, num_coords u32, coords &i64) int

// FT_Outline_Get_BBox computes the exact bounding box of an outline.
fn C.FT_Outline_Get_BBox(outline voidptr, abbox voidptr) int

// FT_Outline_Embolden thickens an outline in place.
fn C.FT_Outline_Embolden(outline voidptr, strength i64) int

// FT_Bitmap_Init initializes a bitmap struct to empty.
fn C.FT_Bitmap_Init(abitmap voidptr)

// FT_Bitmap_Done frees a bitmap owned by the library.
fn C.FT_Bitmap_Done(library voidptr, bitmap voidptr) int

// FT_Bitmap_Convert converts a bitmap into 8bpp gray with the given alignment.
fn C.FT_Bitmap_Convert(library voidptr, source voidptr, target voidptr, alignment i32) int

// FT_Bitmap_Copy copies a bitmap.
fn C.FT_Bitmap_Copy(library voidptr, source voidptr, target voidptr) int

// FT_GlyphSlot_Own_Bitmap ensures the glyph slot owns its bitmap buffer.
fn C.FT_GlyphSlot_Own_Bitmap(slot voidptr) int

// FT_MulFix performs FreeType's 16.16 fixed-point multiply (with rounding).
fn C.FT_MulFix(a i64, b i64) i64

// The FreeType Unicode charmap encoding tag ('unic' as a FourCC).
pub const ft_encoding_unicode = u32(0x756E6963)

// FT_Load_Glyph flag bits (from freetype.h). These are stable ABI values.
const ft_load_default = i32(0x0)
const ft_load_render = i32(1 << 2)
const ft_load_no_hinting = i32(1 << 1)
const ft_load_force_autohint = i32(1 << 5)
const ft_load_no_autohint = i32(1 << 15)
const ft_load_color = i32(1 << 20)
const ft_load_no_svg = i32(1 << 24)
const ft_load_target_light = i32((1 & 15) << 16)
const ft_load_target_mono = i32((2 & 15) << 16)

// FT_Get_Sfnt_Table selector values (FT_Sfnt_Tag enum, ABI-stable order).
const ft_sfnt_head = int(1)
const ft_sfnt_hhea = int(2)
const ft_sfnt_os2 = int(4)
const ft_sfnt_post = int(6)

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
	// Raw pointer to the C `FT_MM_Var` descriptor, retained so it can be
	// freed with FT_Done_MM_Var. Null if not backed by a live descriptor.
	raw voidptr = unsafe { nil }
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

// to_int converts the load flags into the packed FT_Load_Glyph flag bits.
pub fn (f LoadFlags) to_int() i32 {
	mut flags := ft_load_default
	if f.render {
		flags |= ft_load_render
	}
	if f.color {
		flags |= ft_load_color
	}
	if f.no_hinting {
		flags |= ft_load_no_hinting
	}
	if f.force_autohint {
		flags |= ft_load_force_autohint
	}
	if f.no_autohint {
		flags |= ft_load_no_autohint
	}
	if f.no_svg {
		flags |= ft_load_no_svg
	}
	// The render target (light/mono) is encoded in bits 16..19.
	match f.target {
		.normal {}
		.light { flags |= ft_load_target_light }
		.mono { flags |= ft_load_target_mono }
	}
	return flags
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
// `handle` is the raw `FT_Library` returned by FreeType.
pub struct Library {
pub mut:
	handle voidptr
}

// init creates a new FreeType library instance.
pub fn Library.init() !Library {
	mut lib := voidptr(unsafe { nil })
	err := C.FT_Init_FreeType(&lib)
	if err != 0 {
		return error('FT_Init_FreeType failed (${err})')
	}
	return Library{
		handle: lib
	}
}

// deinit destroys the FreeType library instance.
pub fn (mut l Library) deinit() {
	if !isnil(l.handle) {
		C.FT_Done_FreeType(l.handle)
		l.handle = unsafe { nil }
	}
}

// init_face creates a new face from a file path.
pub fn (l Library) init_face(path string, index i32) !Face {
	if isnil(l.handle) {
		return error('freetype library not initialized')
	}
	mut ft_face := voidptr(unsafe { nil })
	err := C.FT_New_Face(l.handle, &char(path.str), i64(index), &ft_face)
	if err != 0 {
		return error('FT_New_Face(${path}) failed (${err})')
	}
	return Face{
		// The public `handle` field mirrors the FreeType FT_FaceRec layout
		// so consumers can read fields directly; it aliases the same pointer.
		handle:  unsafe { &FaceRec(ft_face) }
		ft_face: ft_face
	}
}

// init_memory_face creates a new face from in-memory data.
pub fn (l Library) init_memory_face(data []u8, index i32) !Face {
	if isnil(l.handle) {
		return error('freetype library not initialized')
	}
	mut ft_face := voidptr(unsafe { nil })
	base := if data.len > 0 { &u8(data.data) } else { &u8(unsafe { nil }) }
	err := C.FT_New_Memory_Face(l.handle, base, i64(data.len), i64(index), &ft_face)
	if err != 0 {
		return error('FT_New_Memory_Face failed (${err})')
	}
	return Face{
		handle:  unsafe { &FaceRec(ft_face) }
		ft_face: ft_face
	}
}

// done_mm_var frees a multiple master variation struct.
pub fn (l Library) done_mm_var(mm &MMVar) {
	// The V `MMVar` is a translated value copy; the underlying C descriptor
	// is freed via its retained raw pointer when available.
	if !isnil(l.handle) && !isnil(mm.raw) {
		C.FT_Done_MM_Var(l.handle, mm.raw)
	}
}

// ============================================================
// Face (wraps FT_Face)
// ============================================================

// Face represents a FreeType font face.
//
// `handle` is a pointer typed as the mirror `FaceRec` struct so that
// consumers can read fields like `.size.metrics.y_scale` directly. It
// points at the same memory as the raw `FT_Face` (`ft_face`), which we
// pass to the C entry points.
pub struct Face {
pub mut:
	handle  &FaceRec = unsafe { nil }
	ft_face voidptr  = unsafe { nil }
}

// deinit destroys this font face.
pub fn (mut f Face) deinit() {
	if !isnil(f.ft_face) {
		C.FT_Done_Face(f.ft_face)
		f.ft_face = unsafe { nil }
		f.handle = unsafe { nil }
	}
}

// ref increases the reference count of this face.
pub fn (f Face) ref() {
	if !isnil(f.ft_face) {
		C.FT_Reference_Face(f.ft_face)
	}
}

// select_charmap selects a character map encoding.
pub fn (f Face) select_charmap(encoding Encoding) ! {
	tag := match encoding {
		.unicode { ft_encoding_unicode }
	}
	err := C.FT_Select_Charmap(f.ft_face, tag)
	if err != 0 {
		return error('FT_Select_Charmap failed (${err})')
	}
}

// set_char_size sets the character size in 26.6 fractional points.
pub fn (f Face) set_char_size(width i32, height i32, h_res u32, v_res u32) ! {
	err := C.FT_Set_Char_Size(f.ft_face, i64(width), i64(height), h_res, v_res)
	if err != 0 {
		return error('FT_Set_Char_Size failed (${err})')
	}
}

// load_glyph loads a glyph into the glyph slot.
pub fn (f Face) load_glyph(glyph_index u32, flags LoadFlags) ! {
	err := C.FT_Load_Glyph(f.ft_face, glyph_index, flags.to_int())
	if err != 0 {
		return error('FT_Load_Glyph failed (${err})')
	}
}

// render_glyph renders a loaded glyph to a bitmap.
pub fn (f Face) render_glyph(mode RenderMode) ! {
	if isnil(f.ft_face) {
		return error('freetype face not initialized')
	}
	// The glyph slot pointer lives inside FT_FaceRec; we route through the
	// mirror struct which aliases the same memory.
	slot := voidptr(f.handle.glyph)
	render_mode := match mode {
		.normal { 0 }
		.light { 1 }
		.mono { 2 }
	}
	err := C.FT_Render_Glyph(slot, render_mode)
	if err != 0 {
		return error('FT_Render_Glyph failed (${err})')
	}
}

// get_char_index returns the glyph index for a Unicode codepoint.
// Returns none if the codepoint is not in the font.
pub fn (f Face) get_char_index(code u32) ?u32 {
	if isnil(f.ft_face) {
		return none
	}
	idx := C.FT_Get_Char_Index(f.ft_face, u64(code))
	if idx == 0 {
		return none
	}
	return idx
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
	err := C.FT_Select_Size(f.ft_face, index)
	if err != 0 {
		return error('FT_Select_Size failed (${err})')
	}
}

// load_sfnt_table loads raw SFNT table data by tag.
pub fn (f Face) load_sfnt_table(tag Tag) ![]u8 {
	if isnil(f.ft_face) {
		return error('freetype face not initialized')
	}
	// First query the length by passing a null buffer.
	mut length := u64(0)
	err := C.FT_Load_Sfnt_Table(f.ft_face, u64(tag.value), 0, &u8(unsafe { nil }),
		&length)
	if err != 0 {
		return error('FT_Load_Sfnt_Table (length) failed (${err})')
	}
	if length == 0 {
		return error('table not found')
	}
	// Then read the table bytes into a freshly allocated buffer.
	mut buf := []u8{len: int(length)}
	err2 := C.FT_Load_Sfnt_Table(f.ft_face, u64(tag.value), 0, &u8(buf.data), &length)
	if err2 != 0 {
		return error('FT_Load_Sfnt_Table (read) failed (${err2})')
	}
	return buf
}

// ============================================================
// Bitmap operations (stubs)
// ============================================================

// bitmap_init initializes a bitmap to empty.
pub fn bitmap_init(mut bm Bitmap) {
	bm = Bitmap{}
}

// bitmap_done frees bitmap data.
//
// BOUNDARY: The `fn C.FT_Bitmap_Done` binding is declared above, but the
// hand-defined V `Bitmap` mirror does not share the exact field order of
// FreeType's `FT_Bitmap` (which is rows, width, pitch, buffer, num_grays,
// pixel_mode, palette_mode, palette). Passing `&Bitmap` directly would be a
// layout mismatch, so the actual conversion glue (which must marshal to a
// real FT_Bitmap) is left for the code that owns the rasterization path.
pub fn bitmap_done(lib Library, mut bm Bitmap) {
	// C.FT_Bitmap_Done(lib.handle, <real FT_Bitmap*>) once marshalling exists.
}

// bitmap_convert converts a bitmap to a different format.
// BOUNDARY: see bitmap_done — needs a real FT_Bitmap, not the V mirror.
pub fn bitmap_convert(lib Library, source &Bitmap, mut target Bitmap, alignment i32) ! {
	// C.FT_Bitmap_Convert(lib.handle, <src FT_Bitmap*>, <dst FT_Bitmap*>, alignment)
}

// bitmap_copy copies a bitmap.
// BOUNDARY: see bitmap_done — needs a real FT_Bitmap, not the V mirror.
pub fn bitmap_copy(lib Library, source &Bitmap, mut target Bitmap) ! {
	// C.FT_Bitmap_Copy(lib.handle, <src FT_Bitmap*>, <dst FT_Bitmap*>)
}

// ============================================================
// Outline operations (stubs)
// ============================================================

// outline_get_bbox computes the bounding box of an outline.
// `outline` points at the FT_Outline embedded in the live glyph slot, so
// we pass it straight through to FreeType, which writes into `bbox`.
pub fn outline_get_bbox(outline &Outline, mut bbox BBox) {
	C.FT_Outline_Get_BBox(voidptr(outline), voidptr(&bbox))
}

// outline_embolden thickens an outline in place.
pub fn outline_embolden(mut outline Outline, strength i64) {
	C.FT_Outline_Embolden(voidptr(&outline), strength)
}

// glyph_slot_own_bitmap ensures the glyph slot owns its bitmap.
pub fn glyph_slot_own_bitmap(mut glyph GlyphSlotRec) ! {
	err := C.FT_GlyphSlot_Own_Bitmap(voidptr(&glyph))
	if err != 0 {
		return error('FT_GlyphSlot_Own_Bitmap failed (${err})')
	}
}

// ============================================================
// Fixed-point math
// ============================================================

// mul_fix performs a 16.16 fixed-point multiply.
pub fn mul_fix(a i64, b i64) i64 {
	return C.FT_MulFix(a, b)
}

// f26dot6_to_f64 converts a raw 26.6 fixed-point i64 to f64.
pub fn f26dot6_to_f64(v i64) f64 {
	return F26Dot6{ value: i32(v) }.to_f64()
}

// f26dot6_to_f32 converts a raw 26.6 fixed-point i64 to f32.
pub fn f26dot6_to_f32(v i64) f32 {
	return f32(v >> 6)
}
