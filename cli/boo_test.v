module cli

fn test_boo_parser_state_source_layout_and_ordinals() {
	assert sizeof(BooParseState) == 1
	assert [BooParseState.normal, .span, .in_tag, .in_closing_tag].map(u8(it)) == [
		u8(0),
		1,
		2,
		3,
	]
}

fn test_boo_embeds_all_pinned_ghostty_frames() {
	frames := decompress_boo_frames()!
	assert frames.len == 235
	assert frames[0].contains('<span class="b">')
	for frame in frames {
		assert frame.split_into_lines().len == 41
		// Rendering validates all 4,100 cells after removing span markup.
		draw_boo_frame(frame, 100, 41)!
	}
}

fn test_boo_line_parser_preserves_cells_and_styles_spans() {
	styled, visible := style_boo_line('a<span class="b">b</span>c')
	assert visible == 3
	assert styled == 'a\x1b[34mb\x1b[39mc'
}

fn test_boo_draw_centers_frame_and_warns_for_small_screens() {
	frames := decompress_boo_frames()!
	drawn := draw_boo_frame(frames[0], 102, 43)!
	assert drawn.starts_with('\x1b[2J\x1b[H\x1b[2;2H')
	assert drawn.contains('\x1b[34m')
	warning := draw_boo_frame(frames[0], 80, 24)!
	assert warning.contains('Screen must be at least 100w x 41h')
}
