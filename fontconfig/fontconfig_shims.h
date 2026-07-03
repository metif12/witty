#include <fontconfig/fontconfig.h>

// Read the `nfont` and `fonts` fields out of the opaque FcFontSet so that
// the V side doesn't have to mirror the C struct layout.
static int vt_fontconfig_fontset_nfont(void *fs) {
	if (!fs) return 0;
	return ((FcFontSet *)fs)->nfont;
}

static void *vt_fontconfig_fontset_font(void *fs, int idx) {
	if (!fs) return 0;
	FcFontSet *set = (FcFontSet *)fs;
	if (idx < 0 || idx >= set->nfont) return 0;
	return (void *)set->fonts[idx];
}
