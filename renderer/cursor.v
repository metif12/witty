module renderer

import terminal

// Available cursor styles for drawing that renderers must support.
pub enum Style as u8 {
	block
	block_hollow
	bar
	underline
	lock
}

// StyleOptions contains the options used to determine cursor visibility
// and style during rendering.
pub struct StyleOptions {
pub:
	// Whether we are in preedit (IME composition) mode.
	preedit bool
	// Whether the terminal window is focused.
	focused bool
	// Whether the cursor blink state is currently visible.
	blink_visible bool
}

// Returns the cursor style to use for the current render state or none
// if a cursor should not be rendered at all.
//
// Note the order of conditionals is important. It represents
// a priority system of how we determine what state overrides cursor
// visibility and style.
pub fn style(state &terminal.RenderState, opts StyleOptions) ?Style {
	// The cursor must be visible in the viewport to be rendered.
	if _ := state.cursor.viewport {
		// viewport is set, continue
	} else {
		return none
	}

	// If we are in preedit, then we always show the block cursor. We do
	// this even if the cursor is explicitly not visible because it shows
	// an important editing state to the user.
	if opts.preedit {
		return .block
	}

	// If we're at a password input its always a lock.
	if state.cursor.password_input {
		return .lock
	}

	// If the cursor is explicitly not visible by terminal mode, we don't render.
	if !state.cursor.visible {
		return none
	}

	// If we're not focused, our cursor is always visible so that
	// we can show the hollow box.
	if !opts.focused {
		return .block_hollow
	}

	// If the cursor is blinking and our blink state is not visible,
	// then we don't show the cursor.
	if state.cursor.blinking && !opts.blink_visible {
		return none
	}

	// Otherwise, we use whatever style the terminal wants.
	return Style.from_terminal(state.cursor.visual_style)
}

// Create a cursor style from the terminal style request.
pub fn Style.from_terminal(term terminal.CursorStyle) ?Style {
	return match term {
		.bar { .bar }
		.block { .block }
		.block_hollow { .block_hollow }
		.underline { .underline }
	}
}
