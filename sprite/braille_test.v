module sprite

fn test_braille_pattern_packed_unicode_layout() {
	assert sizeof(BraillePattern) == 1
	first := braille_pattern_from(0x2801)
	assert first.tl()
	assert !first.ul()
	assert !first.br()

	last := braille_pattern_from(0x28ff)
	assert last.tl()
	assert last.ul()
	assert last.ll()
	assert last.tr()
	assert last.ur()
	assert last.lr()
	assert last.bl()
	assert last.br()
}
