#include <stdint.h>
#include <string.h>

typedef struct witty_ft_bitmap {
	unsigned int width;
	unsigned int rows;
	int pitch;
	int bitmap_left;
	int bitmap_top;
	long advance_x;
	long advance_y;
	unsigned char pixel_mode;
	unsigned short num_grays;
	const unsigned char *buffer;
} witty_ft_bitmap;

typedef struct witty_ft_metrics {
	unsigned int x_ppem;
	unsigned int y_ppem;
	long x_scale;
	long y_scale;
	long ascender;
	long descender;
	long height;
	long max_advance;
	unsigned int units_per_em;
	long face_flags;
} witty_ft_metrics;

#ifdef WITTY_ENABLE_FREETYPE

#include <ft2build.h>
#include FT_FREETYPE_H

int witty_ft_init(void **lib) {
	return FT_Init_FreeType((FT_Library *)lib);
}

void witty_ft_done(void *lib) {
	if (lib) FT_Done_FreeType((FT_Library)lib);
}

int witty_ft_new_face(void *lib, char *path, long long index, void **face) {
	if (!lib || !path || !face) return -1;
	return FT_New_Face((FT_Library)lib, path, (FT_Long)index, (FT_Face *)face);
}

int witty_ft_new_memory_face(void *lib, unsigned char *data, long long len, long long index, void **face) {
	if (!lib || !data || len <= 0 || !face) return -1;
	return FT_New_Memory_Face((FT_Library)lib, data, (FT_Long)len, (FT_Long)index, (FT_Face *)face);
}

void witty_ft_done_face(void *face) {
	if (face) FT_Done_Face((FT_Face)face);
}

void witty_ft_reference_face(void *face) {
	if (face) FT_Reference_Face((FT_Face)face);
}

int witty_ft_select_unicode_charmap(void *face) {
	if (!face) return -1;
	return FT_Select_Charmap((FT_Face)face, FT_ENCODING_UNICODE);
}

int witty_ft_set_char_size(void *face, int width, int height, unsigned int h_res, unsigned int v_res) {
	if (!face) return -1;
	return FT_Set_Char_Size((FT_Face)face, width, height, h_res, v_res);
}

unsigned int witty_ft_get_char_index(void *face, uint32_t codepoint) {
	if (!face) return 0;
	return FT_Get_Char_Index((FT_Face)face, (FT_ULong)codepoint);
}

int witty_ft_load_glyph(void *face, unsigned int glyph_index, int render, int color, int no_hinting, int force_autohint, int no_autohint, int no_svg, int target) {
	if (!face) return -1;
	FT_Int32 flags = 0;
	if (render) flags |= FT_LOAD_RENDER;
	if (color) flags |= FT_LOAD_COLOR;
	if (no_hinting) flags |= FT_LOAD_NO_HINTING;
	if (force_autohint) flags |= FT_LOAD_FORCE_AUTOHINT;
	if (no_autohint) flags |= FT_LOAD_NO_AUTOHINT;
#ifdef FT_LOAD_NO_SVG
	if (no_svg) flags |= FT_LOAD_NO_SVG;
#endif
	switch (target) {
	case 1:
		flags |= FT_LOAD_TARGET_LIGHT;
		break;
	case 2:
		flags |= FT_LOAD_TARGET_MONO;
		break;
	default:
		flags |= FT_LOAD_TARGET_NORMAL;
		break;
	}
	return FT_Load_Glyph((FT_Face)face, glyph_index, flags);
}

int witty_ft_render_glyph(void *face, int mode) {
	if (!face || !((FT_Face)face)->glyph) return -1;
	FT_Render_Mode ft_mode = FT_RENDER_MODE_NORMAL;
	switch (mode) {
	case 1:
		ft_mode = FT_RENDER_MODE_LIGHT;
		break;
	case 2:
		ft_mode = FT_RENDER_MODE_MONO;
		break;
	default:
		ft_mode = FT_RENDER_MODE_NORMAL;
		break;
	}
	return FT_Render_Glyph(((FT_Face)face)->glyph, ft_mode);
}

void witty_ft_get_bitmap(void *face, witty_ft_bitmap *out) {
	if (!out) return;
	memset(out, 0, sizeof(*out));
	if (!face || !((FT_Face)face)->glyph) return;
	FT_GlyphSlot glyph = ((FT_Face)face)->glyph;
	out->width = glyph->bitmap.width;
	out->rows = glyph->bitmap.rows;
	out->pitch = glyph->bitmap.pitch;
	out->bitmap_left = glyph->bitmap_left;
	out->bitmap_top = glyph->bitmap_top;
	out->advance_x = glyph->advance.x;
	out->advance_y = glyph->advance.y;
	out->pixel_mode = glyph->bitmap.pixel_mode;
	out->num_grays = glyph->bitmap.num_grays;
	out->buffer = glyph->bitmap.buffer;
}

void witty_ft_get_metrics(void *face, witty_ft_metrics *out) {
	if (!out) return;
	memset(out, 0, sizeof(*out));
	if (!face) return;
	FT_Face ft_face = (FT_Face)face;
	if (ft_face->size) {
		out->x_ppem = ft_face->size->metrics.x_ppem;
		out->y_ppem = ft_face->size->metrics.y_ppem;
		out->x_scale = ft_face->size->metrics.x_scale;
		out->y_scale = ft_face->size->metrics.y_scale;
		out->ascender = ft_face->size->metrics.ascender;
		out->descender = ft_face->size->metrics.descender;
		out->height = ft_face->size->metrics.height;
		out->max_advance = ft_face->size->metrics.max_advance;
	}
	out->units_per_em = ft_face->units_per_EM;
	out->face_flags = ft_face->face_flags;
}

int witty_ft_has_color(void *face) {
	if (!face) return 0;
#ifdef FT_HAS_COLOR
	return FT_HAS_COLOR((FT_Face)face) ? 1 : 0;
#else
	return 0;
#endif
}

int witty_ft_is_scalable(void *face) {
	if (!face) return 0;
	return FT_IS_SCALABLE((FT_Face)face) ? 1 : 0;
}

#endif
