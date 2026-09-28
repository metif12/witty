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

// Primitive metric accessors used by the direct V translation of
// coretext.zig's Face.getMetrics().
static int witty_coretext_basic_metrics(
	void *font_ptr,
	double *px_per_em,
	double *ascent,
	double *descent,
	double *line_gap,
	double *cap_height,
	double *ex_height
) {
	if (!font_ptr) return 0;
	CTFontRef font = (CTFontRef)font_ptr;
	if (px_per_em) *px_per_em = CTFontGetSize(font);
	if (ascent) *ascent = CTFontGetAscent(font);
	if (descent) *descent = CTFontGetDescent(font);
	if (line_gap) *line_gap = CTFontGetLeading(font);
	if (cap_height) *cap_height = CTFontGetCapHeight(font);
	if (ex_height) *ex_height = CTFontGetXHeight(font);
	return 1;
}

static int witty_coretext_glyphs_for_characters(
	void *font_ptr, const uint16_t *characters, uint16_t *glyphs, int count
) {
	if (!font_ptr || !characters || !glyphs || count < 0) return 0;
	return CTFontGetGlyphsForCharacters(
		(CTFontRef)font_ptr, (const UniChar *)characters, (CGGlyph *)glyphs,
		(CFIndex)count) ? 1 : 0;
}

static double witty_coretext_glyph_advances(
	void *font_ptr, const uint16_t *glyphs, void *advances, int count
) {
	if (!font_ptr || !glyphs || count < 0) return 0;
	return CTFontGetAdvancesForGlyphs(
		(CTFontRef)font_ptr, kCTFontOrientationHorizontal,
		(const CGGlyph *)glyphs, (CGSize *)advances, (CFIndex)count);
}

static int witty_coretext_glyphs_bounds(
	void *font_ptr, const uint16_t *glyphs, int count,
	double *x_out, double *y_out, double *width_out, double *height_out
) {
	if (!font_ptr || !glyphs || count < 0 || !x_out || !y_out ||
		!width_out || !height_out) return 0;
	CGRect rect = CTFontGetBoundingRectsForGlyphs(
		(CTFontRef)font_ptr, kCTFontOrientationHorizontal,
		(const CGGlyph *)glyphs, NULL, (CFIndex)count);
	*x_out = rect.origin.x;
	*y_out = rect.origin.y;
	*width_out = rect.size.width;
	*height_out = rect.size.height;
	return 1;
}

static uint32_t witty_coretext_units_per_em(void *font_ptr) {
	if (!font_ptr) return 0;
	return (uint32_t)CTFontGetUnitsPerEm((CTFontRef)font_ptr);
}

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

static int witty_coretext_glyph_bounds(
	void *font_ptr,
	uint32_t glyph_id,
	double *x_out,
	double *y_out,
	double *width_out,
	double *height_out
) {
	if (!font_ptr || !x_out || !y_out || !width_out || !height_out) return 0;
	CGGlyph glyph = (CGGlyph)glyph_id;
	CGRect rect = CTFontGetBoundingRectsForGlyphs(
		(CTFontRef)font_ptr,
		kCTFontOrientationHorizontal,
		&glyph,
		NULL,
		1
	);
	if (CGRectIsNull(rect)) return 0;
	*x_out = rect.origin.x;
	*y_out = rect.origin.y;
	*width_out = rect.size.width;
	*height_out = rect.size.height;
	return 1;
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

// Primitive CoreText accessors used by the direct V translation of
// discovery.zig's Score.score().
static uint64_t witty_ct_font_glyph_count(void *font_ptr) {
	if (!font_ptr) return 0;
	CFIndex count = CTFontGetGlyphCount((CTFontRef)font_ptr);
	return count > 0 ? (uint64_t)count : 0;
}

// Return the three symbolic traits used by discovery as compact bridge bits:
// bit 0 bold, bit 1 italic, and bit 2 monospace.
static uint32_t witty_ct_descriptor_traits(void *desc_ptr) {
	if (!desc_ptr) return 0;
	uint32_t result = 0;
	CFDictionaryRef traits = (CFDictionaryRef)CTFontDescriptorCopyAttribute(
		(CTFontDescriptorRef)desc_ptr, kCTFontTraitsAttribute);
	if (!traits) return 0;
	CFNumberRef symbolic = (CFNumberRef)CFDictionaryGetValue(
		traits, kCTFontSymbolicTrait);
	if (symbolic) {
		int32_t raw = 0;
		if (CFNumberGetValue(symbolic, kCFNumberSInt32Type, &raw)) {
			CTFontSymbolicTraits value = (CTFontSymbolicTraits)(uint32_t)raw;
			if (value & kCTFontTraitBold) result |= 1u;
			if (value & kCTFontTraitItalic) result |= 2u;
			if (value & kCTFontTraitMonoSpace) result |= 4u;
		}
	}
	CFRelease(traits);
	return result;
}

static int witty_ct_descriptor_style_name(
	void *desc_ptr, uint8_t *buf, size_t len
) {
	if (!desc_ptr || !buf || len == 0) return 0;
	buf[0] = 0;
	CFStringRef value = (CFStringRef)CTFontDescriptorCopyAttribute(
		(CTFontDescriptorRef)desc_ptr, kCTFontStyleNameAttribute);
	if (!value) return 0;
	Boolean ok = CFStringGetCString(
		value, (char *)buf, (CFIndex)len, kCFStringEncodingUTF8);
	CFRelease(value);
	return ok ? 1 : 0;
}

static void *witty_ct_font_copy_variation_axes(void *font_ptr) {
	if (!font_ptr) return NULL;
	return (void *)CTFontCopyVariationAxes((CTFontRef)font_ptr);
}

static void *witty_ct_font_copy_variation_values(void *font_ptr) {
	if (!font_ptr) return NULL;
	return (void *)CTFontCopyAttribute(
		(CTFontRef)font_ptr, kCTFontVariationAttribute);
}

static int witty_ct_variation_count(void *axes_ptr) {
	if (!axes_ptr) return 0;
	return (int)CFArrayGetCount((CFArrayRef)axes_ptr);
}

static int witty_ct_variation_axis_info(
	void *axes_ptr,
	int index,
	uint8_t *name_buf,
	size_t name_len,
	uint32_t *identifier_out,
	double *minimum_out,
	double *maximum_out,
	double *default_out
) {
	if (!axes_ptr || !name_buf || name_len == 0 || !identifier_out ||
		!minimum_out || !maximum_out || !default_out) return 0;
	CFArrayRef axes = (CFArrayRef)axes_ptr;
	CFIndex count = CFArrayGetCount(axes);
	if (index < 0 || (CFIndex)index >= count) return 0;
	CFDictionaryRef axis = (CFDictionaryRef)CFArrayGetValueAtIndex(
		axes, (CFIndex)index);
	CFNumberRef identifier = (CFNumberRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisIdentifierKey);
	CFStringRef name = (CFStringRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisNameKey);
	CFNumberRef minimum = (CFNumberRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisMinimumValueKey);
	CFNumberRef maximum = (CFNumberRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisMaximumValueKey);
	CFNumberRef default_value = (CFNumberRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisDefaultValueKey);
	if (!identifier || !name || !minimum || !maximum || !default_value) return 0;

	int32_t identifier_value = 0;
	(void)CFNumberGetValue(identifier, kCFNumberSInt32Type, &identifier_value);
	*identifier_out = (uint32_t)identifier_value;
	*minimum_out = 0;
	*maximum_out = 0;
	*default_out = 0;
	(void)CFNumberGetValue(minimum, kCFNumberDoubleType, minimum_out);
	(void)CFNumberGetValue(maximum, kCFNumberDoubleType, maximum_out);
	(void)CFNumberGetValue(default_value, kCFNumberDoubleType, default_out);
	name_buf[0] = 0;
	(void)CFStringGetCString(
		name, (char *)name_buf, (CFIndex)name_len, kCFStringEncodingUTF8);
	return 1;
}

// Extract one variation axis name and its effective value. The effective value
// is the font instance value when present and the axis default otherwise.
static int witty_ct_variation_get(
	void *axes_ptr,
	void *values_ptr,
	int index,
	uint8_t *name_buf,
	size_t name_len,
	double *value_out
) {
	if (!axes_ptr || !values_ptr || !name_buf || name_len == 0 || !value_out) {
		return 0;
	}
	CFArrayRef axes = (CFArrayRef)axes_ptr;
	CFIndex count = CFArrayGetCount(axes);
	if (index < 0 || (CFIndex)index >= count) return 0;
	CFDictionaryRef axis = (CFDictionaryRef)CFArrayGetValueAtIndex(
		axes, (CFIndex)index);
	CFNumberRef identifier = (CFNumberRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisIdentifierKey);
	CFStringRef name = (CFStringRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisNameKey);
	CFNumberRef default_value = (CFNumberRef)CFDictionaryGetValue(
		axis, kCTFontVariationAxisDefaultValueKey);
	if (!identifier || !name || !default_value) return 0;

	double value = 0;
	(void)CFNumberGetValue(default_value, kCFNumberDoubleType, &value);
	CFNumberRef configured = (CFNumberRef)CFDictionaryGetValue(
		(CFDictionaryRef)values_ptr, identifier);
	if (configured) {
		(void)CFNumberGetValue(configured, kCFNumberDoubleType, &value);
	}
	name_buf[0] = 0;
	(void)CFStringGetCString(
		name, (char *)name_buf, (CFIndex)name_len, kCFStringEncodingUTF8);
	*value_out = value;
	return 1;
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

static int witty_coretext_basic_metrics(
	void *font_ptr,
	double *px_per_em,
	double *ascent,
	double *descent,
	double *line_gap,
	double *cap_height,
	double *ex_height
) {
	(void)font_ptr;
	(void)px_per_em;
	(void)ascent;
	(void)descent;
	(void)line_gap;
	(void)cap_height;
	(void)ex_height;
	return 0;
}

static int witty_coretext_glyphs_for_characters(
	void *font_ptr, const uint16_t *characters, uint16_t *glyphs, int count
) {
	(void)font_ptr; (void)characters; (void)glyphs; (void)count;
	return 0;
}

static double witty_coretext_glyph_advances(
	void *font_ptr, const uint16_t *glyphs, void *advances, int count
) {
	(void)font_ptr; (void)glyphs; (void)advances; (void)count;
	return 0;
}

static int witty_coretext_glyphs_bounds(
	void *font_ptr, const uint16_t *glyphs, int count,
	double *x_out, double *y_out, double *width_out, double *height_out
) {
	(void)font_ptr; (void)glyphs; (void)count;
	if (x_out) *x_out = 0;
	if (y_out) *y_out = 0;
	if (width_out) *width_out = 0;
	if (height_out) *height_out = 0;
	return 0;
}

static uint32_t witty_coretext_units_per_em(void *font_ptr) {
	(void)font_ptr;
	return 0;
}

static void *witty_coretext_create_hb_font(void *font_ptr, double pixels) {
	(void)font_ptr;
	(void)pixels;
	return NULL;
}

static void witty_coretext_destroy_hb_font(void *font_ptr) {
	(void)font_ptr;
}

static int witty_coretext_glyph_bounds(
	void *font_ptr, uint32_t glyph_id, double *x_out, double *y_out,
	double *width_out, double *height_out
) {
	(void)font_ptr; (void)glyph_id;
	if (x_out) *x_out = 0;
	if (y_out) *y_out = 0;
	if (width_out) *width_out = 0;
	if (height_out) *height_out = 0;
	return 0;
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

static void *witty_ct_font_copy_variation_axes(void *font_ptr) {
	(void)font_ptr;
	return NULL;
}

static int witty_ct_variation_count(void *axes_ptr) {
	(void)axes_ptr;
	return 0;
}

static int witty_ct_variation_axis_info(
	void *axes_ptr, int index, uint8_t *name_buf, size_t name_len,
	uint32_t *identifier_out, double *minimum_out, double *maximum_out,
	double *default_out
) {
	(void)axes_ptr; (void)index; (void)identifier_out; (void)minimum_out;
	(void)maximum_out; (void)default_out;
	if (name_buf && name_len > 0) name_buf[0] = 0;
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

#endif
