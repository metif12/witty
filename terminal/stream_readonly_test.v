module terminal

// Tests for ReadonlyStream (stream_readonly.zig tests).

fn test_basic_print() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	s.next_slice('Hello'.bytes())!
	assert t.screens.active.cursor.x == 5
	assert t.screens.active.cursor.y == 0

	str := t.plain_string()!
	assert str == 'Hello'
}

fn test_cursor_movement() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Move cursor using escape sequences
	s.next_slice('Hello\x1b[1;1H'.bytes())!
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0

	// Move to position 2,3
	s.next_slice('\x1b[2;3H'.bytes())!
	assert t.screens.active.cursor.x == 2
	assert t.screens.active.cursor.y == 1
}

fn test_erase_operations() ! {
	mut t := Terminal.init(Options{ cols: 20, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Print some text
	s.next_slice('Hello World'.bytes())!
	assert t.screens.active.cursor.x == 11
	assert t.screens.active.cursor.y == 0

	// Move cursor to position 1,6 and erase from cursor to end of line
	s.next_slice('\x1b[1;6H'.bytes())!
	s.next_slice('\x1b[K'.bytes())!

	str := t.plain_string()!
	assert str == 'Hello'
}

fn test_tabs() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	s.next_slice('A\tB'.bytes())!
	assert t.screens.active.cursor.x == 9

	str := t.plain_string()!
	assert str == 'A       B'
}

fn test_modes() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Test wraparound mode
	assert t.modes.get(.wraparound)
	s.next_slice('\x1b[?7l'.bytes())! // Disable wraparound
	assert !t.modes.get(.wraparound)
	s.next_slice('\x1b[?7h'.bytes())! // Enable wraparound
	assert t.modes.get(.wraparound)
}

fn test_scrolling_regions() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set scrolling region from line 5 to 20
	s.next_slice('\x1b[5;20r'.bytes())!
	assert t.scrolling_region.top == 4
	assert t.scrolling_region.bottom == 19
	assert t.scrolling_region.left == 0
	assert t.scrolling_region.right == 79
}

fn test_charsets() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Configure G0 as DEC special graphics
	s.next_slice('\x1b(0'.bytes())!
	s.next_slice('`'.bytes())! // Should print diamond character

	str := t.plain_string()!
	assert str == '◆'
}

fn test_alt_screen() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 5 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Write to primary screen
	s.next_slice('Primary'.bytes())!
	assert t.screens.active_key == .primary

	// Switch to alt screen
	s.next_slice('\x1b[?1049h'.bytes())!
	assert t.screens.active_key == .alternate

	// Write to alt screen
	s.next_slice('Alt'.bytes())!

	// Switch back to primary
	s.next_slice('\x1b[?1049l'.bytes())!
	assert t.screens.active_key == .primary

	str := t.plain_string()!
	assert str == 'Primary'
}

fn test_cursor_save_and_restore() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Move cursor to 10,15
	s.next_slice('\x1b[10;15H'.bytes())!
	assert t.screens.active.cursor.x == 14
	assert t.screens.active.cursor.y == 9

	// Save cursor
	s.next_slice('\x1b7'.bytes())!

	// Move cursor elsewhere
	s.next_slice('\x1b[1;1H'.bytes())!
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0

	// Restore cursor
	s.next_slice('\x1b8'.bytes())!
	assert t.screens.active.cursor.x == 14
	assert t.screens.active.cursor.y == 9
}

fn test_attributes() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set bold and write text
	s.next_slice('\x1b[1mBold\x1b[0m'.bytes())!

	// Verify we can write attributes - just check the string was written
	str := t.plain_string()!
	assert str == 'Bold'
}

fn test_decaln_screen_alignment() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 3 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Run DECALN
	s.next_slice('\x1b#8'.bytes())!

	// Verify entire screen is filled with 'E'
	str := t.plain_string()!
	assert str == 'EEEEEEEEEE\nEEEEEEEEEE\nEEEEEEEEEE'

	// Cursor should be at 1,1
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0
}

fn test_full_reset() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Make some changes
	s.next_slice('Hello'.bytes())!
	s.next_slice('\x1b[10;20H'.bytes())!
	s.next_slice('\x1b[5;20r'.bytes())! // Set scroll region
	s.next_slice('\x1b[?7l'.bytes())! // Disable wraparound

	// Full reset
	s.next_slice('\x1bc'.bytes())!

	// Verify reset state
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0
	assert t.scrolling_region.top == 0
	assert t.scrolling_region.bottom == 23
	assert t.modes.get(.wraparound)
}

fn test_ignores_query_actions() ! {
	mut t := Terminal.init(Options{ cols: 80, rows: 24 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// These should be ignored without error
	s.next_slice('\x1b[c'.bytes())! // Device attributes
	s.next_slice('\x1b[5n'.bytes())! // Device status report
	s.next_slice('\x1b[6n'.bytes())! // Cursor position report

	// Terminal should still be functional
	s.next_slice('Test'.bytes())!
	str := t.plain_string()!
	assert str == 'Test'
}

fn test_osc_4_set_and_reset_palette() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Save default color
	default_color_0 := t.colors.palette.original[0]

	// Set color 0 to red
	s.next_slice('\x1b]4;0;rgb:ff/00/00\x1b\\'.bytes())!
	assert t.colors.palette.current[0].r == u8(0xff)
	assert t.colors.palette.current[0].g == u8(0x00)
	assert t.colors.palette.current[0].b == u8(0x00)
	assert t.colors.palette.mask_is_set(0)

	// Reset color 0
	s.next_slice('\x1b]104;0\x1b\\'.bytes())!
	assert t.colors.palette.current[0] == default_color_0
	assert !t.colors.palette.mask_is_set(0)
}

fn test_osc_104_reset_all_palette_colors() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set multiple colors
	s.next_slice('\x1b]4;0;rgb:ff/00/00\x1b\\'.bytes())!
	s.next_slice('\x1b]4;1;rgb:00/ff/00\x1b\\'.bytes())!
	s.next_slice('\x1b]4;2;rgb:00/00/ff\x1b\\'.bytes())!
	assert t.colors.palette.mask_is_set(0)
	assert t.colors.palette.mask_is_set(1)
	assert t.colors.palette.mask_is_set(2)

	// Reset all palette colors
	s.next_slice('\x1b]104\x1b\\'.bytes())!
	assert t.colors.palette.current[0] == t.colors.palette.original[0]
	assert t.colors.palette.current[1] == t.colors.palette.original[1]
	assert t.colors.palette.current[2] == t.colors.palette.original[2]
	assert !t.colors.palette.mask_is_set(0)
	assert !t.colors.palette.mask_is_set(1)
	assert !t.colors.palette.mask_is_set(2)
}

fn test_osc_10_set_and_reset_foreground_color() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Initially unset
	assert t.colors.foreground.get() == none

	// Set foreground to red
	s.next_slice('\x1b]10;rgb:ff/00/00\x1b\\'.bytes())!
	fg := t.colors.foreground.get() or { panic('foreground is null') }
	assert fg.r == u8(0xff)
	assert fg.g == u8(0x00)
	assert fg.b == u8(0x00)

	// Reset foreground
	s.next_slice('\x1b]110\x1b\\'.bytes())!
	assert t.colors.foreground.get() == none
}

fn test_osc_11_set_and_reset_background_color() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set background to green
	s.next_slice('\x1b]11;rgb:00/ff/00\x1b\\'.bytes())!
	bg := t.colors.background.get() or { panic('background is null') }
	assert bg.r == u8(0x00)
	assert bg.g == u8(0xff)
	assert bg.b == u8(0x00)

	// Reset background
	s.next_slice('\x1b]111\x1b\\'.bytes())!
	assert t.colors.background.get() == none
}

fn test_osc_12_set_and_reset_cursor_color() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set cursor to blue
	s.next_slice('\x1b]12;rgb:00/00/ff\x1b\\'.bytes())!
	cursor := t.colors.cursor.get() or { panic('cursor is null') }
	assert cursor.r == u8(0x00)
	assert cursor.g == u8(0x00)
	assert cursor.b == u8(0xff)

	// Reset cursor
	s.next_slice('\x1b]112\x1b\\'.bytes())!
	// After reset, cursor might be null (using default)
}

fn test_kitty_color_protocol_set_palette() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set palette color 5 to magenta using kitty protocol
	s.next_slice('\x1b]21;5=rgb:ff/00/ff\x1b\\'.bytes())!
	assert t.colors.palette.current[5].r == u8(0xff)
	assert t.colors.palette.current[5].g == u8(0x00)
	assert t.colors.palette.current[5].b == u8(0xff)
	assert t.colors.palette.mask_is_set(5)
	assert t.flags.dirty().palette()
}

fn test_kitty_color_protocol_reset_palette() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set and then reset palette color
	original := t.colors.palette.original[7]
	s.next_slice('\x1b]21;7=rgb:aa/bb/cc\x1b\\'.bytes())!
	assert t.colors.palette.mask_is_set(7)

	s.next_slice('\x1b]21;7=\x1b\\'.bytes())!
	assert t.colors.palette.current[7] == original
	assert !t.colors.palette.mask_is_set(7)
}

fn test_kitty_color_protocol_set_foreground() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set foreground using kitty protocol
	s.next_slice('\x1b]21;foreground=rgb:12/34/56\x1b\\'.bytes())!
	fg := t.colors.foreground.get() or { panic('foreground is null') }
	assert fg.r == u8(0x12)
	assert fg.g == u8(0x34)
	assert fg.b == u8(0x56)
}

fn test_kitty_color_protocol_set_background() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set background using kitty protocol
	s.next_slice('\x1b]21;background=rgb:78/9a/bc\x1b\\'.bytes())!
	bg := t.colors.background.get() or { panic('background is null') }
	assert bg.r == u8(0x78)
	assert bg.g == u8(0x9a)
	assert bg.b == u8(0xbc)
}

fn test_kitty_color_protocol_set_cursor() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set cursor using kitty protocol
	s.next_slice('\x1b]21;cursor=rgb:de/f0/12\x1b\\'.bytes())!
	cursor := t.colors.cursor.get() or { panic('cursor is null') }
	assert cursor.r == u8(0xde)
	assert cursor.g == u8(0xf0)
	assert cursor.b == u8(0x12)
}

fn test_kitty_color_protocol_reset_foreground() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set and reset foreground
	s.next_slice('\x1b]21;foreground=rgb:11/22/33\x1b\\'.bytes())!
	assert t.colors.foreground.get() != none

	s.next_slice('\x1b]21;foreground=\x1b\\'.bytes())!
	// After reset, should be unset
	assert t.colors.foreground.get() == none
}

fn test_palette_dirty_flag_set_on_color_change() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Clear dirty flag
	t.flags.set_dirty_palette(false)

	// Setting palette color should set dirty flag
	s.next_slice('\x1b]4;0;rgb:ff/00/00\x1b\\'.bytes())!
	assert t.flags.dirty().palette()

	// Clear and test reset
	t.flags.set_dirty_palette(false)
	s.next_slice('\x1b]104;0\x1b\\'.bytes())!
	assert t.flags.dirty().palette()

	// Clear and test kitty protocol
	t.flags.set_dirty_palette(false)
	s.next_slice('\x1b]21;1=rgb:00/ff/00\x1b\\'.bytes())!
	assert t.flags.dirty().palette()
}

fn test_semantic_prompt_fresh_line() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	s.next_slice('Hello'.bytes())!
	s.next_slice('\x1b]133;L\x07'.bytes())!
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 1
}

fn test_semantic_prompt_fresh_line_new_prompt() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Write some text and then send OSC 133;A (fresh_line_new_prompt)
	s.next_slice('Hello'.bytes())!
	s.next_slice('\x1b]133;A\x07'.bytes())!

	// Should do a fresh line (carriage return + index)
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 1

	// Should set cursor semantic_content to prompt
	assert t.screens.active.cursor.semantic_content == .prompt

	// Test with redraw option
	s.next_slice('prompt\$ '.bytes())!
	s.next_slice('\x1b]133;A;redraw=1\x07'.bytes())!
	assert t.flags.shell_redraws_prompt() == .redraw_true
}

fn test_semantic_prompt_end_of_input_then_start_output() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Write some text and then send OSC 133;A (fresh_line_new_prompt)
	s.next_slice('Hello'.bytes())!
	s.next_slice('\x1b]133;A\x07'.bytes())!
	s.next_slice('prompt\$ '.bytes())!
	s.next_slice('\x1b]133;B\x07'.bytes())!
	assert t.screens.active.cursor.semantic_content == .input
	s.next_slice('\x1b]133;C\x07'.bytes())!
	assert t.screens.active.cursor.semantic_content == .output
}

fn test_semantic_prompt_prompt_start() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Write some text
	s.next_slice('Hello'.bytes())!

	// OSC 133;P marks the start of a prompt (without fresh line behavior)
	s.next_slice('\x1b]133;P\x07'.bytes())!
	assert t.screens.active.cursor.semantic_content == .prompt
	assert t.screens.active.cursor.x == 5
	assert t.screens.active.cursor.y == 0
}

fn test_semantic_prompt_new_command() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Write some text
	s.next_slice('Hello'.bytes())!
	s.next_slice('\x1b]133;N\x07'.bytes())!

	// Should behave like fresh_line_new_prompt - cursor moves to column 0
	// on next line since we had content
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 1
	assert t.screens.active.cursor.semantic_content == .prompt
}

fn test_semantic_prompt_new_command_at_column_zero() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// OSC 133;N when already at column 0 should stay on same line
	s.next_slice('\x1b]133;N\x07'.bytes())!
	assert t.screens.active.cursor.x == 0
	assert t.screens.active.cursor.y == 0
	assert t.screens.active.cursor.semantic_content == .prompt
}

fn test_semantic_prompt_end_prompt_start_input_terminate_eol_clears_on_linefeed() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := Stream.init_alloc[ReadonlyHandler](voidptr(1), ReadonlyHandler.init(mut t))
	defer { s.deinit() }

	// Set input terminated by EOL
	s.next_slice('\x1b]133;I\x07'.bytes())!
	assert t.screens.active.cursor.semantic_content == .input

	// Linefeed should reset semantic content to output
	s.next_slice('\n'.bytes())!
	assert t.screens.active.cursor.semantic_content == .output
}

// Witty-only: the scalar Stream entry points (`next`, `print`, `execute`)
// that stream.zig exposes publicly, driven through `Terminal.vt_stream()`.
fn test_readonly_scalar_stream_surface() ! {
	mut t := Terminal.init(Options{ cols: 10, rows: 10 })!
	defer { t.deinit() }

	mut s := t.vt_stream()
	defer { s.deinit() }

	s.next(u8(`A`))!
	s.print(u32(`B`))!
	assert t.screens.active.cursor.x == 2
	assert t.plain_string()! == 'AB'

	s.execute(0x0d)!
	assert t.screens.active.cursor.x == 0
}
