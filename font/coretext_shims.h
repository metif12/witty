#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>

static double witty_coretext_font_size(double size) {
	return size > 0.0 ? size : 13.0;
}

static void *witty_coretext_create_font_named(char *name, double size) {
	const char *family = name && name[0] ? name : "Menlo";
	CFStringRef cf_name = CFStringCreateWithCString(NULL, family, kCFStringEncodingUTF8);
	if (!cf_name) return NULL;
	CTFontRef font = CTFontCreateWithName(cf_name, witty_coretext_font_size(size), NULL);
	CFRelease(cf_name);
	return (void *)font;
}

static void *witty_coretext_create_default_font(double size) {
	return witty_coretext_create_font_named("Menlo", size);
}

// Create a CTFont from an in-memory TTF/TTC buffer. Retained; caller frees
// with witty_coretext_release. Returns NULL on failure.
static void *witty_coretext_create_font_from_data(const uint8_t *data, size_t len, double size) {
	if (!data || len == 0) return NULL;
	CFDataRef cf = CFDataCreateWithBytesNoCopy(NULL, data, (CFIndex)len, kCFAllocatorNull);
	if (!cf) return NULL;
	CTFontDescriptorRef desc = CTFontManagerCreateFontDescriptorFromData(cf);
	CFRelease(cf);
	if (!desc) return NULL;
	CTFontRef font = CTFontCreateWithFontDescriptor(desc, witty_coretext_font_size(size), NULL);
	CFRelease(desc);
	return (void *)font;
}

static void *witty_coretext_create_font_from_path(char *path, double size) {
	if (!path || !path[0]) return witty_coretext_create_default_font(size);
	CFURLRef url = CFURLCreateFromFileSystemRepresentation(
		NULL,
		(const UInt8 *)path,
		(CFIndex)strlen(path),
		false
	);
	if (!url) return witty_coretext_create_default_font(size);

	CFArrayRef descs = CTFontManagerCreateFontDescriptorsFromURL(url);
	CFRelease(url);
	if (!descs || CFArrayGetCount(descs) == 0) {
		if (descs) CFRelease(descs);
		return witty_coretext_create_default_font(size);
	}

	CTFontDescriptorRef desc = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descs, 0);
	CTFontRef font = CTFontCreateWithFontDescriptor(desc, witty_coretext_font_size(size), NULL);
	CFRelease(descs);
	if (!font) return witty_coretext_create_default_font(size);
	return (void *)font;
}

static void *witty_coretext_copy_font_with_size(void *font_ptr, double size) {
	if (!font_ptr) return witty_coretext_create_default_font(size);
	return (void *)CTFontCreateCopyWithAttributes(
		(CTFontRef)font_ptr,
		witty_coretext_font_size(size),
		NULL,
		NULL
	);
}

static void witty_coretext_release(void *ptr) {
	if (ptr) CFRelease((CFTypeRef)ptr);
}

static int witty_coretext_copy_family_name(void *font_ptr, uint8_t *buf, size_t len) {
	if (!font_ptr || !buf || len == 0) return 0;
	buf[0] = 0;
	CFStringRef family = CTFontCopyFamilyName((CTFontRef)font_ptr);
	if (!family) return 0;
	Boolean ok = CFStringGetCString(family, (char *)buf, (CFIndex)len, kCFStringEncodingUTF8);
	CFRelease(family);
	return ok ? 1 : 0;
}

static int witty_coretext_copy_display_name(void *font_ptr, uint8_t *buf, size_t len) {
	if (!font_ptr || !buf || len == 0) return 0;
	buf[0] = 0;
	CFStringRef name = CTFontCopyDisplayName((CTFontRef)font_ptr);
	if (!name) return 0;
	Boolean ok = CFStringGetCString(name, (char *)buf, (CFIndex)len, kCFStringEncodingUTF8);
	CFRelease(name);
	return ok ? 1 : 0;
}

static int witty_coretext_glyph_for_codepoint(void *font_ptr, uint32_t cp, uint32_t *glyph_out) {
	if (!font_ptr || !glyph_out) return 0;
	UniChar chars[2] = {0, 0};
	CGGlyph glyphs[2] = {0, 0};
	CFIndex len = 1;
	if (cp <= 0xFFFF) {
		chars[0] = (UniChar)cp;
	} else if (cp <= 0x10FFFF) {
		uint32_t v = cp - 0x10000;
		chars[0] = (UniChar)(0xD800 + (v >> 10));
		chars[1] = (UniChar)(0xDC00 + (v & 0x3FF));
		len = 2;
	} else {
		return 0;
	}
	if (!CTFontGetGlyphsForCharacters((CTFontRef)font_ptr, chars, glyphs, len)) return 0;
	if (glyphs[0] == 0) return 0;
	*glyph_out = (uint32_t)glyphs[0];
	return 1;
}

static int witty_coretext_get_metrics(
	void *font_ptr,
	double *px_per_em,
	double *cell_width,
	double *ascent,
	double *descent,
	double *line_gap,
	double *underline_position,
	double *underline_thickness,
	double *strikethrough_position,
	double *strikethrough_thickness,
	double *cap_height,
	double *ex_height,
	double *ascii_height,
	double *ic_width,
	int *has_ic_width
) {
	if (!font_ptr) return 0;
	CTFontRef font = (CTFontRef)font_ptr;
	double size = CTFontGetSize(font);
	double asc = CTFontGetAscent(font);
	double desc = -CTFontGetDescent(font);
	double leading = CTFontGetLeading(font);
	double cap = CTFontGetCapHeight(font);
	double xh = CTFontGetXHeight(font);

	double max_advance = 0.0;
	UniChar chars[95];
	CGGlyph glyphs[95];
	CGSize advances[95];
	for (int i = 0; i < 95; i++) chars[i] = (UniChar)(32 + i);
	memset(glyphs, 0, sizeof(glyphs));
	memset(advances, 0, sizeof(advances));
	(void)CTFontGetGlyphsForCharacters(font, chars, glyphs, 95);
	CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, glyphs, advances, 95);
	for (int i = 0; i < 95; i++) {
		if (advances[i].width > max_advance) {
			max_advance = advances[i].width;
		}
	}
	CGRect ascii_bounds = CTFontGetBoundingRectsForGlyphs(
		font, kCTFontOrientationHorizontal, glyphs, NULL, 95);

	double measured_ic_width = 0.0;
	int measured_has_ic_width = 0;
	UniChar water_char = 0x6C34;
	CGGlyph water_glyph = 0;
	if (CTFontGetGlyphsForCharacters(font, &water_char, &water_glyph, 1) && water_glyph != 0) {
		CGSize water_advance = CGSizeZero;
		CTFontGetAdvancesForGlyphs(
			font, kCTFontOrientationHorizontal, &water_glyph, &water_advance, 1);
		CGRect water_bounds = CTFontGetBoundingRectsForGlyphs(
			font, kCTFontOrientationHorizontal, &water_glyph, NULL, 1);
		if (water_bounds.size.width <= water_advance.width) {
			measured_ic_width = water_advance.width;
			measured_has_ic_width = 1;
		}
	}

	if (px_per_em) *px_per_em = size;
	if (cell_width) *cell_width = max_advance;
	if (ascent) *ascent = asc;
	if (descent) *descent = desc;
	if (line_gap) *line_gap = leading > 0.0 ? leading : 0.0;
	if (underline_position) *underline_position = CTFontGetUnderlinePosition(font);
	if (underline_thickness) {
		double thickness = CTFontGetUnderlineThickness(font);
		*underline_thickness = thickness > 0.0 ? thickness : 1.0;
	}
	if (strikethrough_position) *strikethrough_position = cap > 0.0 ? cap * 0.45 : asc * 0.35;
	if (strikethrough_thickness) {
		double thickness = CTFontGetUnderlineThickness(font);
		*strikethrough_thickness = thickness > 0.0 ? thickness : 1.0;
	}
	if (cap_height) *cap_height = cap;
	if (ex_height) *ex_height = xh;
	if (ascii_height) *ascii_height = ascii_bounds.size.height;
	if (ic_width) *ic_width = measured_ic_width;
	if (has_ic_width) *has_ic_width = measured_has_ic_width;
	return 1;
}

static int witty_coretext_render_glyph(
	void *font_ptr,
	uint32_t glyph_id,
	double cell_height,
	double cell_baseline,
	uint32_t *width_out,
	uint32_t *height_out,
	int32_t *offset_x_out,
	int32_t *offset_y_out,
	uint8_t **buffer_out
) {
	if (!font_ptr || !width_out || !height_out || !offset_x_out || !offset_y_out || !buffer_out) {
		return 0;
	}
	*width_out = 0;
	*height_out = 0;
	*offset_x_out = 0;
	*offset_y_out = 0;
	*buffer_out = NULL;

	CGGlyph glyph = (CGGlyph)glyph_id;
	if (glyph == 0) return 0;
	CGRect rect = CTFontGetBoundingRectsForGlyphs(
		(CTFontRef)font_ptr,
		kCTFontOrientationHorizontal,
		&glyph,
		NULL,
		1
	);
	if (CGRectIsNull(rect) || rect.size.width <= 0.0 || rect.size.height <= 0.0) return 1;

	double pad = 1.0;
	double min_x = floor(rect.origin.x - pad);
	double min_y = floor(rect.origin.y - pad);
	double max_x = ceil(rect.origin.x + rect.size.width + pad);
	double max_y = ceil(rect.origin.y + rect.size.height + pad);
	size_t width = (size_t)(max_x - min_x);
	size_t height = (size_t)(max_y - min_y);
	if (width == 0 || height == 0 || width > 512 || height > 512) return 0;

	size_t len = width * height;
	uint8_t *raw = (uint8_t *)calloc(len, 1);
	if (!raw) return 0;

	CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
	if (!gray) {
		free(raw);
		return 0;
	}
	CGContextRef ctx = CGBitmapContextCreate(raw, width, height, 8, width, gray, kCGImageAlphaNone);
	CGColorSpaceRelease(gray);
	if (!ctx) {
		free(raw);
		return 0;
	}

	CGContextSetAllowsAntialiasing(ctx, true);
	CGContextSetShouldAntialias(ctx, true);
	CGContextSetAllowsFontSmoothing(ctx, true);
	CGContextSetShouldSmoothFonts(ctx, true);
	CGContextSetAllowsFontSubpixelPositioning(ctx, true);
	CGContextSetShouldSubpixelPositionFonts(ctx, true);
	CGContextSetAllowsFontSubpixelQuantization(ctx, false);
	CGContextSetShouldSubpixelQuantizeFonts(ctx, false);
	CGContextSetGrayFillColor(ctx, 1.0, 1.0);
	CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);

	CGPoint pos = CGPointMake(-min_x, -min_y);
	CTFontDrawGlyphs((CTFontRef)font_ptr, &glyph, &pos, 1, ctx);
	CGContextRelease(ctx);

	uint8_t *out = (uint8_t *)malloc(len);
	if (!out) {
		free(raw);
		return 0;
	}
	for (size_t y = 0; y < height; y++) {
		memcpy(out + (y * width), raw + ((height - 1 - y) * width), width);
	}
	free(raw);

	*width_out = (uint32_t)width;
	*height_out = (uint32_t)height;
	*offset_x_out = (int32_t)min_x;
	*offset_y_out = (int32_t)(cell_height - cell_baseline + max_y);
	*buffer_out = out;
	return 1;
}

static void witty_coretext_free_buffer(uint8_t *ptr) {
	free(ptr);
}

// ------------------------------------------------------------------
// Discovery + descriptor scoring helpers (CoreText backend).
// ------------------------------------------------------------------

static void witty_ct_release(void *ptr) {
	if (ptr) CFRelease((CFTypeRef)ptr);
}

static void witty_ct_retain(void *ptr) {
	if (ptr) CFRetain((CFTypeRef)ptr);
}

// Build a CTFontDescriptor from the fields of a font Descriptor. Any zero/
// empty field is omitted. Traits are only set if at least one is requested.
static void *witty_ct_build_descriptor(
	const char *family,
	const char *style,
	uint32_t codepoint,
	double size,
	int bold,
	int italic,
	int monospace
) {
	CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(
		NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	if (!attrs) return NULL;

	if (family && family[0]) {
		CFStringRef v = CFStringCreateWithCString(NULL, family, kCFStringEncodingUTF8);
		if (v) {
			CFDictionarySetValue(attrs, kCTFontFamilyNameAttribute, v);
			CFRelease(v);
		}
	}
	if (style && style[0]) {
		CFStringRef v = CFStringCreateWithCString(NULL, style, kCFStringEncodingUTF8);
		if (v) {
			CFDictionarySetValue(attrs, kCTFontStyleNameAttribute, v);
			CFRelease(v);
		}
	}
	if (codepoint > 0) {
		CFCharacterSetRef cs = CFCharacterSetCreateWithCharactersInRange(
			NULL, CFRangeMake((CFIndex)codepoint, 1));
		if (cs) {
			CFDictionarySetValue(attrs, kCTFontCharacterSetAttribute, cs);
			CFRelease(cs);
		}
	}
	if (size > 0) {
		int32_t s = (int32_t)(size + 0.5);
		CFNumberRef v = CFNumberCreate(NULL, kCFNumberSInt32Type, &s);
		if (v) {
			CFDictionarySetValue(attrs, kCTFontSizeAttribute, v);
			CFRelease(v);
		}
	}

	uint32_t traits = 0;
	if (bold) traits |= kCTFontTraitBold;
	if (italic) traits |= kCTFontTraitItalic;
	if (monospace) traits |= kCTFontTraitMonoSpace;
	if (traits != 0) {
		int32_t tv = (int32_t)traits;
		CFNumberRef num = CFNumberCreate(NULL, kCFNumberSInt32Type, &tv);
		CFMutableDictionaryRef tdict = CFDictionaryCreateMutable(
			NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		if (num && tdict) {
			CFDictionarySetValue(tdict, kCTFontSymbolicTrait, num);
			CFDictionarySetValue(attrs, kCTFontTraitsAttribute, tdict);
		}
		if (num) CFRelease(num);
		if (tdict) CFRelease(tdict);
	}

	CTFontDescriptorRef desc = CTFontDescriptorCreateWithAttributes(attrs);
	CFRelease(attrs);
	return (void *)desc;
}

// Given a search descriptor, build a font collection and return the CFArray
// of matching descriptors (retained; caller releases). May return NULL.
static void *witty_ct_matching_descriptors(void *search_desc) {
	if (!search_desc) return NULL;
	const void *values[1] = { search_desc };
	CFArrayRef desc_arr = CFArrayCreate(NULL, values, 1, &kCFTypeArrayCallBacks);
	if (!desc_arr) return NULL;
	CTFontCollectionRef set = CTFontCollectionCreateWithFontDescriptors(desc_arr, NULL);
	CFRelease(desc_arr);
	if (!set) return NULL;
	CFArrayRef list = CTFontCollectionCreateMatchingFontDescriptors(set);
	CFRelease(set);
	return (void *)list;
}

static int witty_ct_descriptor_is_color(void *desc_ptr) {
	if (!desc_ptr) return 0;
	CTFontRef font = CTFontCreateWithFontDescriptor(
		(CTFontDescriptorRef)desc_ptr, 12.0, NULL);
	if (!font) return 0;
	CTFontSymbolicTraits traits = CTFontGetSymbolicTraits(font);
	CFRelease(font);
	return (traits & kCTFontTraitColorGlyphs) != 0;
}

static int witty_cf_array_count(void *arr) {
	if (!arr) return 0;
	return (int)CFArrayGetCount((CFArrayRef)arr);
}

// Returns the value at index (NOT retained; caller should retain to keep it
// alive past the array's lifetime).
static void *witty_cf_array_get(void *arr, int i) {
	if (!arr) return NULL;
	return (void *)CFArrayGetValueAtIndex((CFArrayRef)arr, (CFIndex)i);
}

// Compute a sorting score for a candidate descriptor against the search
// fields. Higher is better. The packed layout matches font/discovery.v's
// Score.to_int(): glyph_count[0..16), fuzzy_style[16..24), bold[24],
// italic[25], exact_style[26], monospace[27], codepoint[28].
//
// This mirrors ghostty's Score.score() using CoreText's own trait/attribute
// APIs. Refinement of bold/italic via the 'head'/'OS/2'/variation tables is
// intentionally omitted here (documented boundary): we rely on the descriptor
// symbolic traits, which is correct for the common case.
static uint64_t witty_ct_score(
	const char *desired_style, // may be NULL
	uint32_t codepoint,
	int want_bold,
	int want_italic,
	void *candidate_desc
) {
	uint64_t glyph_count = 0;
	uint8_t fuzzy_style = 0;
	uint64_t bold_match = 0;
	uint64_t italic_match = 0;
	uint64_t exact_style = 0;
	uint64_t monospace = 0;
	uint64_t has_codepoint = 0;

	if (!candidate_desc) return 0;

	// We always load the font; fonts we can't load score 0.
	CTFontRef font = CTFontCreateWithFontDescriptor(
		(CTFontDescriptorRef)candidate_desc, 12.0, NULL);
	if (!font) return 0;

	// Glyph count (clamped to u16 max).
	{
		CFIndex gc = CTFontGetGlyphCount(font);
		if (gc < 0) gc = 0;
		if (gc > 0xFFFF) gc = 0xFFFF;
		glyph_count = (uint64_t)gc;
	}

	// Codepoint coverage.
	if (codepoint > 0) {
		uint32_t g = 0;
		has_codepoint = witty_coretext_glyph_for_codepoint((void *)font, codepoint, &g) ? 1 : 0;
	}

	// Symbolic traits (bold / italic / monospace).
	int is_bold = 0, is_italic = 0, is_mono = 0;
	{
		CTFontSymbolicTraits t = CTFontGetSymbolicTraits(font);
		is_bold = (t & kCTFontTraitBold) ? 1 : 0;
		is_italic = (t & kCTFontTraitItalic) ? 1 : 0;
		is_mono = (t & kCTFontTraitMonoSpace) ? 1 : 0;
	}
	monospace = is_mono ? 1 : 0;
	bold_match = (want_bold == is_bold) ? 1 : 0;
	italic_match = (want_italic == is_italic) ? 1 : 0;

	// Style string from the descriptor.
	char style_buf[128];
	style_buf[0] = 0;
	{
		CFStringRef sname = (CFStringRef)CTFontDescriptorCopyAttribute(
			(CTFontDescriptorRef)candidate_desc, kCTFontStyleNameAttribute);
		if (sname) {
			CFStringGetCString(sname, style_buf, sizeof(style_buf), kCFStringEncodingUTF8);
			CFRelease(sname);
		}
	}

	// Determine desired style strings.
	const char *desired[4];
	int desired_n = 0;
	if (desired_style && desired_style[0]) {
		desired[desired_n++] = desired_style;
	} else if (want_bold && want_italic) {
		desired[desired_n++] = "bold italic";
		desired[desired_n++] = "bold";
		desired[desired_n++] = "italic";
		desired[desired_n++] = "oblique";
	} else if (want_bold) {
		desired[desired_n++] = "bold";
		desired[desired_n++] = "upright";
	} else if (want_italic) {
		desired[desired_n++] = "italic";
		desired[desired_n++] = "regular";
		desired[desired_n++] = "oblique";
	} else {
		desired[desired_n++] = "regular";
		desired[desired_n++] = "upright";
	}

	// Exact (case-insensitive) match on first desired style.
	if (desired_n > 0 && strcasecmp(style_buf, desired[0]) == 0) {
		exact_style = 1;
	}

	// Fuzzy match: start from the style length, subtract any matching
	// desired-style lengths, then invert so smaller leftover -> higher score.
	{
		size_t leftover = strlen(style_buf);
		size_t slen = leftover;
		for (int i = 0; i < desired_n; i++) {
			// case-insensitive substring search
			size_t dl = strlen(desired[i]);
			if (dl == 0 || dl > slen) continue;
			int found = 0;
			for (size_t j = 0; j + dl <= slen && !found; j++) {
#if defined(__APPLE__)
				if (strncasecmp(style_buf + j, desired[i], dl) == 0) found = 1;
#else
				if (strncmp(style_buf + j, desired[i], dl) == 0) found = 1;
#endif
			}
			if (found) {
				if (leftover >= dl) leftover -= dl; else leftover = 0;
			}
		}
		if (leftover > 255) leftover = 255;
		fuzzy_style = (uint8_t)(255 - leftover);
	}

	CFRelease(font);

	uint64_t result = glyph_count & 0xFFFF;
	result |= ((uint64_t)fuzzy_style) << 16;
	result |= bold_match << 24;
	result |= italic_match << 25;
	result |= exact_style << 26;
	result |= monospace << 27;
	result |= has_codepoint << 28;
	return result;
}

// Create a copy of a descriptor with the character-set attribute removed so
// that loaded fonts aren't restricted to that single codepoint. Retained;
// caller releases.
static void *witty_ct_descriptor_drop_charset(void *desc) {
	if (!desc) return NULL;
	CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(
		NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	if (!attrs) return NULL;
	CFDictionarySetValue(attrs, kCTFontCharacterSetAttribute, kCFNull);
	CTFontDescriptorRef out = CTFontDescriptorCreateCopyWithAttributes(
		(CTFontDescriptorRef)desc, attrs);
	CFRelease(attrs);
	return (void *)out;
}

// Extract the font file path for a descriptor (via its URL attribute).
// Returns 1 on success and fills buf; 0 otherwise.
static int witty_ct_descriptor_path(void *desc, uint8_t *buf, size_t len) {
	if (!desc || !buf || len == 0) return 0;
	buf[0] = 0;
	CFURLRef url = (CFURLRef)CTFontDescriptorCopyAttribute(
		(CTFontDescriptorRef)desc, kCTFontURLAttribute);
	if (!url) return 0;
	Boolean ok = CFURLGetFileSystemRepresentation(url, true, buf, (CFIndex)len);
	CFRelease(url);
	return ok ? 1 : 0;
}

// Create a CTFont from a descriptor at the given size. Retained; caller frees
// with witty_coretext_release.
static void *witty_ct_font_from_descriptor(void *desc, double size) {
	if (!desc) return NULL;
	return (void *)CTFontCreateWithFontDescriptor(
		(CTFontDescriptorRef)desc, witty_coretext_font_size(size), NULL);
}

// Copy the descriptor of a CTFont (retained; caller releases).
static void *witty_ct_font_copy_descriptor(void *font) {
	if (!font) return NULL;
	return (void *)CTFontCopyFontDescriptor((CTFontRef)font);
}

// Use CTFontCreateForString to find a font that supports the given codepoint,
// starting from `orig_font`. Returns a retained descriptor, or NULL. Skips
// CoreText's "LastResort" fallback font.
static void *witty_ct_font_for_string(void *orig_font, uint32_t codepoint) {
	if (!orig_font || codepoint == 0) return NULL;

	UniChar chars[2] = {0, 0};
	CFIndex clen = 1;
	if (codepoint <= 0xFFFF) {
		chars[0] = (UniChar)codepoint;
	} else if (codepoint <= 0x10FFFF) {
		uint32_t v = codepoint - 0x10000;
		chars[0] = (UniChar)(0xD800 + (v >> 10));
		chars[1] = (UniChar)(0xDC00 + (v & 0x3FF));
		clen = 2;
	} else {
		return NULL;
	}

	CFStringRef str = CFStringCreateWithCharacters(NULL, chars, clen);
	if (!str) return NULL;

	CTFontRef font = CTFontCreateForString(
		(CTFontRef)orig_font, str, CFRangeMake(0, clen));
	CFRelease(str);
	if (!font) return NULL;

	// Reject the "LastResort" fallback font.
	CFStringRef psname = CTFontCopyPostScriptName(font);
	if (psname) {
		char name_buf[64];
		name_buf[0] = 0;
		if (CFStringGetCString(psname, name_buf, sizeof(name_buf), kCFStringEncodingUTF8)) {
			if (strcmp(name_buf, "LastResort") == 0) {
				CFRelease(psname);
				CFRelease(font);
				return NULL;
			}
		}
		CFRelease(psname);
	}

	CTFontDescriptorRef desc = CTFontCopyFontDescriptor(font);
	CFRelease(font);
	return (void *)desc;
}

// ------------------------------------------------------------------
// Face helpers (CoreText backend).
// ------------------------------------------------------------------

// Copy an SFNT table from a font by 4-char tag. Returns 1 and allocates a
// buffer (freed with witty_coretext_free_buffer) on success, 0 otherwise.
static int witty_coretext_copy_table(
	void *font_ptr,
	const char *tag4,
	uint8_t **buffer_out,
	uint32_t *len_out
) {
	if (buffer_out) *buffer_out = NULL;
	if (len_out) *len_out = 0;
	if (!font_ptr || !tag4 || !buffer_out || !len_out) return 0;

	uint32_t tag = ((uint32_t)(uint8_t)tag4[0] << 24) |
		((uint32_t)(uint8_t)tag4[1] << 16) |
		((uint32_t)(uint8_t)tag4[2] << 8) |
		((uint32_t)(uint8_t)tag4[3]);

	CFDataRef data = CTFontCopyTable(
		(CTFontRef)font_ptr, (CTFontTableTag)tag, kCTFontTableOptionNoOptions);
	if (!data) return 0;

	CFIndex n = CFDataGetLength(data);
	const UInt8 *ptr = CFDataGetBytePtr(data);
	if (n <= 0 || !ptr) {
		CFRelease(data);
		return 0;
	}
	uint8_t *out = (uint8_t *)malloc((size_t)n);
	if (!out) {
		CFRelease(data);
		return 0;
	}
	memcpy(out, ptr, (size_t)n);
	CFRelease(data);
	*buffer_out = out;
	*len_out = (uint32_t)n;
	return 1;
}

// Copy a font applying an italic-skew transform (synthetic italic). Retained.
static void *witty_coretext_copy_italic(void *font_ptr) {
	if (!font_ptr) return NULL;
	CGAffineTransform m = CGAffineTransformMake(1, 0, 0.267949, 1, 0, 0);
	return (void *)CTFontCreateCopyWithAttributes(
		(CTFontRef)font_ptr, 0.0, &m, NULL);
}

// Copy a font with a new descriptor that carries variation axes applied.
// `ids` and `values` are parallel arrays of length `count`. Retained.
static void *witty_coretext_copy_with_variations(
	void *font_ptr,
	const uint32_t *ids,
	const double *values,
	int count,
	double size
) {
	if (!font_ptr) return NULL;
	CTFontDescriptorRef desc = CTFontCopyFontDescriptor((CTFontRef)font_ptr);
	if (!desc) return NULL;
	for (int i = 0; i < count; i++) {
		int32_t idv = (int32_t)ids[i];
		CFNumberRef idnum = CFNumberCreate(NULL, kCFNumberSInt32Type, &idv);
		if (!idnum) continue;
		CTFontDescriptorRef next = CTFontDescriptorCreateCopyWithVariation(
			desc, idnum, values[i]);
		CFRelease(idnum);
		if (next) {
			CFRelease(desc);
			desc = next;
		}
	}
	CTFontRef out = CTFontCreateCopyWithAttributes(
		(CTFontRef)font_ptr, size > 0 ? size : 0.0, NULL, desc);
	CFRelease(desc);
	return (void *)out;
}

// Returns 1 if the font has any colorized glyphs (symbolic color trait), and
// sets *has_sbix to 1 if it has an sbix table.
static int witty_coretext_color_info(void *font_ptr, int *has_sbix) {
	if (has_sbix) *has_sbix = 0;
	if (!font_ptr) return 0;
	CTFontSymbolicTraits t = CTFontGetSymbolicTraits((CTFontRef)font_ptr);
	int color = (t & kCTFontTraitColorGlyphs) ? 1 : 0;
	if (has_sbix) {
		CFDataRef data = CTFontCopyTable(
			(CTFontRef)font_ptr, (CTFontTableTag)'sbix', kCTFontTableOptionNoOptions);
		if (data) {
			if (CFDataGetLength(data) > 0) *has_sbix = 1;
			CFRelease(data);
		}
	}
	return color;
}

#else
static void *witty_coretext_create_font_named(char *name, double size) {
	(void)name;
	(void)size;
	return NULL;
}

static void *witty_coretext_create_default_font(double size) {
	(void)size;
	return NULL;
}

static void *witty_coretext_create_font_from_data(const uint8_t *data, size_t len, double size) {
	(void)data;
	(void)len;
	(void)size;
	return NULL;
}

static void *witty_coretext_create_font_from_path(char *path, double size) {
	(void)path;
	(void)size;
	return NULL;
}

static void *witty_coretext_copy_font_with_size(void *font_ptr, double size) {
	(void)font_ptr;
	(void)size;
	return NULL;
}

static void witty_coretext_release(void *ptr) {
	(void)ptr;
}

static int witty_coretext_copy_family_name(void *font_ptr, uint8_t *buf, size_t len) {
	(void)font_ptr;
	if (buf && len > 0) buf[0] = 0;
	return 0;
}

static int witty_coretext_copy_display_name(void *font_ptr, uint8_t *buf, size_t len) {
	(void)font_ptr;
	if (buf && len > 0) buf[0] = 0;
	return 0;
}

static int witty_coretext_glyph_for_codepoint(void *font_ptr, uint32_t cp, uint32_t *glyph_out) {
	(void)font_ptr;
	(void)cp;
	(void)glyph_out;
	return 0;
}

static int witty_coretext_get_metrics(
	void *font_ptr,
	double *px_per_em,
	double *cell_width,
	double *ascent,
	double *descent,
	double *line_gap,
	double *underline_position,
	double *underline_thickness,
	double *strikethrough_position,
	double *strikethrough_thickness,
	double *cap_height,
	double *ex_height,
	double *ascii_height,
	double *ic_width,
	int *has_ic_width
) {
	(void)font_ptr;
	(void)px_per_em;
	(void)cell_width;
	(void)ascent;
	(void)descent;
	(void)line_gap;
	(void)underline_position;
	(void)underline_thickness;
	(void)strikethrough_position;
	(void)strikethrough_thickness;
	(void)cap_height;
	(void)ex_height;
	(void)ascii_height;
	(void)ic_width;
	(void)has_ic_width;
	return 0;
}

static int witty_coretext_render_glyph(
	void *font_ptr,
	uint32_t glyph_id,
	double cell_height,
	double cell_baseline,
	uint32_t *width_out,
	uint32_t *height_out,
	int32_t *offset_x_out,
	int32_t *offset_y_out,
	uint8_t **buffer_out
) {
	(void)font_ptr;
	(void)glyph_id;
	(void)cell_height;
	(void)cell_baseline;
	if (width_out) *width_out = 0;
	if (height_out) *height_out = 0;
	if (offset_x_out) *offset_x_out = 0;
	if (offset_y_out) *offset_y_out = 0;
	if (buffer_out) *buffer_out = NULL;
	return 0;
}

static void witty_coretext_free_buffer(uint8_t *ptr) {
	(void)ptr;
}

// --- Non-Apple stubs for discovery/face helpers. ---

static void witty_ct_release(void *ptr) { (void)ptr; }
static void witty_ct_retain(void *ptr) { (void)ptr; }

static void *witty_ct_build_descriptor(
	const char *family, const char *style, uint32_t codepoint,
	double size, int bold, int italic, int monospace
) {
	(void)family; (void)style; (void)codepoint; (void)size;
	(void)bold; (void)italic; (void)monospace;
	return NULL;
}

static void *witty_ct_matching_descriptors(void *search_desc) {
	(void)search_desc;
	return NULL;
}

static int witty_ct_descriptor_is_color(void *desc_ptr) {
	(void)desc_ptr;
	return 0;
}

static int witty_cf_array_count(void *arr) { (void)arr; return 0; }
static void *witty_cf_array_get(void *arr, int i) { (void)arr; (void)i; return NULL; }

static uint64_t witty_ct_score(
	const char *desired_style, uint32_t codepoint,
	int want_bold, int want_italic, void *candidate_desc
) {
	(void)desired_style; (void)codepoint; (void)want_bold;
	(void)want_italic; (void)candidate_desc;
	return 0;
}

static void *witty_ct_descriptor_drop_charset(void *desc) { (void)desc; return NULL; }

static int witty_ct_descriptor_path(void *desc, uint8_t *buf, size_t len) {
	(void)desc;
	if (buf && len > 0) buf[0] = 0;
	return 0;
}

static void *witty_ct_font_from_descriptor(void *desc, double size) {
	(void)desc; (void)size;
	return NULL;
}

static void *witty_ct_font_copy_descriptor(void *font) { (void)font; return NULL; }

static void *witty_ct_font_for_string(void *orig_font, uint32_t codepoint) {
	(void)orig_font; (void)codepoint;
	return NULL;
}

static int witty_coretext_copy_table(
	void *font_ptr, const char *tag4, uint8_t **buffer_out, uint32_t *len_out
) {
	(void)font_ptr; (void)tag4;
	if (buffer_out) *buffer_out = NULL;
	if (len_out) *len_out = 0;
	return 0;
}

static void *witty_coretext_copy_italic(void *font_ptr) { (void)font_ptr; return NULL; }

static void *witty_coretext_copy_with_variations(
	void *font_ptr, const uint32_t *ids, const double *values, int count, double size
) {
	(void)font_ptr; (void)ids; (void)values; (void)count; (void)size;
	return NULL;
}

static int witty_coretext_color_info(void *font_ptr, int *has_sbix) {
	(void)font_ptr;
	if (has_sbix) *has_sbix = 0;
	return 0;
}
#endif
