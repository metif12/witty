module font

fn test_glyph_matches_source_field_layout() {
	assert sizeof(Glyph) == 24
	assert __offsetof(Glyph, width) == 0
	assert __offsetof(Glyph, height) == 4
	assert __offsetof(Glyph, offset_x) == 8
	assert __offsetof(Glyph, offset_y) == 12
	assert __offsetof(Glyph, atlas_x) == 16
	assert __offsetof(Glyph, atlas_y) == 20
}
