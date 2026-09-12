module quirks

// disable_default_font_features reports whether default font features should
// be disabled for face. The current source has no active font quirks.
pub fn disable_default_font_features[T](face &T) bool {
	_ = face
	return false
}

// inline_assert is Ghostty's inlined assertion helper. V's assert is a
// compiler primitive and provides the corresponding build-mode behavior.
@[inline]
pub fn inline_assert(ok bool) {
	assert ok
}
