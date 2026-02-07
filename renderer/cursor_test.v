module renderer

import terminal

// ============================================================
// Cursor tests - translated from cursor.zig
// ============================================================

// Test CursorStyle.from_terminal conversion.
fn test_cursor_style_from_terminal_bar() {
	result := CursorStyle.from_terminal(.bar) or {
		assert false
		return
	}
	assert result == .bar
}

fn test_cursor_style_from_terminal_block() {
	result := CursorStyle.from_terminal(.block) or {
		assert false
		return
	}
	assert result == .block
}

fn test_cursor_style_from_terminal_underline() {
	result := CursorStyle.from_terminal(.underline) or {
		assert false
		return
	}
	assert result == .underline
}

fn test_cursor_style_from_terminal_block_hollow() {
	result := CursorStyle.from_terminal(.block_hollow) or {
		assert false
		return
	}
	assert result == .block_hollow
}

// Test cursor_style: cursor not in viewport returns none.
fn test_cursor_style_not_in_viewport() {
	state := terminal.RenderState{}
	// viewport is none by default
	result := cursor_style(&state, StyleOptions{
		preedit: false
		focused: true
		blink_visible: true
	})
	assert result == none
}

// Test cursor_style: preedit always returns block (when viewport is set).
fn test_cursor_style_preedit_block() {
	state := terminal.RenderState{
		cursor: terminal.RenderCursor{
			viewport: terminal.ViewportPoint{x: 0, y: 0}
		}
	}
	result := cursor_style(&state, StyleOptions{
		preedit: true
		focused: false
		blink_visible: false
	})
	assert result != none
	if r := result {
		assert r == .block
	}
}

// Test cursor_style: password input returns lock.
fn test_cursor_style_password_lock() {
	state := terminal.RenderState{
		cursor: terminal.RenderCursor{
			viewport: terminal.ViewportPoint{x: 0, y: 0}
			password_input: true
		}
	}
	result := cursor_style(&state, StyleOptions{
		preedit: false
		focused: true
		blink_visible: true
	})
	assert result != none
	if r := result {
		assert r == .lock
	}
}

// Test cursor_style: not visible returns none.
fn test_cursor_style_not_visible() {
	state := terminal.RenderState{
		cursor: terminal.RenderCursor{
			viewport: terminal.ViewportPoint{x: 0, y: 0}
			visible: false
		}
	}
	result := cursor_style(&state, StyleOptions{
		preedit: false
		focused: true
		blink_visible: true
	})
	assert result == none
}

// Test cursor_style: not focused returns block_hollow.
fn test_cursor_style_not_focused() {
	state := terminal.RenderState{
		cursor: terminal.RenderCursor{
			viewport: terminal.ViewportPoint{x: 0, y: 0}
			visible: true
			visual_style: .bar
		}
	}
	result := cursor_style(&state, StyleOptions{
		preedit: false
		focused: false
		blink_visible: true
	})
	assert result != none
	if r := result {
		assert r == .block_hollow
	}
}

// Test cursor_style: blinking and blink not visible returns none.
fn test_cursor_style_blinking_not_visible() {
	state := terminal.RenderState{
		cursor: terminal.RenderCursor{
			viewport: terminal.ViewportPoint{x: 0, y: 0}
			visible: true
			blinking: true
			visual_style: .bar
		}
	}
	result := cursor_style(&state, StyleOptions{
		preedit: false
		focused: true
		blink_visible: false
	})
	assert result == none
}

// Test cursor_style: normal case returns visual_style.
fn test_cursor_style_normal_case() {
	state := terminal.RenderState{
		cursor: terminal.RenderCursor{
			viewport: terminal.ViewportPoint{x: 0, y: 0}
			visible: true
			visual_style: .bar
		}
	}
	result := cursor_style(&state, StyleOptions{
		preedit: false
		focused: true
		blink_visible: true
	})
	assert result != none
	if r := result {
		assert r == .bar
	}
}
