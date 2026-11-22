module harfbuzz

$if macos || ios {
	$if managed_native ? {
		#flag -I@VMODROOT/.witty-build/include
	} $else {
		#flag -I/opt/homebrew/include
		#flag -L/opt/homebrew/lib
		#flag -lharfbuzz
	}
	#flag -framework CoreText

	#include "@VMODROOT/harfbuzz/coretext_native.h"

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
}
