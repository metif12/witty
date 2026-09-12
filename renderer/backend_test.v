module renderer

fn test_backend_storage_and_default() {
	assert sizeof(Backend) == 1
	$if wasm32 {
		assert Backend.default_() == .webgl
	} $else $if macos || ios {
		assert Backend.default_() == .metal
	} $else {
		assert Backend.default_() == .opengl
	}
}
