module vaxis

import os
import log
import sync
import zigimg

pub struct TerminalExited {}

pub struct TerminalRedraw {}

pub struct TerminalBell {}

pub struct TerminalTitleChange {
pub:
	bytes []u8
}

pub struct TerminalPwdChange {
pub:
	bytes []u8
}

pub type TerminalEvent = TerminalExited
	| TerminalRedraw
	| TerminalBell
	| TerminalTitleChange
	| TerminalPwdChange

pub struct TerminalKeyPress {
pub:
	key Key
}

pub type TerminalInputEvent = TerminalKeyPress

pub struct TerminalOptions {
pub:
	scrollback_size           u16     = 500
	winsize                   Winsize = Winsize{
		rows: 24
		cols: 80
	}
	initial_working_directory ?string
}

pub struct TerminalMode {
pub mut:
	origin   bool
	autowrap bool = true
	cursor   bool = true
	sync     bool
}

pub struct TerminalPty {
pub mut:
	pty os.File @[required]
	tty os.File @[required]
}

pub struct TerminalCommand {
pub mut:
	argv              []string @[required]
	working_directory ?string  @[required]
	pid               ?int
	env_map           &map[string]string @[required]
	pty               TerminalPty        @[required]
}

// GC owns the screen arrays and byte lists. File descriptors remain explicit
// owners, matching the source lifecycle. back_screen is bound by spawn/set_mode.
@[heap]
pub struct Terminal {
pub mut:
	scrollback_size   u16                @[required]
	pty               TerminalPty        @[required]
	pty_writer        zigimg.WriteStream @[required]
	cmd               TerminalCommand    @[required]
	thread            ?voidptr
	front_screen      TerminalScreen @[required]
	front_mutex       &sync.Mutex     = sync.new_mutex()
	back_screen       &TerminalScreen = unsafe { nil }
	back_screen_pri   TerminalScreen @[required]
	back_screen_alt   TerminalScreen @[required]
	scroll_offset     uint
	back_mutex        &sync.Mutex = sync.new_mutex()
	dirty             bool
	should_quit       bool
	mode              TerminalMode
	tab_stops         []u16 @[required]
	title             []u8
	working_directory []u8
	last_printed      string
	event_queue       &EventQueue[TerminalEvent] = EventQueue.new[TerminalEvent](16)
}

pub fn (mut terminal Terminal) draw(win Window) ! {
	if terminal.back_mutex.try_lock() {
		if !terminal.mode.sync {
			terminal.back_screen.copy_to(mut terminal.front_screen) or {
				terminal.back_mutex.unlock()
				return err
			}
			terminal.dirty = false
		}
		terminal.back_mutex.unlock()
	}
	for row := u16(0); row < terminal.front_screen.height; row++ {
		mut col := u16(0)
		for col < terminal.front_screen.width {
			cell := terminal.front_screen.read_cell(uint(col), uint(row)) or { continue }
			win.write_cell(col, row, cell)
			col = terminal_add_u16(col, if cell.char_.width > 0 {
				u16(cell.char_.width)
			} else {
				u16(1)
			})
		}
	}
	if terminal.mode.cursor {
		win.set_cursor_shape(terminal.front_screen.cursor.shape)
		win.show_cursor(terminal.front_screen.cursor.col, terminal.front_screen.cursor.row)
	}
}

pub fn (mut terminal Terminal) try_event() ?TerminalEvent {
	return terminal.event_queue.try_pop()
}

pub fn (mut terminal Terminal) update(event TerminalInputEvent) ! {
	mut writer := terminal.get_pty_writer()
	defer { writer.flush() or {} }
	terminal_key_encode(mut writer, event.key, true, terminal.back_screen.csi_u_flags)!
}

pub fn (mut terminal Terminal) get_pty_writer() &zigimg.WriteStream {
	return unsafe { &terminal.pty_writer }
}

pub fn (mut terminal Terminal) set_mode(mode u16, value bool) {
	match mode {
		7 {
			terminal.mode.autowrap = value
		}
		25 {
			terminal.mode.cursor = value
		}
		1049 {
			terminal.back_screen = if value {
				&terminal.back_screen_alt
			} else {
				&terminal.back_screen_pri
			}
			for i in 0 .. terminal.back_screen.buf.len {
				terminal.back_screen.buf[i].dirty = true
			}
		}
		2026 {
			terminal.mode.sync = value
		}
		else {}
	}
}

pub fn (mut terminal Terminal) carriage_return() {
	terminal.back_screen.cursor.pending_wrap = false
	terminal.back_screen.cursor.col = if terminal.mode.origin
		|| terminal.back_screen.cursor.col >= terminal.back_screen.scrolling_region.left {
		terminal.back_screen.scrolling_region.left
	} else {
		u16(0)
	}
}

pub fn (mut terminal Terminal) horizontal_tab(count uint) {
	col := terminal.back_screen.cursor.col
	mut seen := uint(0)
	mut final := u16(0)
	mut found := false
	for stop in terminal.tab_stops {
		if stop <= col {
			continue
		}
		seen = widget_checked_add(seen, 1)
		if seen == count {
			final = stop
			found = true
			break
		}
	}
	if !found { final = terminal_sub_u16(terminal.back_screen.width, 1) }
	terminal.back_screen.cursor_right(if final < col { u16(0) } else { final - col })
}

pub fn (mut terminal Terminal) horizontal_back_tab(count uint) {
	col := terminal.back_screen.cursor.col
	mut index := uint(0)
	mut found := false
	for i, stop in terminal.tab_stops {
		if stop <= col {
			continue
		}
		index = uint(i)
		found = true
		break
	}
	if !found {
		if terminal.tab_stops.len == 0 { panic('integer overflow') }
		index = uint(terminal.tab_stops.len - 1)
	}
	delta := if count == 0 { uint(0) } else { count - 1 }
	index = if index < delta { uint(0) } else { index - delta }
	if index >= uint(terminal.tab_stops.len) { panic('index out of bounds') }
	mut final := terminal.tab_stops[int(index)]
	if terminal.mode.origin && final < terminal.back_screen.scrolling_region.left {
		final = terminal.back_screen.scrolling_region.left
	}
	terminal.back_screen.cursor_left(terminal_sub_u16(final, col))
}

fn terminal_add_u16(left u16, right u16) u16 {
	if left > 65535 - right { panic('integer overflow') }
	return left + right
}

fn terminal_sub_u16(left u16, right u16) u16 {
	if left < right { panic('integer overflow') }
	return left - right
}

fn terminal_sat_sub_u16(left u16, right u16) u16 {
	return if left < right { u16(0) } else { left - right }
}

fn terminal_min_u16(left u16, right u16) u16 {
	return if left < right { left } else { right }
}

fn terminal_mul_u16(left u16, right u16) u16 {
	if right != 0 && left > 65535 / right { panic('integer overflow') }
	return left * right
}

fn (mut terminal Terminal) run() ! {
	mut parser := TerminalParser{
		buf: []u8{cap: 128}
	}
	mut buffer := []u8{len: 4096}
	mut reader := zigimg.ReadStream.init_file_streaming(terminal.pty.pty, mut buffer)
	for !terminal.should_quit {
		event := parser.parse_reader(mut reader)!
		terminal.back_mutex.lock()
		if !terminal.dirty && terminal.event_queue.try_push(TerminalRedraw{}) {
			terminal.dirty = true
		}
		terminal.consume_event(event) or {
			terminal.back_mutex.unlock()
			return err
		}
		terminal.back_mutex.unlock()
	}
}

fn (mut terminal Terminal) consume_event(event TerminalParseEvent) ! {
	match event {
		TerminalPrint {
			text := event.bytes.bytestr()
			mut iter := text_input_grapheme_iterator(text)
			for {
				grapheme := iter.next() or { break }
				gr := text[grapheme.start..grapheme.limit]
				terminal.back_screen.print(gr, u8(text_input_gwidth(gr, .unicode)),
					terminal.mode.autowrap)!
			}
		}
		TerminalControl {
			terminal.handle_c0(event.value)!
		}
		TerminalEscape {
			if event.bytes.len == 0 { panic('integer overflow') }
			match event.bytes[event.bytes.len - 1] {
				`B` {}
				`D` {
					terminal.back_screen.index()!
				}
				`E` {
					terminal.back_screen.index()!
					terminal.carriage_return()
				}
				`H` {
					if terminal.back_screen.cursor.col in terminal.tab_stops { return }
					terminal.tab_stops << terminal.back_screen.cursor.col
					terminal.tab_stops.sort()
				}
				`M` {
					terminal.back_screen.reverse_index()!
				}
				else {
					log.info('unhandled escape: ${event.bytes.bytestr()}')
				}
			}
		}
		TerminalSs2 {
			log.info('unhandled ss2: ${event.byte.ascii_str()}')
		}
		TerminalSs3 {
			log.info('unhandled ss3: ${event.byte.ascii_str()}')
		}
		TerminalCsi {
			terminal.handle_csi(event)!
		}
		TerminalOsc {
			terminal.handle_osc(event.bytes)!
		}
		TerminalApc {
			log.info('unhandled apc: ${event.bytes.bytestr()}')
		}
	}
}

fn (mut terminal Terminal) handle_c0(value TerminalC0) ! {
	match value {
		.nul, .soh, .stx, .eot, .enq, .so, .si {}
		.bel { terminal.event_queue.push(TerminalBell{}) }
		.bs { terminal.back_screen.cursor_left(1) }
		.ht { terminal.horizontal_tab(1) }
		.lf, .vt, .ff { terminal.back_screen.index()! }
		.cr { terminal.carriage_return() }
		else { log.warn('unhandled C0: 0x${u8(value):x}') }
	}
}

fn (mut terminal Terminal) handle_csi(seq TerminalCsi) ! {
	match seq.final {
		`A`, `k` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.cursor_up(iter.next() or { u16(1) })
		}
		`B` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.cursor_down(uint(iter.next() or { u16(1) }))
		}
		`C` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.cursor_right(iter.next() or { u16(1) })
		}
		`D`, `j` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.cursor_left(iter.next() or { u16(1) })
		}
		`E` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.cursor_down(uint(iter.next() or { u16(1) }))
			terminal.carriage_return()
		}
		`F` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.cursor_up(iter.next() or { u16(1) })
			terminal.carriage_return()
		}
		`G`, 0x60 {
			mut iter := seq.iterator[u16]()
			col := iter.next() or { u16(1) }
			terminal.back_screen.cursor.col = terminal_sat_sub_u16(col, 1)
			if terminal.back_screen.cursor.col < terminal.back_screen.scrolling_region.left {
				terminal.back_screen.cursor.col = terminal.back_screen.scrolling_region.left
			}
			if terminal.back_screen.cursor.col > terminal.back_screen.scrolling_region.right {
				terminal.back_screen.cursor.col = terminal.back_screen.scrolling_region.right
			}
			terminal.back_screen.cursor.pending_wrap = false
		}
		`H`, `f` {
			mut iter := seq.iterator[u16]()
			row := iter.next() or { u16(1) }
			col := iter.next() or { u16(1) }
			terminal.back_screen.cursor.col = terminal_sat_sub_u16(col, 1)
			terminal.back_screen.cursor.row = terminal_sat_sub_u16(row, 1)
			terminal.back_screen.cursor.pending_wrap = false
		}
		`I` {
			mut iter := seq.iterator[u16]()
			terminal.horizontal_tab(uint(iter.next() or { u16(1) }))
		}
		`J` {
			mut iter := seq.iterator[u16]()
			kind := iter.next() or { u16(0) }
			match kind {
				0 { terminal.back_screen.erase_below() }
				1 { terminal.back_screen.erase_above() }
				2 { terminal.back_screen.erase_all() }
				else {}
			}
		}
		`K` {
			mut iter := seq.iterator[u8]()
			kind := iter.next() or { u8(0) }
			match kind {
				0 { terminal.back_screen.erase_right() }
				1 { terminal.back_screen.erase_left() }
				2 { terminal.back_screen.erase_line() }
				else {}
			}
		}
		`L` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.insert_line(uint(iter.next() or { u16(1) }))!
		}
		`M` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.delete_line(uint(iter.next() or { u16(1) }))!
		}
		`P` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.delete_characters(uint(iter.next() or { u16(1) }))!
		}
		`S` {
			mut iter := seq.iterator[u16]()
			count := iter.next() or { u16(1) }
			row := terminal.back_screen.cursor.row
			col := terminal.back_screen.cursor.col
			wrap := terminal.back_screen.cursor.pending_wrap
			defer {
				terminal.back_screen.cursor.row = row
				terminal.back_screen.cursor.col = col
				terminal.back_screen.cursor.pending_wrap = wrap
			}
			terminal.back_screen.cursor.row = terminal.back_screen.scrolling_region.top
			terminal.back_screen.cursor.col = terminal.back_screen.scrolling_region.left
			terminal.back_screen.delete_line(uint(count))!
		}
		`T` {
			mut iter := seq.iterator[u16]()
			terminal.back_screen.scroll_down(uint(iter.next() or { u16(1) }))!
		}
		`W` {
			if marker := seq.private_marker {
				if marker != `?` { return }
				mut iter := seq.iterator[u16]()
				count := iter.next() or { return }
				if count != 5 { return }
				terminal.tab_stops.clear()
				mut col := u16(0)
				for col < terminal.back_screen.width {
					terminal.tab_stops << col
					col = terminal_add_u16(col, 8)
				}
			}
		}
		`X` {
			terminal.back_screen.cursor.pending_wrap = false
			mut iter := seq.iterator[u16]()
			count := iter.next() or { u16(1) }
			base := terminal_mul_u16(terminal.back_screen.cursor.row, terminal.back_screen.width)
			start := terminal_add_u16(base, terminal.back_screen.cursor.col)
			row_end := terminal_add_u16(base, terminal.back_screen.width)
			erase_end := if row_end > count && row_end > 1 {
				row_end
			} else if count > 1 {
				count
			} else {
				u16(1)
			}
			for i in int(start) .. int(erase_end) {
				if i >= terminal.back_screen.buf.len { panic('index out of bounds') }
				terminal.back_screen.buf[i].erase(terminal.back_screen.cursor.style.bg)
			}
		}
		`Z` {
			mut iter := seq.iterator[u16]()
			terminal.horizontal_back_tab(uint(iter.next() or { u16(1) }))
		}
		`a` {
			mut iter := seq.iterator[u16]()
			count := iter.next() or { u16(1) }
			terminal.back_screen.cursor.pending_wrap = false
			max_end := if terminal.mode.origin {
				terminal.back_screen.scrolling_region.right
			} else {
				terminal_sub_u16(terminal.back_screen.width, 1)
			}
			terminal.back_screen.cursor.col = terminal_min_u16(terminal_add_u16(terminal.back_screen.cursor.col,
				max_end), terminal_add_u16(terminal.back_screen.cursor.col, count))
		}
		`b` {
			mut iter := seq.iterator[u16]()
			count := iter.next() or { u16(1) }
			width := u8(text_input_gwidth(terminal.last_printed, .unicode))
			for _ in 0 .. int(count) {
				terminal.back_screen.print(terminal.last_printed, width, terminal.mode.autowrap)!
			}
		}
		`c` {
			mut writer := terminal.get_pty_writer()
			defer { writer.flush() or {} }
			if marker := seq.private_marker {
				match marker {
					`>` { writer.write_all('\x1b[>1;69;0c'.bytes())! }
					`=` { writer.write_all('\x1b[=0000c'.bytes())! }
					else { terminal_log_csi(seq) }
				}
			} else {
				writer.write_all('\x1b[?62;22c'.bytes())!
			}
		}
		`d` {
			terminal.back_screen.cursor.pending_wrap = false
			mut iter := seq.iterator[u16]()
			count := iter.next() or { u16(1) }
			maximum := if terminal.mode.origin {
				terminal.back_screen.scrolling_region.bottom
			} else {
				terminal_sat_sub_u16(terminal.back_screen.height, 1)
			}
			terminal.back_screen.cursor.pending_wrap = false
			terminal.back_screen.cursor.row = terminal_min_u16(maximum,
				terminal_sat_sub_u16(count, 1))
		}
		`e` {
			mut iter := seq.iterator[u16]()
			count := iter.next() or { u16(1) }
			terminal.back_screen.cursor.pending_wrap = false
			terminal.back_screen.cursor.row = terminal_min_u16(terminal_sat_sub_u16(terminal.back_screen.width, 1),
				terminal_sat_sub_u16(count, 1))
		}
		`g` {
			mut iter := seq.iterator[u16]()
			count := iter.next() or { u16(0) }
			match count {
				0 {
					current := terminal.tab_stops
					terminal.tab_stops = []u16{}
					for stop in current {
						if stop == terminal.back_screen.cursor.col {
							continue
						}
						terminal.tab_stops << stop
					}
				}
				3 {
					terminal.tab_stops = []u16{}
				}
				else {
					terminal_log_csi(seq)
				}
			}
		}
		`h`, `l` {
			mut iter := seq.iterator[u16]()
			mode := iter.next() or { return }
			if seq.private_marker != none && mode == 4 { return }
			terminal.set_mode(mode, seq.final == `h`)
		}
		`m` {
			if seq.intermediate == none && seq.private_marker == none {
				terminal.back_screen.sgr(seq)
			}
		}
		`n` {
			mut iter := seq.iterator[u16]()
			kind := iter.next() or { u16(0) }
			if seq.intermediate == none && seq.private_marker == none {
				mut writer := terminal.get_pty_writer()
				defer { writer.flush() or {} }
				match kind {
					5 {
						writer.write_all('\x1b[0n'.bytes())!
					}
					6 {
						row := terminal_add_u16(terminal.back_screen.cursor.row, 1)
						col := terminal_add_u16(terminal.back_screen.cursor.col, 1)
						writer.write_all('\x1b[${row};${col}R'.bytes())!
					}
					else {
						terminal_log_csi(seq)
					}
				}
			}
		}
		`p` {
			mut iter := seq.iterator[u16]()
			kind := iter.next() or { u16(0) }
			if intermediate := seq.intermediate {
				if intermediate == `$` {
					mut writer := terminal.get_pty_writer()
					defer { writer.flush() or {} }
					if kind == 2026 {
						writer.write_all('\x1b[?2026;2$p'.bytes())!
					} else {
						log.warn('unhandled mode: ${kind}')
						writer.write_all('\x1b[?${kind};0$p'.bytes())!
					}
				} else {
					terminal_log_csi(seq)
				}
			}
		}
		`q` {
			if intermediate := seq.intermediate {
				if intermediate == ` ` {
					mut iter := seq.iterator[u8]()
					shape := iter.next() or { u8(0) }
					if shape > 6 { panic('invalid enum value') }
					terminal.back_screen.cursor.shape = unsafe { CursorShape(shape) }
				}
			}
			if marker := seq.private_marker {
				mut writer := terminal.get_pty_writer()
				defer { writer.flush() or {} }
				if marker == `>` {
					writer.write_all('\x1bP>|libvaxis dev\x1b\\'.bytes())!
				} else {
					terminal_log_csi(seq)
				}
			}
		}
		`r` {
			if seq.intermediate != none || seq.private_marker != none { return }
			mut iter := seq.iterator[u16]()
			top := iter.next() or { u16(1) }
			bottom := iter.next() or { terminal.back_screen.height }
			terminal.back_screen.scrolling_region.top = terminal_sat_sub_u16(top, 1)
			terminal.back_screen.scrolling_region.bottom = terminal_sat_sub_u16(bottom, 1)
			terminal.back_screen.cursor.pending_wrap = false
			if terminal.mode.origin {
				terminal.back_screen.cursor.col = terminal.back_screen.scrolling_region.left
				terminal.back_screen.cursor.row = terminal.back_screen.scrolling_region.top
			} else {
				terminal.back_screen.cursor.col = 0
				terminal.back_screen.cursor.row = 0
			}
		}
		else {
			terminal_log_csi(seq)
		}
	}
}

fn terminal_log_csi(seq TerminalCsi) {
	log.info('unhandled CSI: ${seq.format_text()}')
}

fn (mut terminal Terminal) handle_osc(bytes []u8) ! {
	mut semicolon := -1
	for i, byte in bytes {
		if byte == `;` {
			semicolon = i
			break
		}
	}
	if semicolon < 0 {
		log.info('unhandled osc: ${bytes.bytestr()}')
		return
	}
	kind := parse_input_unsigned(bytes[..semicolon].bytestr(), 10, 8) or {
		log.info('unhandled osc: ${bytes.bytestr()}')
		return
	}
	match kind {
		0 {
			terminal.title.clear()
			terminal.title << bytes[semicolon + 1..]
			terminal.event_queue.push(TerminalTitleChange{
				bytes: unsafe { terminal.title.data.vbytes(terminal.title.len) }
			})
		}
		7 {
			log.error('osc: ${bytes.bytestr()}')
			terminal.working_directory.clear()
			mut start := -1
			for i := semicolon + 10; i < bytes.len; i++ {
				if bytes[i] == `/` {
					start = i
					break
				}
			}
			if start < 0 {
				log.info('unknown OSC 7 format: ${bytes.bytestr()}')
				return
			}
			encoded := bytes[start..]
			mut i := 0
			for i < encoded.len {
				mut byte := encoded[i]
				if byte == `%` {
					if i + 3 > encoded.len { panic('index out of bounds') }
					byte = u8(parse_input_unsigned(encoded[i + 1..i + 3].bytestr(), 16, 8)!)
					i += 2
				}
				terminal.working_directory << byte
				i++
			}
			terminal.event_queue.push(TerminalPwdChange{
				bytes: unsafe { terminal.working_directory.data.vbytes(terminal.working_directory.len) }
			})
		}
		else {
			log.info('unhandled osc: ${bytes.bytestr()}')
		}
	}
}
