module terminal

// Tests for mouse_shape.v (translated from mouse_shape.zig)

// cursor shape from string (translated from Zig test "cursor shape from string")
fn test_cursor_shape_from_string() {
	result := FullMouseShape.from_string('default') or { panic('expected value') }
	assert result == FullMouseShape.default_
}

fn test_cursor_shape_from_string_w3c() {
	assert FullMouseShape.from_string('pointer') or { panic('expected value') } == .pointer
	assert FullMouseShape.from_string('help') or { panic('expected value') } == .help
	assert FullMouseShape.from_string('wait') or { panic('expected value') } == .wait
	assert FullMouseShape.from_string('crosshair') or { panic('expected value') } == .crosshair
	assert FullMouseShape.from_string('text') or { panic('expected value') } == .text
	assert FullMouseShape.from_string('move') or { panic('expected value') } == .move
	assert FullMouseShape.from_string('zoom-in') or { panic('expected value') } == .zoom_in
	assert FullMouseShape.from_string('zoom-out') or { panic('expected value') } == .zoom_out
}

fn test_cursor_shape_from_string_xterm() {
	// xterm/foot aliases
	assert FullMouseShape.from_string('left_ptr') or { panic('expected value') } == .default_
	assert FullMouseShape.from_string('hand') or { panic('expected value') } == .pointer
	assert FullMouseShape.from_string('xterm') or { panic('expected value') } == .text
	assert FullMouseShape.from_string('hand1') or { panic('expected value') } == .grab
	assert FullMouseShape.from_string('fleur') or { panic('expected value') } == .all_scroll
	assert FullMouseShape.from_string('crossed_circle') or { panic('expected value') } == .not_allowed
}

fn test_cursor_shape_from_string_unknown() {
	assert FullMouseShape.from_string('nonexistent') == none
	assert FullMouseShape.from_string('') == none
	assert FullMouseShape.from_string('DEFAULT') == none
}

fn test_cursor_shape_resize_variants() {
	assert FullMouseShape.from_string('n-resize') or { panic('expected value') } == .n_resize
	assert FullMouseShape.from_string('e-resize') or { panic('expected value') } == .e_resize
	assert FullMouseShape.from_string('s-resize') or { panic('expected value') } == .s_resize
	assert FullMouseShape.from_string('w-resize') or { panic('expected value') } == .w_resize
	assert FullMouseShape.from_string('ne-resize') or { panic('expected value') } == .ne_resize
	assert FullMouseShape.from_string('nw-resize') or { panic('expected value') } == .nw_resize
	assert FullMouseShape.from_string('se-resize') or { panic('expected value') } == .se_resize
	assert FullMouseShape.from_string('sw-resize') or { panic('expected value') } == .sw_resize
	assert FullMouseShape.from_string('ew-resize') or { panic('expected value') } == .ew_resize
	assert FullMouseShape.from_string('ns-resize') or { panic('expected value') } == .ns_resize
	assert FullMouseShape.from_string('nesw-resize') or { panic('expected value') } == .nesw_resize
	assert FullMouseShape.from_string('nwse-resize') or { panic('expected value') } == .nwse_resize
}

fn test_cursor_shape_xterm_resize_aliases() {
	assert FullMouseShape.from_string('right_side') or { panic('expected value') } == .e_resize
	assert FullMouseShape.from_string('top_side') or { panic('expected value') } == .n_resize
	assert FullMouseShape.from_string('top_right_corner') or { panic('expected value') } == .ne_resize
	assert FullMouseShape.from_string('top_left_corner') or { panic('expected value') } == .nw_resize
	assert FullMouseShape.from_string('bottom_side') or { panic('expected value') } == .s_resize
	assert FullMouseShape.from_string('bottom_right_corner') or { panic('expected value') } == .se_resize
	assert FullMouseShape.from_string('bottom_left_corner') or { panic('expected value') } == .sw_resize
	assert FullMouseShape.from_string('left_side') or { panic('expected value') } == .w_resize
}
