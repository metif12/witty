module font

fn test_backend_storage_and_default() {
	assert sizeof(Backend) == 1
	$if macos {
		assert Backend.default_() == .coretext
	} $else $if wasm32 {
		assert Backend.default_() == .web_canvas
	} $else {
		assert Backend.default_() == .fontconfig_freetype
	}
}

fn test_backend_feature_queries() {
	assert Backend.freetype.has_freetype()
	assert !Backend.freetype.has_fontconfig()
	assert Backend.fontconfig_freetype.has_fontconfig()
	assert Backend.coretext.has_coretext()
	assert !Backend.coretext.has_harfbuzz()
	assert Backend.coretext_harfbuzz.has_harfbuzz()
	assert !Backend.web_canvas.has_coretext()
}
