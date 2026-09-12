module terminal

// Tests for mouse_shape.v (translated from mouse_shape.zig)

// cursor shape from string (translated from Zig test "cursor shape from string")
fn test_cursor_shape_from_string() {
	result := MouseShape.from_string('default') or { panic('expected value') }
	assert result == MouseShape.default_
}

fn test_mouse_shape_source_layout_and_ordinals() {
	assert sizeof(MouseShape) == 4
	assert int(MouseShape.default_) == 0
	assert int(MouseShape.context_menu) == 1
	assert int(MouseShape.pointer) == 3
	assert int(MouseShape.all_scroll) == 17
	assert int(MouseShape.zoom_out) == 33
}

fn test_cursor_shape_from_string_w3c() {
	assert MouseShape.from_string('pointer') or { panic('expected value') } == .pointer
	assert MouseShape.from_string('help') or { panic('expected value') } == .help
	assert MouseShape.from_string('wait') or { panic('expected value') } == .wait
	assert MouseShape.from_string('crosshair') or { panic('expected value') } == .crosshair
	assert MouseShape.from_string('text') or { panic('expected value') } == .text
	assert MouseShape.from_string('move') or { panic('expected value') } == .move
	assert MouseShape.from_string('zoom-in') or { panic('expected value') } == .zoom_in
	assert MouseShape.from_string('zoom-out') or { panic('expected value') } == .zoom_out
}

fn test_cursor_shape_from_string_xterm() {
	// xterm/foot aliases
	assert MouseShape.from_string('left_ptr') or { panic('expected value') } == .default_
	assert MouseShape.from_string('hand') or { panic('expected value') } == .pointer
	assert MouseShape.from_string('xterm') or { panic('expected value') } == .text
	assert MouseShape.from_string('hand1') or { panic('expected value') } == .grab
	assert MouseShape.from_string('fleur') or { panic('expected value') } == .all_scroll
	assert MouseShape.from_string('crossed_circle') or { panic('expected value') } == .not_allowed
}

fn test_cursor_shape_from_string_unknown() {
	assert MouseShape.from_string('nonexistent') == none
	assert MouseShape.from_string('') == none
	assert MouseShape.from_string('DEFAULT') == none
}

fn test_cursor_shape_resize_variants() {
	assert MouseShape.from_string('n-resize') or { panic('expected value') } == .n_resize
	assert MouseShape.from_string('e-resize') or { panic('expected value') } == .e_resize
	assert MouseShape.from_string('s-resize') or { panic('expected value') } == .s_resize
	assert MouseShape.from_string('w-resize') or { panic('expected value') } == .w_resize
	assert MouseShape.from_string('ne-resize') or { panic('expected value') } == .ne_resize
	assert MouseShape.from_string('nw-resize') or { panic('expected value') } == .nw_resize
	assert MouseShape.from_string('se-resize') or { panic('expected value') } == .se_resize
	assert MouseShape.from_string('sw-resize') or { panic('expected value') } == .sw_resize
	assert MouseShape.from_string('ew-resize') or { panic('expected value') } == .ew_resize
	assert MouseShape.from_string('ns-resize') or { panic('expected value') } == .ns_resize
	assert MouseShape.from_string('nesw-resize') or { panic('expected value') } == .nesw_resize
	assert MouseShape.from_string('nwse-resize') or { panic('expected value') } == .nwse_resize
}

fn test_cursor_shape_xterm_resize_aliases() {
	assert MouseShape.from_string('right_side') or { panic('expected value') } == .e_resize
	assert MouseShape.from_string('top_side') or { panic('expected value') } == .n_resize
	assert MouseShape.from_string('top_right_corner') or { panic('expected value') } == .ne_resize
	assert MouseShape.from_string('top_left_corner') or { panic('expected value') } == .nw_resize
	assert MouseShape.from_string('bottom_side') or { panic('expected value') } == .s_resize
	assert MouseShape.from_string('bottom_right_corner') or { panic('expected value') } == .se_resize
	assert MouseShape.from_string('bottom_left_corner') or { panic('expected value') } == .sw_resize
	assert MouseShape.from_string('left_side') or { panic('expected value') } == .w_resize
}
