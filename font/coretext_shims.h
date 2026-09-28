#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <harfbuzz/hb.h>
#include <harfbuzz/hb-coretext.h>

static void *witty_coretext_create_hb_font(void *font_ptr, double pixels) {
	if (!font_ptr) return NULL;
	hb_font_t *font = hb_coretext_font_create((CTFontRef)font_ptr);
	if (!font) return NULL;
	float scale = (float)pixels;
	uint32_t scale_bits = 0;
	memcpy(&scale_bits, &scale, sizeof(scale_bits));
	hb_font_set_scale(font, (int32_t)scale_bits, (int32_t)scale_bits);
	return (void *)font;
}

static void witty_coretext_destroy_hb_font(void *font_ptr) {
	if (font_ptr) hb_font_destroy((hb_font_t *)font_ptr);
}

#else
static void *witty_coretext_create_hb_font(void *font_ptr, double pixels) {
	(void)font_ptr;
	(void)pixels;
	return NULL;
}

static void witty_coretext_destroy_hb_font(void *font_ptr) {
	(void)font_ptr;
}

#endif
