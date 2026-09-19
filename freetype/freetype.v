module freetype

// FreeType library bindings.
//
// This module provides V bindings for the FreeType C library, used for
// rasterizing scalable and bitmap fonts on platforms that don't use
// CoreText (i.e. Linux, or the coretext_freetype backend).
//
// Translated from ghostty/pkg/freetype.
//
// FT_Face and FT_GlyphSlot are accessed only through the C bridge helpers
// below. Their public C records contain platform-dependent integer widths,
// so mirroring those records directly in V is not ABI-safe.

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

#include <freetype/ftbbox.h>

#include <freetype/ftbitmap.h>

#include "bridge.h"

// Opaque C handle types. FreeType's `FT_Library`, `FT_Face`, etc. are
// pointers to opaque structs. We treat them as `voidptr` on the V side so
// that we never depend on the exact C struct layout.

// FT_Init_FreeType initializes a new FreeType library instance.
fn C.FT_Init_FreeType(alibrary &voidptr) int

// FT_Done_FreeType destroys a FreeType library instance.
fn C.FT_Done_FreeType(library voidptr) int

// FT_Library_Version returns the runtime library version.
fn C.FT_Library_Version(library voidptr, major &int, minor &int, patch &int)

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

// FT_Set_Transform sets the transform applied while loading glyphs.
fn C.FT_Set_Transform(face voidptr, matrix voidptr, delta voidptr)

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

fn C.witty_ft_has_fixed_sizes(face voidptr) int

fn C.witty_ft_has_color(face voidptr) int

fn C.witty_ft_has_sbix(face voidptr) int

fn C.witty_ft_has_multiple_masters(face voidptr) int

fn C.witty_ft_is_scalable(face voidptr) int

fn C.witty_ft_glyph(face voidptr) voidptr

fn C.witty_ft_size(face voidptr) voidptr

fn C.witty_ft_face_flags(face voidptr) i64

fn C.witty_ft_units_per_em(face voidptr) u16

fn C.witty_ft_num_fixed_sizes(face voidptr) i32

fn C.witty_ft_fixed_size_width(face voidptr, index i32) i16

fn C.witty_ft_size_x_ppem(size voidptr) u16

fn C.witty_ft_size_y_ppem(size voidptr) u16

fn C.witty_ft_size_x_scale(size voidptr) i64

fn C.witty_ft_size_y_scale(size voidptr) i64

fn C.witty_ft_size_ascender(size voidptr) i64

fn C.witty_ft_size_descender(size voidptr) i64

fn C.witty_ft_size_height(size voidptr) i64

fn C.witty_ft_size_max_advance(size voidptr) i64

fn C.witty_ft_glyph_advance_x(slot voidptr) i64

fn C.witty_ft_glyph_advance_y(slot voidptr) i64

fn C.witty_ft_glyph_width(slot voidptr) i64

fn C.witty_ft_glyph_height(slot voidptr) i64

fn C.witty_ft_glyph_bearing_x(slot voidptr) i64

fn C.witty_ft_glyph_bearing_y(slot voidptr) i64

fn C.witty_ft_glyph_bitmap_left(slot voidptr) i32

fn C.witty_ft_glyph_bitmap_top(slot voidptr) i32

fn C.witty_ft_glyph_format(slot voidptr) u32

fn C.witty_ft_glyph_bitmap(slot voidptr) voidptr

fn C.witty_ft_glyph_outline(slot voidptr) voidptr

fn C.witty_ft_outline_n_points(outline voidptr) i16

fn C.witty_ft_outline_point_x(outline voidptr, index i32) i64

fn C.witty_ft_outline_point_y(outline voidptr, index i32) i64

fn C.witty_ft_outline_set_point(outline voidptr, index i32, x i64, y i64)

fn C.witty_ft_bitmap_rows(bitmap voidptr) u32

fn C.witty_ft_bitmap_width(bitmap voidptr) u32

fn C.witty_ft_bitmap_pitch(bitmap voidptr) int

fn C.witty_ft_bitmap_buffer(bitmap voidptr) &u8

fn C.witty_ft_bitmap_num_grays(bitmap voidptr) u16

fn C.witty_ft_bitmap_pixel_mode(bitmap voidptr) u8

fn C.witty_ft_mm_num_axis(mm voidptr) u32

fn C.witty_ft_mm_axis_tag(mm voidptr, index u32) u64

fn C.witty_ft_mm_axis_name(mm voidptr, index u32) &char

fn C.witty_ft_mm_axis_minimum(mm voidptr, index u32) i64

fn C.witty_ft_mm_axis_default(mm voidptr, index u32) i64

fn C.witty_ft_mm_axis_maximum(mm voidptr, index u32) i64

fn C.witty_ft_get_sfnt_name(face voidptr, index u32, name_id &u16, platform_id &u16, encoding_id &u16, bytes &&u8, length &u32) int

fn C.witty_tt_head_units_per_em(table voidptr) u16

fn C.witty_tt_post_underline_position(table voidptr) i16

fn C.witty_tt_post_underline_thickness(table voidptr) i16

fn C.witty_tt_os2_version(table voidptr) u16

fn C.witty_tt_os2_typo_ascender(table voidptr) i16

fn C.witty_tt_os2_typo_descender(table voidptr) i16

fn C.witty_tt_os2_typo_line_gap(table voidptr) i16

fn C.witty_tt_os2_selection(table voidptr) u16

fn C.witty_tt_os2_win_ascent(table voidptr) u16

fn C.witty_tt_os2_win_descent(table voidptr) u16

fn C.witty_tt_os2_cap_height(table voidptr) i16

fn C.witty_tt_os2_x_height(table voidptr) i16

fn C.witty_tt_os2_strikeout_size(table voidptr) i16

fn C.witty_tt_os2_strikeout_position(table voidptr) i16

fn C.witty_tt_hhea_ascender(table voidptr) i16

fn C.witty_tt_hhea_descender(table voidptr) i16

fn C.witty_tt_hhea_line_gap(table voidptr) i16

// FT_Load_Glyph flag bits (from freetype.h). These are stable ABI values.
const ft_load_default = i32(0x0)
const ft_load_no_scale = i32(1 << 0)
const ft_load_no_hinting = i32(1 << 1)
const ft_load_render = i32(1 << 2)
const ft_load_no_bitmap = i32(1 << 3)
const ft_load_vertical_layout = i32(1 << 4)
const ft_load_force_autohint = i32(1 << 5)
const ft_load_crop_bitmap = i32(1 << 6)
const ft_load_pedantic = i32(1 << 7)
const ft_load_advance_only = i32(1 << 8)
const ft_load_ignore_global_advance_width = i32(1 << 9)
const ft_load_no_recurse = i32(1 << 10)
const ft_load_ignore_transform = i32(1 << 11)
const ft_load_monochrome = i32(1 << 12)
const ft_load_linear_design = i32(1 << 13)
const ft_load_sbits_only = i32(1 << 14)
const ft_load_no_autohint = i32(1 << 15)
const ft_load_target_mask = i32(15 << 16)
const ft_load_color = i32(1 << 20)
const ft_load_compute_metrics = i32(1 << 21)
const ft_load_bitmap_metrics_only = i32(1 << 22)
const ft_load_svg_only = i32(1 << 23)
const ft_load_no_svg = i32(1 << 24)

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
pub const face_flag_fixed_sizes = i64(1 << 1)
pub const face_flag_multiple_masters = i64(1 << 8)
pub const face_flag_color = i64(1 << 14)

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
pub enum Encoding as u32 {
	none           = 0x00000000
	ms_symbol      = 0x73796d62
	unicode        = 0x756e6963
	sjis           = 0x736a6973
	prc            = 0x67622020
	big5           = 0x62696735
	wansung        = 0x77616e73
	johab          = 0x6a6f6861
	adobe_standard = 0x41444f42
	adobe_expert   = 0x41444245
	adobe_custom   = 0x41444243
	adobe_latin_1  = 0x6c617431
	old_latin_2    = 0x6c617432
	apple_roman    = 0x61726d6e
}

// RenderMode specifies the glyph rendering target.
pub enum RenderMode as u32 {
	normal
	light
	mono
	lcd
	lcd_v
	sdf
}

// SfntTag identifies SFNT table types.
pub enum SfntTag as i32 {
	head
	maxp
	os2
	hhea
	vhea
	post
	pclt
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
	size            &SizeRec      = unsafe { nil }
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
	raw         voidptr = unsafe { nil }
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

// Matrix is FreeType's 16.16 affine transform matrix.
pub struct Matrix {
pub:
	xx i64
	xy i64
	yx i64
	yy i64
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
	rows         u32
	width        u32
	pitch        i32
	buffer       &u8 = unsafe { nil }
	num_grays    u16
	pixel_mode   u8
	palette_mode u8
	palette      voidptr = unsafe { nil }
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
	n_contours i16
	n_points   i16
	points     &OutlinePoint = unsafe { nil }
	tags       &char         = unsafe { nil }
	contours   &i16          = unsafe { nil }
	flags      i32
	raw        voidptr = unsafe { nil }
}

// OutlinePoint holds a single outline point (26.6 fixed-point).
pub struct OutlinePoint {
pub mut:
	x i64
	y i64
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

// LoadTarget is the four-bit target field in FreeType's load flags.
pub enum LoadTarget as u8 {
	normal
	light
	mono
	lcd
	lcd_v
}

// LoadFlags is the exact 32-bit FT_Load_Glyph flag value. Ghostty represents
// this as a packed struct; V accessors retain that layout without widening the
// individual bits into booleans.
pub struct LoadFlags {
mut:
	value i32 = ft_load_default
}

pub fn LoadFlags.from_int(value i32) LoadFlags {
	return LoadFlags{
		value: value
	}
}

pub fn (flags LoadFlags) to_int() i32 {
	return flags.value
}

fn (flags LoadFlags) bit(mask i32) bool {
	return flags.value & mask != 0
}

fn (mut flags LoadFlags) set_bit(mask i32, enabled bool) {
	if enabled {
		flags.value |= mask
	} else {
		flags.value &= ~mask
	}
}

pub fn (flags LoadFlags) no_scale() bool {
	return flags.bit(ft_load_no_scale)
}

pub fn (mut flags LoadFlags) set_no_scale(enabled bool) {
	flags.set_bit(ft_load_no_scale, enabled)
}

pub fn (flags LoadFlags) no_hinting() bool {
	return flags.bit(ft_load_no_hinting)
}

pub fn (mut flags LoadFlags) set_no_hinting(enabled bool) {
	flags.set_bit(ft_load_no_hinting, enabled)
}

pub fn (flags LoadFlags) render() bool {
	return flags.bit(ft_load_render)
}

pub fn (mut flags LoadFlags) set_render(enabled bool) {
	flags.set_bit(ft_load_render, enabled)
}

pub fn (flags LoadFlags) no_bitmap() bool {
	return flags.bit(ft_load_no_bitmap)
}

pub fn (mut flags LoadFlags) set_no_bitmap(enabled bool) {
	flags.set_bit(ft_load_no_bitmap, enabled)
}

pub fn (flags LoadFlags) vertical_layout() bool {
	return flags.bit(ft_load_vertical_layout)
}

pub fn (mut flags LoadFlags) set_vertical_layout(enabled bool) {
	flags.set_bit(ft_load_vertical_layout, enabled)
}

pub fn (flags LoadFlags) force_autohint() bool {
	return flags.bit(ft_load_force_autohint)
}

pub fn (mut flags LoadFlags) set_force_autohint(enabled bool) {
	flags.set_bit(ft_load_force_autohint, enabled)
}

pub fn (flags LoadFlags) crop_bitmap() bool {
	return flags.bit(ft_load_crop_bitmap)
}

pub fn (mut flags LoadFlags) set_crop_bitmap(enabled bool) {
	flags.set_bit(ft_load_crop_bitmap, enabled)
}

pub fn (flags LoadFlags) pedantic() bool {
	return flags.bit(ft_load_pedantic)
}

pub fn (mut flags LoadFlags) set_pedantic(enabled bool) {
	flags.set_bit(ft_load_pedantic, enabled)
}

pub fn (flags LoadFlags) advance_only() bool {
	return flags.bit(ft_load_advance_only)
}

pub fn (mut flags LoadFlags) set_advance_only(enabled bool) {
	flags.set_bit(ft_load_advance_only, enabled)
}

pub fn (flags LoadFlags) ignore_global_advance_width() bool {
	return flags.bit(ft_load_ignore_global_advance_width)
}

pub fn (mut flags LoadFlags) set_ignore_global_advance_width(enabled bool) {
	flags.set_bit(ft_load_ignore_global_advance_width, enabled)
}

pub fn (flags LoadFlags) no_recurse() bool {
	return flags.bit(ft_load_no_recurse)
}

pub fn (mut flags LoadFlags) set_no_recurse(enabled bool) {
	flags.set_bit(ft_load_no_recurse, enabled)
}

pub fn (flags LoadFlags) ignore_transform() bool {
	return flags.bit(ft_load_ignore_transform)
}

pub fn (mut flags LoadFlags) set_ignore_transform(enabled bool) {
	flags.set_bit(ft_load_ignore_transform, enabled)
}

pub fn (flags LoadFlags) monochrome() bool {
	return flags.bit(ft_load_monochrome)
}

pub fn (mut flags LoadFlags) set_monochrome(enabled bool) {
	flags.set_bit(ft_load_monochrome, enabled)
}

pub fn (flags LoadFlags) linear_design() bool {
	return flags.bit(ft_load_linear_design)
}

pub fn (mut flags LoadFlags) set_linear_design(enabled bool) {
	flags.set_bit(ft_load_linear_design, enabled)
}

pub fn (flags LoadFlags) sbits_only() bool {
	return flags.bit(ft_load_sbits_only)
}

pub fn (mut flags LoadFlags) set_sbits_only(enabled bool) {
	flags.set_bit(ft_load_sbits_only, enabled)
}

pub fn (flags LoadFlags) no_autohint() bool {
	return flags.bit(ft_load_no_autohint)
}

pub fn (mut flags LoadFlags) set_no_autohint(enabled bool) {
	flags.set_bit(ft_load_no_autohint, enabled)
}

pub fn (flags LoadFlags) target() LoadTarget {
	return unsafe { LoadTarget((flags.value & ft_load_target_mask) >> 16) }
}

pub fn (mut flags LoadFlags) set_target(target LoadTarget) {
	flags.value = (flags.value & ~ft_load_target_mask) | i32(u32(target) << 16)
}

pub fn (flags LoadFlags) color() bool {
	return flags.bit(ft_load_color)
}

pub fn (mut flags LoadFlags) set_color(enabled bool) {
	flags.set_bit(ft_load_color, enabled)
}

pub fn (flags LoadFlags) compute_metrics() bool {
	return flags.bit(ft_load_compute_metrics)
}

pub fn (mut flags LoadFlags) set_compute_metrics(enabled bool) {
	flags.set_bit(ft_load_compute_metrics, enabled)
}

pub fn (flags LoadFlags) bitmap_metrics_only() bool {
	return flags.bit(ft_load_bitmap_metrics_only)
}

pub fn (mut flags LoadFlags) set_bitmap_metrics_only(enabled bool) {
	flags.set_bit(ft_load_bitmap_metrics_only, enabled)
}

pub fn (flags LoadFlags) svg_only() bool {
	return flags.bit(ft_load_svg_only)
}

pub fn (mut flags LoadFlags) set_svg_only(enabled bool) {
	flags.set_bit(ft_load_svg_only, enabled)
}

pub fn (flags LoadFlags) no_svg() bool {
	return flags.bit(ft_load_no_svg)
}

pub fn (mut flags LoadFlags) set_no_svg(enabled bool) {
	flags.set_bit(ft_load_no_svg, enabled)
}

// Tag represents a 4-byte OpenType table tag.
pub struct Tag {
pub:
	value u32
}

// init creates a Tag from a 4-byte string.
pub fn Tag.init(s string) Tag {
	assert s.len == 4
	return Tag{
		value: (u32(s[0]) << 24) | (u32(s[1]) << 16) | (u32(s[2]) << 8) | u32(s[3])
	}
}

pub fn (tag Tag) str() string {
	value := [u8(tag.value >> 24), u8(tag.value >> 16), u8(tag.value >> 8), u8(tag.value)]!
	return value[..].bytestr()
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

pub struct Version {
pub:
	major i32
	minor i32
	patch i32
}

pub fn (version Version) to_string(mut buf []u8) !string {
	text := '${version.major}.${version.minor}.${version.patch}'
	if text.len > buf.len {
		return error('FreeType version buffer is too small')
	}
	for i, byte in text.bytes() {
		buf[i] = byte
	}
	return buf[..text.len].bytestr()
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

// version returns the version of the loaded FreeType library.
pub fn (l Library) version() Version {
	mut result := Version{}
	C.FT_Library_Version(l.handle, &result.major, &result.minor, &result.patch)
	return result
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
		handle: ft_face
	}
}

// init_memory_face creates a new face from in-memory data.
pub fn (l Library) init_memory_face(data []u8, index i32) !Face {
	if isnil(l.handle) {
		return error('freetype library not initialized')
	}
	mut owned := data.clone()
	mut ft_face := voidptr(unsafe { nil })
	base := if owned.len > 0 { &u8(owned.data) } else { &u8(unsafe { nil }) }
	err := C.FT_New_Memory_Face(l.handle, base, i64(owned.len), i64(index), &ft_face)
	if err != 0 {
		return error('FT_New_Memory_Face failed (${err})')
	}
	return Face{
		handle:      ft_face
		memory_data: owned
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
pub struct Face {
pub mut:
	handle      voidptr = unsafe { nil }
	memory_data []u8
}

// deinit destroys this font face.
pub fn (mut f Face) deinit() {
	if !isnil(f.handle) {
		C.FT_Done_Face(f.handle)
		f.handle = unsafe { nil }
		f.memory_data = []
	}
}

// ref increases the reference count of this face.
pub fn (f Face) ref() {
	if !isnil(f.handle) {
		C.FT_Reference_Face(f.handle)
	}
}

// select_charmap selects a character map encoding.
pub fn (f Face) select_charmap(encoding Encoding) ! {
	err := C.FT_Select_Charmap(f.handle, u32(encoding))
	if err != 0 {
		return error('FT_Select_Charmap failed (${err})')
	}
}

// set_char_size sets the character size in 26.6 fractional points.
pub fn (f Face) set_char_size(width i32, height i32, h_res u16, v_res u16) ! {
	err := C.FT_Set_Char_Size(f.handle, i64(width), i64(height), u32(h_res), u32(v_res))
	if err != 0 {
		return error('FT_Set_Char_Size failed (${err})')
	}
}

// load_glyph loads a glyph into the glyph slot.
pub fn (f Face) load_glyph(glyph_index u32, flags LoadFlags) ! {
	err := C.FT_Load_Glyph(f.handle, glyph_index, flags.to_int())
	if err != 0 {
		return error('FT_Load_Glyph failed (${err})')
	}
}

// render_glyph renders a loaded glyph to a bitmap.
pub fn (f Face) render_glyph(mode RenderMode) ! {
	if isnil(f.handle) {
		return error('freetype face not initialized')
	}
	slot := C.witty_ft_glyph(f.handle)
	err := C.FT_Render_Glyph(slot, int(mode))
	if err != 0 {
		return error('FT_Render_Glyph failed (${err})')
	}
}

// get_char_index returns the glyph index for a Unicode codepoint.
// Returns none if the codepoint is not in the font.
pub fn (f Face) get_char_index(code u32) ?u32 {
	if isnil(f.handle) {
		return none
	}
	idx := C.FT_Get_Char_Index(f.handle, u64(code))
	if idx == 0 {
		return none
	}
	return idx
}

// has_color returns true if the font has color (e.g., emoji) glyphs.
pub fn (f Face) has_color() bool {
	return !isnil(f.handle) && C.witty_ft_has_color(f.handle) != 0
}

pub fn (f Face) has_fixed_sizes() bool {
	return !isnil(f.handle) && C.witty_ft_has_fixed_sizes(f.handle) != 0
}

pub fn (f Face) has_sbix() bool {
	return !isnil(f.handle) && C.witty_ft_has_sbix(f.handle) != 0
}

// is_scalable returns true if the font is in a scalable format.
pub fn (f Face) is_scalable() bool {
	return !isnil(f.handle) && C.witty_ft_is_scalable(f.handle) != 0
}

// has_multiple_masters returns true if the font supports OpenType variations.
pub fn (f Face) has_multiple_masters() bool {
	return !isnil(f.handle) && C.witty_ft_has_multiple_masters(f.handle) != 0
}

// get_mm_var returns the multiple master / variation data.
pub fn (f Face) get_mm_var() !MMVar {
	mut raw := voidptr(unsafe { nil })
	err := C.FT_Get_MM_Var(f.handle, &raw)
	if err != 0 {
		return error('FT_Get_MM_Var failed (${err})')
	}
	num_axis := C.witty_ft_mm_num_axis(raw)
	mut axes := []MMAxis{cap: int(num_axis)}
	for i in 0 .. num_axis {
		name_ptr := C.witty_ft_mm_axis_name(raw, i)
		axes << MMAxis{
			tag:     C.witty_ft_mm_axis_tag(raw, i)
			name:    if name_ptr == unsafe { nil } {
				''
			} else {
				unsafe { cstring_to_vstring(name_ptr) }
			}
			minimum: C.witty_ft_mm_axis_minimum(raw, i)
			def:     C.witty_ft_mm_axis_default(raw, i)
			maximum: C.witty_ft_mm_axis_maximum(raw, i)
		}
	}
	return MMVar{ num_axis: num_axis, axis: axes, raw: raw }
}

// set_var_design_coordinates sets variation axis coordinates.
pub fn (f Face) set_var_design_coordinates(coords []i64) ! {
	if coords.len == 0 {
		return
	}
	err := C.FT_Set_Var_Design_Coordinates(f.handle, u32(coords.len), unsafe { &coords[0] })
	if err != 0 {
		return error('FT_Set_Var_Design_Coordinates failed (${err})')
	}
}

// get_var_design_coordinates gets current variation axis coordinates.
pub fn (f Face) get_var_design_coordinates(mut coords []i64) ! {
	if coords.len == 0 {
		return
	}
	err := C.FT_Get_Var_Design_Coordinates(f.handle, u32(coords.len), unsafe { &coords[0] })
	if err != 0 {
		return error('FT_Get_Var_Design_Coordinates failed (${err})')
	}
}

// set_transform sets the transform applied when glyphs are loaded.
pub fn (f Face) set_transform(matrix ?&Matrix, delta ?&Vector) {
	mut matrix_ptr := voidptr(unsafe { nil })
	mut delta_ptr := voidptr(unsafe { nil })
	if value := matrix {
		matrix_ptr = voidptr(value)
	}
	if value := delta {
		delta_ptr = voidptr(value)
	}
	C.FT_Set_Transform(f.handle, matrix_ptr, delta_ptr)
}

// get_sfnt_name_count returns the number of name table entries.
pub fn (f Face) get_sfnt_name_count() usize {
	return usize(C.FT_Get_Sfnt_Name_Count(f.handle))
}

// get_sfnt_name returns the name table entry at the given index.
pub fn (f Face) get_sfnt_name(index usize) !SfntName {
	mut name_id := u16(0)
	mut platform_id := u16(0)
	mut encoding_id := u16(0)
	mut bytes := &u8(unsafe { nil })
	mut length := u32(0)
	err := C.witty_ft_get_sfnt_name(f.handle, u32(index), &name_id, &platform_id, &encoding_id,
		&bytes, &length)
	if err != 0 {
		return error('FT_Get_Sfnt_Name failed (${err})')
	}
	mut data := []u8{len: int(length)}
	for i in 0 .. int(length) {
		data[i] = unsafe { bytes[i] }
	}
	return SfntName{
		name_id:     name_id
		platform_id: platform_id
		encoding_id: encoding_id
		string_data: data
		string_len:  length
	}
}

// get_sfnt_table returns a pointer to the specified SFNT table.
// The returned pointer type depends on the tag:
//   .head -> &TT_Header
//   .post -> &TT_Postscript
//   .os2  -> &TT_OS2
//   .hhea -> &TT_HoriHeader
pub fn (f Face) get_sfnt_table_head() ?&TT_Header {
	table := C.FT_Get_Sfnt_Table(f.handle, int(SfntTag.head))
	if isnil(table) {
		return none
	}
	return &TT_Header{ units_per_em: C.witty_tt_head_units_per_em(table) }
}

pub fn (f Face) get_sfnt_table_post() ?&TT_Postscript {
	table := C.FT_Get_Sfnt_Table(f.handle, int(SfntTag.post))
	if isnil(table) {
		return none
	}
	return &TT_Postscript{
		underline_position:  C.witty_tt_post_underline_position(table)
		underline_thickness: C.witty_tt_post_underline_thickness(table)
	}
}

pub fn (f Face) get_sfnt_table_os2() ?&TT_OS2 {
	table := C.FT_Get_Sfnt_Table(f.handle, int(SfntTag.os2))
	if isnil(table) {
		return none
	}
	return &TT_OS2{
		version:              C.witty_tt_os2_version(table)
		s_typo_ascender:      C.witty_tt_os2_typo_ascender(table)
		s_typo_descender:     C.witty_tt_os2_typo_descender(table)
		s_typo_line_gap:      C.witty_tt_os2_typo_line_gap(table)
		fs_selection:         C.witty_tt_os2_selection(table)
		us_win_ascent:        C.witty_tt_os2_win_ascent(table)
		us_win_descent:       C.witty_tt_os2_win_descent(table)
		s_cap_height:         C.witty_tt_os2_cap_height(table)
		sx_height:            C.witty_tt_os2_x_height(table)
		y_strikeout_size:     C.witty_tt_os2_strikeout_size(table)
		y_strikeout_position: C.witty_tt_os2_strikeout_position(table)
	}
}

pub fn (f Face) get_sfnt_table_hhea() ?&TT_HoriHeader {
	table := C.FT_Get_Sfnt_Table(f.handle, int(SfntTag.hhea))
	if isnil(table) {
		return none
	}
	return &TT_HoriHeader{
		ascender:  C.witty_tt_hhea_ascender(table)
		descender: C.witty_tt_hhea_descender(table)
		line_gap:  C.witty_tt_hhea_line_gap(table)
	}
}

pub fn (f Face) face_flags() i64 {
	return if isnil(f.handle) { i64(0) } else { C.witty_ft_face_flags(f.handle) }
}

pub fn (f Face) units_per_em() u16 {
	return if isnil(f.handle) { u16(0) } else { C.witty_ft_units_per_em(f.handle) }
}

pub fn (f Face) num_fixed_sizes() int {
	return if isnil(f.handle) { 0 } else { int(C.witty_ft_num_fixed_sizes(f.handle)) }
}

pub fn (f Face) fixed_size_width(index int) i16 {
	return C.witty_ft_fixed_size_width(f.handle, i32(index))
}

pub fn (f Face) size_metrics() ?SizeMetrics {
	size := C.witty_ft_size(f.handle)
	if isnil(size) {
		return none
	}
	return SizeMetrics{
		x_ppem:      C.witty_ft_size_x_ppem(size)
		y_ppem:      C.witty_ft_size_y_ppem(size)
		x_scale:     C.witty_ft_size_x_scale(size)
		y_scale:     C.witty_ft_size_y_scale(size)
		ascender:    C.witty_ft_size_ascender(size)
		descender:   C.witty_ft_size_descender(size)
		height:      C.witty_ft_size_height(size)
		max_advance: C.witty_ft_size_max_advance(size)
	}
}

pub fn (f Face) glyph() ?GlyphSlotRec {
	slot := C.witty_ft_glyph(f.handle)
	if isnil(slot) {
		return none
	}
	bitmap_ptr := C.witty_ft_glyph_bitmap(slot)
	outline_ptr := C.witty_ft_glyph_outline(slot)
	return GlyphSlotRec{
		raw:         slot
		advance:     Vector{
			x: C.witty_ft_glyph_advance_x(slot)
			y: C.witty_ft_glyph_advance_y(slot)
		}
		metrics:     GlyphMetrics{
			width:          C.witty_ft_glyph_width(slot)
			height:         C.witty_ft_glyph_height(slot)
			hori_bearing_x: C.witty_ft_glyph_bearing_x(slot)
			hori_bearing_y: C.witty_ft_glyph_bearing_y(slot)
		}
		bitmap:      Bitmap{
			rows:       C.witty_ft_bitmap_rows(bitmap_ptr)
			width:      C.witty_ft_bitmap_width(bitmap_ptr)
			pitch:      C.witty_ft_bitmap_pitch(bitmap_ptr)
			buffer:     C.witty_ft_bitmap_buffer(bitmap_ptr)
			num_grays:  C.witty_ft_bitmap_num_grays(bitmap_ptr)
			pixel_mode: C.witty_ft_bitmap_pixel_mode(bitmap_ptr)
		}
		bitmap_left: C.witty_ft_glyph_bitmap_left(slot)
		bitmap_top:  C.witty_ft_glyph_bitmap_top(slot)
		outline:     Outline{ raw: outline_ptr }
		format:      C.witty_ft_glyph_format(slot)
	}
}

// select_size selects a fixed bitmap strike by index.
pub fn (f Face) select_size(index i32) ! {
	err := C.FT_Select_Size(f.handle, index)
	if err != 0 {
		return error('FT_Select_Size failed (${err})')
	}
}

// SfntTableValue represents Ghostty's optional raw SFNT table slice.
pub struct SfntTableValue {
pub:
	has_value bool
	data      []u8
}

// load_sfnt_table loads raw SFNT table data by tag.
pub fn (f Face) load_sfnt_table(tag Tag) !SfntTableValue {
	if isnil(f.handle) {
		return error('freetype face not initialized')
	}
	// First query the length by passing a null buffer.
	mut length := u64(0)
	err := C.FT_Load_Sfnt_Table(f.handle, u64(tag.value), 0, &u8(unsafe { nil }), &length)
	if err != 0 {
		return error('FT_Load_Sfnt_Table (length) failed (${err})')
	}
	if length == 0 {
		return SfntTableValue{}
	}
	// Then read the table bytes into a freshly allocated buffer.
	mut buf := []u8{len: int(length)}
	err2 := C.FT_Load_Sfnt_Table(f.handle, u64(tag.value), 0, &u8(buf.data), &length)
	if err2 != 0 {
		return error('FT_Load_Sfnt_Table (read) failed (${err2})')
	}
	return SfntTableValue{
		has_value: true
		data:      buf
	}
}

// has_sfnt_table reports whether a raw SFNT table exists and is non-empty.
pub fn (f Face) has_sfnt_table(tag Tag) bool {
	if isnil(f.handle) {
		return false
	}
	mut length := u64(0)
	err := C.FT_Load_Sfnt_Table(f.handle, u64(tag.value), 0, &u8(unsafe { nil }), &length)
	return err == 0 && length != 0
}

// ============================================================
// Bitmap operations
// ============================================================

// bitmap_init initializes a bitmap to empty.
pub fn bitmap_init(mut bm Bitmap) {
	C.FT_Bitmap_Init(voidptr(&bm))
}

// bitmap_done frees bitmap data.
//
pub fn bitmap_done(lib Library, mut bm Bitmap) {
	if !isnil(lib.handle) {
		C.FT_Bitmap_Done(lib.handle, voidptr(&bm))
	}
}

// bitmap_convert converts a bitmap to a different format.
pub fn bitmap_convert(lib Library, source &Bitmap, mut target Bitmap, alignment i32) ! {
	err := C.FT_Bitmap_Convert(lib.handle, voidptr(source), voidptr(&target), alignment)
	if err != 0 {
		return error('FT_Bitmap_Convert failed (${err})')
	}
}

// bitmap_copy copies a bitmap.
pub fn bitmap_copy(lib Library, source &Bitmap, mut target Bitmap) ! {
	err := C.FT_Bitmap_Copy(lib.handle, voidptr(source), voidptr(&target))
	if err != 0 {
		return error('FT_Bitmap_Copy failed (${err})')
	}
}

// ============================================================
// Outline operations
// ============================================================

// outline_get_bbox computes the bounding box of an outline.
// `outline` points at the FT_Outline embedded in the live glyph slot, so
// we pass it straight through to FreeType, which writes into `bbox`.
pub fn outline_get_bbox(outline &Outline, mut bbox BBox) {
	if !isnil(outline.raw) {
		C.FT_Outline_Get_BBox(outline.raw, voidptr(&bbox))
	}
}

// outline_embolden thickens an outline in place.
pub fn outline_embolden(mut outline Outline, strength i64) {
	if !isnil(outline.raw) {
		C.FT_Outline_Embolden(outline.raw, strength)
	}
}

// outline_points_len returns the number of live points in an outline.
pub fn outline_points_len(outline &Outline) int {
	return if isnil(outline.raw) { 0 } else { int(C.witty_ft_outline_n_points(outline.raw)) }
}

// outline_point returns a point from the live FreeType glyph outline.
pub fn outline_point(outline &Outline, index int) OutlinePoint {
	if isnil(outline.raw) || index < 0 || index >= outline_points_len(outline) {
		return OutlinePoint{}
	}
	return OutlinePoint{
		x: C.witty_ft_outline_point_x(outline.raw, i32(index))
		y: C.witty_ft_outline_point_y(outline.raw, i32(index))
	}
}

// outline_set_point updates a point in the live FreeType glyph outline.
pub fn outline_set_point(mut outline Outline, index int, point OutlinePoint) {
	if !isnil(outline.raw) {
		C.witty_ft_outline_set_point(outline.raw, i32(index), point.x, point.y)
	}
}

// glyph_slot_own_bitmap ensures the glyph slot owns its bitmap.
pub fn glyph_slot_own_bitmap(mut glyph GlyphSlotRec) ! {
	if isnil(glyph.raw) {
		return error('glyph slot is not backed by FreeType')
	}
	err := C.FT_GlyphSlot_Own_Bitmap(glyph.raw)
	if err != 0 {
		return error('FT_GlyphSlot_Own_Bitmap failed (${err})')
	}
}

// ============================================================
// Fixed-point math
// ============================================================

// mul_fix performs a 16.16 fixed-point multiply.
pub fn mul_fix(a i32, b i32) i32 {
	return i32(C.FT_MulFix(i64(a), i64(b)))
}

// f26dot6_to_f64 converts a raw 26.6 fixed-point i64 to f64.
pub fn f26dot6_to_f64(v i64) f64 {
	return F26Dot6{ value: i32(v) }.to_f64()
}

// f26dot6_to_f32 converts a raw 26.6 fixed-point i64 to f32.
pub fn f26dot6_to_f32(v i64) f32 {
	return f32(v >> 6)
}
