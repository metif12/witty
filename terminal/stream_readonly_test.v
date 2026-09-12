module terminal

// Tests for ReadonlyStream (stream_readonly.zig tests).

fn test_readonly_basic_print() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	s.next_slice('Hello') or { panic(err) }
	assert t.screens.active.cursor.x == 5
	assert t.screens.active.cursor.y == 0

	str := t.plain_string() or { panic(err) }
	assert str == 'Hello'
}

fn test_readonly_scalar_stream_surface() {
	mut term := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	defer { term.deinit() }
	mut stream := ReadonlyStream.init(mut term)
	defer { stream.deinit() }

	stream.next(u8(`A`))!
	stream.print(u32(`B`))!
	assert term.screens.active.cursor.x == 2
	assert (term.plain_string() or { panic(err) }) == 'AB'

	stream.execute(0x0d)!
	assert term.screens.active.cursor.x == 0
}

fn test_readonly_cursor_movement() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Move cursor using escape sequences
	s.next_slice('Hello\x1b[1;1H') or { panic(err) }
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0

	// Move to position 2,3
	s.next_slice('\x1b[2;3H') or { panic(err) }
	assert t.screens.active.cursor.x == 2
	assert t.screens.active.cursor.y == 1
}

fn test_readonly_erase_operations() {
	mut t := Terminal.init(Options{ cols: 20, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Print some text
	s.next_slice('Hello World') or { panic(err) }
	assert t.screens.active.cursor.x == 11
	assert t.screens.active.cursor.y == 0

	// Move cursor to position 1,6 and erase from cursor to end of line
	s.next_slice('\x1b[1;6H') or { panic(err) }
	s.next_slice('\x1b[K') or { panic(err) }

	str := t.plain_string() or { panic(err) }
	assert str == 'Hello'
}

fn test_readonly_tabs() {
	mut t := Terminal.init(Options{ cols: 80, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	s.next_slice('A\tB') or { panic(err) }
	assert t.screens.active.cursor.x == 9

	str := t.plain_string() or { panic(err) }
	assert str == 'A       B'
}

fn test_readonly_modes() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Test wraparound mode
	assert t.modes.get(.wraparound)
	s.next_slice('\x1b[?7l') or { panic(err) } // Disable wraparound
	assert !t.modes.get(.wraparound)
	s.next_slice('\x1b[?7h') or { panic(err) } // Enable wraparound
	assert t.modes.get(.wraparound)
}

fn test_readonly_scrolling_regions() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set scrolling region from line 5 to 20
	s.next_slice('\x1b[5;20r') or { panic(err) }
	assert t.scrolling_region.top == 4
	assert t.scrolling_region.bottom == 19
	assert t.scrolling_region.left == 0
	assert t.scrolling_region.right == 79
}

fn test_readonly_charsets() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Configure G0 as DEC special graphics
	s.next_slice('\x1b(0') or { panic(err) }
	s.next_slice('`') or { panic(err) } // Should print diamond character

	str := t.plain_string() or { panic(err) }
	assert str == '◆'
}

fn test_readonly_alt_screen() {
	mut t := Terminal.init(Options{ cols: 10, rows: 5 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Write to primary screen
	s.next_slice('Primary') or { panic(err) }
	assert t.screens.active_key == .primary

	// Switch to alt screen
	s.next_slice('\x1b[?1049h') or { panic(err) }
	assert t.screens.active_key == .alternate

	// Write to alt screen
	s.next_slice('Alt') or { panic(err) }

	// Switch back to primary
	s.next_slice('\x1b[?1049l') or { panic(err) }
	assert t.screens.active_key == .primary

	str := t.plain_string() or { panic(err) }
	assert str == 'Primary'
}

fn test_readonly_cursor_save_and_restore() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Move cursor to 10,15
	s.next_slice('\x1b[10;15H') or { panic(err) }
	assert t.screens.active.cursor.x == 14
	assert t.screens.active.cursor.y == 9

	// Save cursor
	s.next_slice('\x1b7') or { panic(err) }

	// Move cursor elsewhere
	s.next_slice('\x1b[1;1H') or { panic(err) }
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0

	// Restore cursor
	s.next_slice('\x1b8') or { panic(err) }
	assert t.screens.active.cursor.x == 14
	assert t.screens.active.cursor.y == 9
}

fn test_readonly_attributes() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set bold and write text
	s.next_slice('\x1b[1mBold\x1b[0m') or { panic(err) }

	// Verify we can write attributes - just check the string was written
	str := t.plain_string() or { panic(err) }
	assert str == 'Bold'
}

fn test_readonly_decaln_screen_alignment() {
	mut t := Terminal.init(Options{ cols: 10, rows: 3 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Run DECALN
	s.next_slice('\x1b#8') or { panic(err) }

	// Verify entire screen is filled with 'E'
	str := t.plain_string() or { panic(err) }
	assert str == 'EEEEEEEEEE\nEEEEEEEEEE\nEEEEEEEEEE'

	// Cursor should be at 1,1
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0
}

fn test_readonly_full_reset() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Make some changes
	s.next_slice('Hello') or { panic(err) }
	s.next_slice('\x1b[10;20H') or { panic(err) }
	s.next_slice('\x1b[5;20r') or { panic(err) } // Set scroll region
	s.next_slice('\x1b[?7l') or { panic(err) } // Disable wraparound

	// Full reset
	s.next_slice('\x1bc') or { panic(err) }

	// Verify reset state
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0
	assert t.scrolling_region.top == 0
	assert t.scrolling_region.bottom == 23
	assert t.modes.get(.wraparound)
}

fn test_readonly_ignores_query_actions() {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// These should be ignored without error
	s.next_slice('\x1b[c') or { panic(err) } // Device attributes
	s.next_slice('\x1b[5n') or { panic(err) } // Device status report
	s.next_slice('\x1b[6n') or { panic(err) } // Cursor position report

	// Terminal should still be functional
	s.next_slice('Test') or { panic(err) }
	str := t.plain_string() or { panic(err) }
	assert str == 'Test'
}

fn test_readonly_osc4_set_and_reset_palette() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Save default color
	default_color_0 := t.colors.palette.original[0]

	// Set color 0 to red
	s.next_slice('\x1b]4;0;rgb:ff/00/00\x1b\\') or { panic(err) }
	assert t.colors.palette.current[0].r == 0xff
	assert t.colors.palette.current[0].g == 0x00
	assert t.colors.palette.current[0].b == 0x00
	assert t.colors.palette.mask_is_set(0)

	// Reset color 0
	s.next_slice('\x1b]104;0\x1b\\') or { panic(err) }
	assert t.colors.palette.current[0] == default_color_0
	assert !t.colors.palette.mask_is_set(0)
}

fn test_readonly_osc104_reset_all_palette_colors() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set multiple colors
	s.next_slice('\x1b]4;0;rgb:ff/00/00\x1b\\') or { panic(err) }
	s.next_slice('\x1b]4;1;rgb:00/ff/00\x1b\\') or { panic(err) }
	s.next_slice('\x1b]4;2;rgb:00/00/ff\x1b\\') or { panic(err) }
	assert t.colors.palette.mask_is_set(0)
	assert t.colors.palette.mask_is_set(1)
	assert t.colors.palette.mask_is_set(2)

	// Reset all palette colors
	s.next_slice('\x1b]104\x1b\\') or { panic(err) }
	assert t.colors.palette.current[0] == t.colors.palette.original[0]
	assert t.colors.palette.current[1] == t.colors.palette.original[1]
	assert t.colors.palette.current[2] == t.colors.palette.original[2]
	assert !t.colors.palette.mask_is_set(0)
	assert !t.colors.palette.mask_is_set(1)
	assert !t.colors.palette.mask_is_set(2)
}

fn test_readonly_osc10_set_and_reset_foreground_color() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Initially unset
	assert t.colors.foreground.get() == none

	// Set foreground to red
	s.next_slice('\x1b]10;rgb:ff/00/00\x1b\\') or { panic(err) }
	fg := t.colors.foreground.get() or { panic('no foreground') }
	assert fg.r == 0xff
	assert fg.g == 0x00
	assert fg.b == 0x00

	// Reset foreground
	s.next_slice('\x1b]110\x1b\\') or { panic(err) }
	assert t.colors.foreground.get() == none
}

fn test_readonly_osc11_set_and_reset_background_color() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set background to green
	s.next_slice('\x1b]11;rgb:00/ff/00\x1b\\') or { panic(err) }
	bg := t.colors.background.get() or { panic('no background') }
	assert bg.r == 0x00
	assert bg.g == 0xff
	assert bg.b == 0x00

	// Reset background
	s.next_slice('\x1b]111\x1b\\') or { panic(err) }
	assert t.colors.background.get() == none
}

fn test_readonly_osc12_set_and_reset_cursor_color() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set cursor to blue
	s.next_slice('\x1b]12;rgb:00/00/ff\x1b\\') or { panic(err) }
	cursor := t.colors.cursor.get() or { panic('no cursor') }
	assert cursor.r == 0x00
	assert cursor.g == 0x00
	assert cursor.b == 0xff

	// Reset cursor
	s.next_slice('\x1b]112\x1b\\') or { panic(err) }
	// After reset, cursor might be null (using default)
}

fn test_readonly_kitty_color_protocol_set_palette() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set palette color 5 to magenta using kitty protocol
	s.next_slice('\x1b]21;5=rgb:ff/00/ff\x1b\\') or { panic(err) }
	assert t.colors.palette.current[5].r == 0xff
	assert t.colors.palette.current[5].g == 0x00
	assert t.colors.palette.current[5].b == 0xff
	assert t.colors.palette.mask_is_set(5)
	assert t.flags.dirty.palette
}

fn test_readonly_kitty_color_protocol_reset_palette() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set and then reset palette color
	original := t.colors.palette.original[7]
	s.next_slice('\x1b]21;7=rgb:aa/bb/cc\x1b\\') or { panic(err) }
	assert t.colors.palette.mask_is_set(7)

	s.next_slice('\x1b]21;7=\x1b\\') or { panic(err) }
	assert t.colors.palette.current[7] == original
	assert !t.colors.palette.mask_is_set(7)
}

fn test_readonly_kitty_color_protocol_set_foreground() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set foreground using kitty protocol
	s.next_slice('\x1b]21;foreground=rgb:12/34/56\x1b\\') or { panic(err) }
	fg := t.colors.foreground.get() or { panic('no foreground') }
	assert fg.r == 0x12
	assert fg.g == 0x34
	assert fg.b == 0x56
}

fn test_readonly_kitty_color_protocol_set_background() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set background using kitty protocol
	s.next_slice('\x1b]21;background=rgb:78/9a/bc\x1b\\') or { panic(err) }
	bg := t.colors.background.get() or { panic('no background') }
	assert bg.r == 0x78
	assert bg.g == 0x9a
	assert bg.b == 0xbc
}

fn test_readonly_kitty_color_protocol_set_cursor() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set cursor using kitty protocol
	s.next_slice('\x1b]21;cursor=rgb:de/f0/12\x1b\\') or { panic(err) }
	cursor := t.colors.cursor.get() or { panic('no cursor') }
	assert cursor.r == 0xde
	assert cursor.g == 0xf0
	assert cursor.b == 0x12
}

fn test_readonly_kitty_color_protocol_reset_foreground() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Set and reset foreground
	s.next_slice('\x1b]21;foreground=rgb:11/22/33\x1b\\') or { panic(err) }
	assert t.colors.foreground.get() != none

	s.next_slice('\x1b]21;foreground=\x1b\\') or { panic(err) }
	// After reset, should be unset
	assert t.colors.foreground.get() == none
}

fn test_readonly_palette_dirty_flag_set_on_color_change() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Clear dirty flag
	t.flags.dirty.palette = false

	// Setting palette color should set dirty flag
	s.next_slice('\x1b]4;0;rgb:ff/00/00\x1b\\') or { panic(err) }
	assert t.flags.dirty.palette

	// Clear and test reset
	t.flags.dirty.palette = false
	s.next_slice('\x1b]104;0\x1b\\') or { panic(err) }
	assert t.flags.dirty.palette

	// Clear and test kitty protocol
	t.flags.dirty.palette = false
	s.next_slice('\x1b]21;1=rgb:00/ff/00\x1b\\') or { panic(err) }
	assert t.flags.dirty.palette
}

fn test_readonly_semantic_prompt_end_of_input_then_start_output() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer {
		s.deinit()
	}

	// Write some text and then send OSC 133;A (fresh_line_new_prompt)
	s.next_slice('Hello') or { panic(err) }
	s.next_slice('\x1b]133;A\a') or { panic(err) }
	s.next_slice('prompt\$ ') or { panic(err) }
	s.next_slice('\x1b]133;B\a') or { panic(err) }
	assert t.screens.active.cursor.semantic_content == .input
	s.next_slice('\x1b]133;C\a') or { panic(err) }
	assert t.screens.active.cursor.semantic_content == .output
}

fn test_readonly_semantic_prompt_fresh_line() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }

	s.next_slice('Hello') or { panic(err) }
	s.next_slice('\x1b]133;L\a') or { panic(err) }
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 1
}

fn test_readonly_semantic_prompt_fresh_line_new_prompt() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }

	s.next_slice('Hello') or { panic(err) }
	s.next_slice('\x1b]133;A\a') or { panic(err) }
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 1
	assert t.screens.active.cursor.semantic_content == .prompt

	s.next_slice('prompt\$ ') or { panic(err) }
	s.next_slice('\x1b]133;A;redraw=1\a') or { panic(err) }
	assert t.flags.shell_redraws_prompt == .redraw_true
}

fn test_readonly_semantic_prompt_prompt_start() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }

	s.next_slice('Hello') or { panic(err) }
	s.next_slice('\x1b]133;P\a') or { panic(err) }
	assert t.screens.active.cursor.semantic_content == .prompt
	assert t.screens.active.cursor.x == 5
	assert t.screens.active.cursor.y == 0
}

fn test_readonly_semantic_prompt_new_command() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }

	s.next_slice('Hello') or { panic(err) }
	s.next_slice('\x1b]133;N\a') or { panic(err) }
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 1
	assert t.screens.active.cursor.semantic_content == .prompt
}

fn test_readonly_semantic_prompt_new_command_at_column_zero() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }

	s.next_slice('\x1b]133;N\a') or { panic(err) }
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0
	assert t.screens.active.cursor.semantic_content == .prompt
}

fn test_readonly_semantic_prompt_input_terminate_eol_clears_on_linefeed() {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 }) or { panic(err) }
	mut s := ReadonlyStream.init(mut t)
	defer { s.deinit() }

	s.next_slice('\x1b]133;I\a') or { panic(err) }
	assert t.screens.active.cursor.semantic_content == .input
	s.next_slice('\n') or { panic(err) }
	assert t.screens.active.cursor.semantic_content == .output
}
