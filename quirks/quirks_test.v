module quirks

struct TestFace {}

fn test_disable_default_font_features() {
	face := TestFace{}
	assert !disable_default_font_features(&face)
}

fn test_inline_assert() {
	inline_assert(true)
}
