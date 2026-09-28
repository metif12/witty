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

// ------------------------------------------------------------------
// Discovery + descriptor scoring helpers (CoreText backend).
// ------------------------------------------------------------------

static void witty_ct_release(void *ptr) {
	if (ptr) CFRelease((CFTypeRef)ptr);
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

// Copy the descriptor of a CTFont (retained; caller releases).
static void *witty_ct_font_copy_descriptor(void *font) {
	if (!font) return NULL;
	return (void *)CTFontCopyFontDescriptor((CTFontRef)font);
}

// ------------------------------------------------------------------
// Face helpers (CoreText backend).
// ------------------------------------------------------------------

#else
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

static void *witty_coretext_create_hb_font(void *font_ptr, double pixels) {
	(void)font_ptr;
	(void)pixels;
	return NULL;
}

static void witty_coretext_destroy_hb_font(void *font_ptr) {
	(void)font_ptr;
}

// --- Non-Apple stubs for discovery/face helpers. ---

static void witty_ct_release(void *ptr) { (void)ptr; }
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

static void *witty_ct_font_copy_descriptor(void *font) { (void)font; return NULL; }

#endif
