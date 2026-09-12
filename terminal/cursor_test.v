module terminal

// Tests for cursor.v (translated from cursor.zig)

fn test_cursor_style_values() {
	assert sizeof(CursorStyle) == 1
	assert int(CursorStyle.bar) == 0
	assert int(CursorStyle.block) == 1
	assert int(CursorStyle.underline) == 2
	assert int(CursorStyle.block_hollow) == 3
}

fn test_cursor_style_match() {
	style := CursorStyle.block_hollow
	result := match style {
		.bar { 'bar' }
		.block { 'block' }
		.underline { 'underline' }
		.block_hollow { 'block_hollow' }
	}
	assert result == 'block_hollow'
}
