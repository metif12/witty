module font

// Backend represents the font backend to use for font rendering, discovery,
// and shaping. Different backends support different features and platforms.
//
// Translated from ghostty/src/font/backend.zig

pub enum Backend as u8 {
	// FreeType for font rendering with no font discovery enabled.
	freetype

	// Fontconfig for font discovery and FreeType for font rendering.
	fontconfig_freetype

	// CoreText for font discovery, rendering, and shaping (macOS).
	coretext

	// CoreText for font discovery, FreeType for rendering, and
	// HarfBuzz for shaping (macOS).
	coretext_freetype

	// CoreText for font discovery and rendering, HarfBuzz for shaping
	coretext_harfbuzz

	// CoreText for font discovery and rendering, no shaping.
	coretext_noshape

	// Use the browser font system and the Canvas API (wasm). This limits
	// the available fonts to browser fonts (anything Canvas natively
	// supports).
	web_canvas
}

// Returns the default backend for the current platform.
// On macOS, defaults to coretext. On Linux, defaults to fontconfig_freetype.
// On wasm, defaults to web_canvas.
//
// Note: In Zig this is a comptime function taking std.Target and WasmTarget.
// In V we simplify to a runtime function since we don't have comptime.
pub fn Backend.default_() Backend {
	// macOS also supports "coretext_freetype" but there is no scenario
	// that is the default. It is only used by people who want to
	// self-compile Ghostty and prefer the freetype aesthetic.
	$if macos || ios {
		return .coretext
	} $else $if wasm32 {
		return .web_canvas
	} $else {
		return .fontconfig_freetype
	}
}

// All the functions below can be called at comptime or runtime to
// determine if we have a certain dependency.

// has_freetype returns true if this backend uses FreeType for rendering.
pub fn (b Backend) has_freetype() bool {
	return match b {
		.freetype, .fontconfig_freetype, .coretext_freetype {
			true
		}
		.coretext, .coretext_harfbuzz, .coretext_noshape, .web_canvas {
			false
		}
	}
}

// has_coretext returns true if this backend uses CoreText.
pub fn (b Backend) has_coretext() bool {
	return match b {
		.coretext, .coretext_freetype, .coretext_harfbuzz, .coretext_noshape {
			true
		}
		.freetype, .fontconfig_freetype, .web_canvas {
			false
		}
	}
}

// has_fontconfig returns true if this backend uses Fontconfig for discovery.
pub fn (b Backend) has_fontconfig() bool {
	return match b {
		.fontconfig_freetype {
			true
		}
		.freetype, .coretext, .coretext_freetype, .coretext_harfbuzz, .coretext_noshape,
		.web_canvas {
			false
		}
	}
}

// has_harfbuzz returns true if this backend uses HarfBuzz for shaping.
pub fn (b Backend) has_harfbuzz() bool {
	return match b {
		.freetype, .fontconfig_freetype, .coretext_freetype, .coretext_harfbuzz {
			true
		}
		.coretext, .coretext_noshape, .web_canvas {
			false
		}
	}
}

// Source build options select one renderer/discovery/shaper combination. The
// V build exposes the same alternatives through -d font_backend_<backend>.
pub fn Backend.selected_() Backend {
	$if font_backend_freetype ? { return .freetype }
	$if font_backend_fontconfig_freetype ? { return .fontconfig_freetype }
	$if font_backend_coretext ? { return .coretext }
	$if font_backend_coretext_freetype ? { return .coretext_freetype }
	$if font_backend_coretext_harfbuzz ? { return .coretext_harfbuzz }
	$if font_backend_coretext_noshape ? { return .coretext_noshape }
	$if font_backend_web_canvas ? { return .web_canvas }
	return Backend.default_()
}
