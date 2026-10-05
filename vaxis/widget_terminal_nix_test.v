module vaxis

import os
import zigimg

fn terminal_test_widget(width u16, height u16) !Terminal {
	pair := TerminalPty{
		pty: os.File{
			fd: -1
		}
		tty: os.File{
			fd: -1
		}
	}
	mut storage := []u8{len: 8}
	mut widget := Terminal{
		scrollback_size: 0
		pty:             pair
		pty_writer:      zigimg.WriteStream.init_memory(mut storage)
		cmd:             TerminalCommand{
			argv:              []
			working_directory: none
			env_map:           unsafe { nil }
			pty:               pair
		}
		front_screen:    TerminalScreen.new(width, height)!
		back_screen_pri: TerminalScreen.new(width, height)!
		back_screen_alt: TerminalScreen.new(width, height)!
		tab_stops:       [u16(0), 8, 16]
	}
	widget.back_screen = &widget.back_screen_pri
	return widget
}

fn test_terminal_controls_draw_and_key_writer() {
	mut widget := terminal_test_widget(20, 3)!
	// Rebind after moving the manually constructed source-shaped value.
	widget.back_screen = &widget.back_screen_pri
	widget.back_screen.cursor.col = 3
	widget.horizontal_tab(1)
	assert widget.back_screen.cursor.col == 8
	widget.back_screen.scrolling_region.left = 2
	widget.carriage_return()
	assert widget.back_screen.cursor.col == 2
	widget.set_mode(7, false)
	assert !widget.mode.autowrap
	widget.set_mode(2026, true)
	assert widget.mode.sync
	widget.set_mode(1049, true)
	assert widget.back_screen == &widget.back_screen_alt
	widget.set_mode(1049, false)
	widget.back_screen.cursor.col = 0
	widget.back_screen.scrolling_region.left = 0
	widget.set_mode(2026, false)
	widget.back_screen.print('x', 1, true)!
	mut screen := Screen.new(Winsize{ cols: 20, rows: 3 })
	widget.draw(Window.new(&screen))!
	cell := screen.read_cell(0, 0) or { panic('missing cell') }
	assert cell.char_.grapheme == 'x'
	assert !widget.dirty
	mut out := []u8{len: 64}
	widget.pty_writer = zigimg.WriteStream.init_memory(mut out)
	widget.update(TerminalInputEvent(TerminalKeyPress{
		key: Key{
			codepoint: u32(`a`)
		}
	}))!
	assert widget.pty_writer.buffered().bytestr() == 'a'
	mut writer := widget.get_pty_writer()
	writer.write_byte(`b`)!
	assert widget.pty_writer.buffered().bytestr() == 'ab'
}

fn test_terminal_pending_events_and_command_kill_without_pid() {
	mut widget := terminal_test_widget(4, 2)!
	widget.back_screen = &widget.back_screen_pri
	assert widget.try_event() == none
	widget.consume_event(TerminalControl{ value: .bel })!
	event := widget.try_event() or { panic('missing bell') }
	assert event is TerminalBell
	widget.consume_event(TerminalOsc{ bytes: '0;first'.bytes() })!
	first := widget.try_event() or { panic('missing title') }
	widget.consume_event(TerminalOsc{ bytes: '0;other'.bytes() })!
	match first {
		TerminalTitleChange {
			assert first.bytes.bytestr() == 'other'
		}
		else {
			assert false
		}
	}

	mut command := TerminalCommand{
		argv:              []
		working_directory: none
		env_map:           unsafe { nil }
		pty:               widget.pty
	}
	command.kill()
	assert command.pid == none
	_ = os.File{}
}

fn test_terminal_print_keeps_parser_accepted_malformed_utf8_bytes() {
	for bytes in [[u8(0xe1), 0x80, `a`], [u8(0xf0), 0x9f, `a`, `b`]] {
		mut reader := zigimg.ReadStream.init_memory(bytes)
		mut parser := TerminalParser{}
		event := parser.parse_reader(mut reader)!
		mut widget := terminal_test_widget(8, 2)!
		widget.back_screen = &widget.back_screen_pri
		widget.consume_event(event)!
		mut reconstructed := []u8{}
		for cell in widget.back_screen.buf {
			if cell.char_ != ' ' { reconstructed << cell.char_.bytes() }
		}
		assert reconstructed == bytes
	}
}
