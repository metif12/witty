#ifndef WITTY_FREETYPE_BRIDGE_H
#define WITTY_FREETYPE_BRIDGE_H

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_TRUETYPE_TABLES_H
#include <freetype/ftmm.h>
#include <freetype/ftsnames.h>

static inline int witty_ft_has_fixed_sizes(FT_Face face) { return FT_HAS_FIXED_SIZES(face); }
static inline int witty_ft_has_color(FT_Face face) { return FT_HAS_COLOR(face); }
static inline int witty_ft_has_sbix(FT_Face face) { return FT_HAS_SBIX(face); }
static inline int witty_ft_has_multiple_masters(FT_Face face) { return FT_HAS_MULTIPLE_MASTERS(face); }
static inline int witty_ft_is_scalable(FT_Face face) { return FT_IS_SCALABLE(face); }

static inline FT_GlyphSlot witty_ft_glyph(FT_Face face) { return face ? face->glyph : NULL; }
static inline FT_Size witty_ft_size(FT_Face face) { return face ? face->size : NULL; }
static inline FT_Long witty_ft_face_flags(FT_Face face) { return face ? face->face_flags : 0; }
static inline FT_UShort witty_ft_units_per_em(FT_Face face) { return face ? face->units_per_EM : 0; }
static inline FT_Int witty_ft_num_fixed_sizes(FT_Face face) { return face ? face->num_fixed_sizes : 0; }
static inline FT_Short witty_ft_fixed_size_width(FT_Face face, FT_Int index) {
  return face && index >= 0 && index < face->num_fixed_sizes ? face->available_sizes[index].width : 0;
}

static inline FT_UShort witty_ft_size_x_ppem(FT_Size size) { return size ? size->metrics.x_ppem : 0; }
static inline FT_UShort witty_ft_size_y_ppem(FT_Size size) { return size ? size->metrics.y_ppem : 0; }
static inline FT_Fixed witty_ft_size_x_scale(FT_Size size) { return size ? size->metrics.x_scale : 0; }
static inline FT_Fixed witty_ft_size_y_scale(FT_Size size) { return size ? size->metrics.y_scale : 0; }
static inline FT_Pos witty_ft_size_ascender(FT_Size size) { return size ? size->metrics.ascender : 0; }
static inline FT_Pos witty_ft_size_descender(FT_Size size) { return size ? size->metrics.descender : 0; }
static inline FT_Pos witty_ft_size_height(FT_Size size) { return size ? size->metrics.height : 0; }
static inline FT_Pos witty_ft_size_max_advance(FT_Size size) { return size ? size->metrics.max_advance : 0; }

static inline FT_Pos witty_ft_glyph_advance_x(FT_GlyphSlot slot) { return slot ? slot->advance.x : 0; }
static inline FT_Pos witty_ft_glyph_advance_y(FT_GlyphSlot slot) { return slot ? slot->advance.y : 0; }
static inline FT_Pos witty_ft_glyph_width(FT_GlyphSlot slot) { return slot ? slot->metrics.width : 0; }
static inline FT_Pos witty_ft_glyph_height(FT_GlyphSlot slot) { return slot ? slot->metrics.height : 0; }
static inline FT_Pos witty_ft_glyph_bearing_x(FT_GlyphSlot slot) { return slot ? slot->metrics.horiBearingX : 0; }
static inline FT_Pos witty_ft_glyph_bearing_y(FT_GlyphSlot slot) { return slot ? slot->metrics.horiBearingY : 0; }
static inline FT_Int witty_ft_glyph_bitmap_left(FT_GlyphSlot slot) { return slot ? slot->bitmap_left : 0; }
static inline FT_Int witty_ft_glyph_bitmap_top(FT_GlyphSlot slot) { return slot ? slot->bitmap_top : 0; }
static inline FT_Glyph_Format witty_ft_glyph_format(FT_GlyphSlot slot) { return slot ? slot->format : 0; }
static inline FT_Bitmap *witty_ft_glyph_bitmap(FT_GlyphSlot slot) { return slot ? &slot->bitmap : NULL; }
static inline FT_Outline *witty_ft_glyph_outline(FT_GlyphSlot slot) { return slot ? &slot->outline : NULL; }
static inline FT_Short witty_ft_outline_n_points(FT_Outline *outline) { return outline ? outline->n_points : 0; }
static inline FT_Pos witty_ft_outline_point_x(FT_Outline *outline, FT_Int index) {
  return outline && index >= 0 && index < outline->n_points ? outline->points[index].x : 0;
}
static inline FT_Pos witty_ft_outline_point_y(FT_Outline *outline, FT_Int index) {
  return outline && index >= 0 && index < outline->n_points ? outline->points[index].y : 0;
}
static inline void witty_ft_outline_set_point(FT_Outline *outline, FT_Int index, FT_Pos x, FT_Pos y) {
  if (outline && index >= 0 && index < outline->n_points) {
    outline->points[index].x = x;
    outline->points[index].y = y;
  }
}

static inline FT_UInt witty_ft_bitmap_rows(FT_Bitmap *bitmap) { return bitmap ? bitmap->rows : 0; }
static inline FT_UInt witty_ft_bitmap_width(FT_Bitmap *bitmap) { return bitmap ? bitmap->width : 0; }
static inline int witty_ft_bitmap_pitch(FT_Bitmap *bitmap) { return bitmap ? bitmap->pitch : 0; }
static inline unsigned char *witty_ft_bitmap_buffer(FT_Bitmap *bitmap) { return bitmap ? bitmap->buffer : NULL; }
static inline unsigned short witty_ft_bitmap_num_grays(FT_Bitmap *bitmap) { return bitmap ? bitmap->num_grays : 0; }
static inline unsigned char witty_ft_bitmap_pixel_mode(FT_Bitmap *bitmap) { return bitmap ? bitmap->pixel_mode : 0; }

static inline FT_UInt witty_ft_mm_num_axis(FT_MM_Var *mm) { return mm ? mm->num_axis : 0; }
static inline FT_ULong witty_ft_mm_axis_tag(FT_MM_Var *mm, FT_UInt i) { return mm->axis[i].tag; }
static inline const char *witty_ft_mm_axis_name(FT_MM_Var *mm, FT_UInt i) { return mm->axis[i].name; }
static inline FT_Fixed witty_ft_mm_axis_minimum(FT_MM_Var *mm, FT_UInt i) { return mm->axis[i].minimum; }
static inline FT_Fixed witty_ft_mm_axis_default(FT_MM_Var *mm, FT_UInt i) { return mm->axis[i].def; }
static inline FT_Fixed witty_ft_mm_axis_maximum(FT_MM_Var *mm, FT_UInt i) { return mm->axis[i].maximum; }

static inline FT_Error witty_ft_get_sfnt_name(
    FT_Face face, FT_UInt index, FT_UShort *name_id, FT_UShort *platform_id,
    FT_UShort *encoding_id, FT_Byte **bytes, FT_UInt *length) {
  FT_SfntName name;
  FT_Error err = FT_Get_Sfnt_Name(face, index, &name);
  if (err) return err;
  *name_id = name.name_id;
  *platform_id = name.platform_id;
  *encoding_id = name.encoding_id;
  *bytes = name.string;
  *length = name.string_len;
  return 0;
}

static inline FT_UShort witty_tt_head_units_per_em(void *p) { return p ? ((TT_Header *)p)->Units_Per_EM : 0; }
static inline FT_Short witty_tt_post_underline_position(void *p) { return p ? ((TT_Postscript *)p)->underlinePosition : 0; }
static inline FT_Short witty_tt_post_underline_thickness(void *p) { return p ? ((TT_Postscript *)p)->underlineThickness : 0; }
static inline FT_UShort witty_tt_os2_version(void *p) { return p ? ((TT_OS2 *)p)->version : 0; }
static inline FT_Short witty_tt_os2_typo_ascender(void *p) { return p ? ((TT_OS2 *)p)->sTypoAscender : 0; }
static inline FT_Short witty_tt_os2_typo_descender(void *p) { return p ? ((TT_OS2 *)p)->sTypoDescender : 0; }
static inline FT_Short witty_tt_os2_typo_line_gap(void *p) { return p ? ((TT_OS2 *)p)->sTypoLineGap : 0; }
static inline FT_UShort witty_tt_os2_selection(void *p) { return p ? ((TT_OS2 *)p)->fsSelection : 0; }
static inline FT_UShort witty_tt_os2_win_ascent(void *p) { return p ? ((TT_OS2 *)p)->usWinAscent : 0; }
static inline FT_UShort witty_tt_os2_win_descent(void *p) { return p ? ((TT_OS2 *)p)->usWinDescent : 0; }
static inline FT_Short witty_tt_os2_cap_height(void *p) { return p ? ((TT_OS2 *)p)->sCapHeight : 0; }
static inline FT_Short witty_tt_os2_x_height(void *p) { return p ? ((TT_OS2 *)p)->sxHeight : 0; }
static inline FT_Short witty_tt_os2_strikeout_size(void *p) { return p ? ((TT_OS2 *)p)->yStrikeoutSize : 0; }
static inline FT_Short witty_tt_os2_strikeout_position(void *p) { return p ? ((TT_OS2 *)p)->yStrikeoutPosition : 0; }
static inline FT_Short witty_tt_hhea_ascender(void *p) { return p ? ((TT_HoriHeader *)p)->Ascender : 0; }
static inline FT_Short witty_tt_hhea_descender(void *p) { return p ? ((TT_HoriHeader *)p)->Descender : 0; }
static inline FT_Short witty_tt_hhea_line_gap(void *p) { return p ? ((TT_HoriHeader *)p)->Line_Gap : 0; }

#endif
