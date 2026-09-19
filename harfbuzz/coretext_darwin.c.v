module harfbuzz

#flag darwin -I/opt/homebrew/include
#flag darwin -L/opt/homebrew/lib
#flag darwin -lharfbuzz
#flag darwin -framework CoreText

#include <harfbuzz/hb-coretext.h>

fn C.hb_coretext_font_create(ct_font voidptr) &C.hb_font_t

// create_coretext creates a HarfBuzz font from a CTFontRef.
pub fn Font.create_coretext(ct_font voidptr) !Font {
	if isnil(ct_font) {
		return error('cannot create HarfBuzz font from a null CoreText font')
	}
	fnt := C.hb_coretext_font_create(ct_font)
	if fnt == unsafe { nil } {
		return error('failed to create HarfBuzz CoreText font')
	}
	return Font{
		ptr: fnt
	}
}
