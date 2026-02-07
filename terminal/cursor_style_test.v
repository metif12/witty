module terminal

// Tests for cursor_style.v (translated from cursor.zig)

fn test_cursor_visual_style_values() {
	assert CursorVisualStyle.bar != CursorVisualStyle.block
	assert CursorVisualStyle.block != CursorVisualStyle.underline
	assert CursorVisualStyle.underline != CursorVisualStyle.block_hollow
}

fn test_cursor_visual_style_match() {
	style := CursorVisualStyle.block_hollow
	result := match style {
		.bar { 'bar' }
		.block { 'block' }
		.underline { 'underline' }
		.block_hollow { 'block_hollow' }
	}
	assert result == 'block_hollow'
}
