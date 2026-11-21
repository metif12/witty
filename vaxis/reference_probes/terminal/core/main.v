module main

import os
import strings
import encoding.hex
import vaxis
import zigimg

fn new_terminal(w u16, h u16, bh u16) !vaxis.Terminal {
	pair := vaxis.TerminalPty{ pty: os.File{ fd: -1 }, tty: os.File{ fd: -1 } }
	mut storage := []u8{len: 8}
	mut t := vaxis.Terminal{ scrollback_size: bh - h, pty: pair, pty_writer: zigimg.WriteStream.init_memory(mut storage), cmd: vaxis.TerminalCommand{ argv: [], working_directory: none, env_map: unsafe { nil }, pty: pair }, front_screen: vaxis.TerminalScreen.new(w, h)!, back_screen_pri: vaxis.TerminalScreen.new(w, bh)!, back_screen_alt: vaxis.TerminalScreen.new(w, h)!, tab_stops: [] }
	for col := u16(0); col < w; col += 8 { t.tab_stops << col }
	return t
}

fn state(t &vaxis.Terminal) string {
	mut flags := ''
	for cell in t.back_screen.buf { flags += int(cell.dirty).str() }
	return '${t.back_screen.cursor.col},${t.back_screen.cursor.row},${int(t.back_screen.cursor.pending_wrap)}/${int(t.mode.origin)}${int(t.mode.autowrap)}${int(t.mode.cursor)}${int(t.mode.sync)}/${int(t.back_screen == &t.back_screen_alt)}/${flags}'
}

fn control(p []string) !string {
	mut t := new_terminal(u16(p[1].int()), 3, 3)!
	t.back_screen = &t.back_screen_pri
	t.back_screen.cursor.col = u16(p[2].int())
	t.back_screen.cursor.row = 1
	t.back_screen.cursor.pending_wrap = true
	t.back_screen.scrolling_region.left = u16(p[3].int())
	t.mode.origin = p[4] == '1'
	n := uint(p[6].u64())
	match p[5] {
		'c' { t.carriage_return() }
		't' { t.horizontal_tab(n) }
		'b' { t.horizontal_back_tab(n) }
		'm' { t.set_mode(u16(n), p[7] == '1') }
		else { panic('bad op') }
	}
	return state(&t)
}

fn draw(p []string) !string {
	w := u16(p[1].int())
	h := u16(p[2].int())
	mut t := new_terminal(w, h, u16(p[3].int()))!
	t.back_screen = &t.back_screen_pri
	t.back_screen.print('x', 1, true)!
	t.back_screen.print('界', 2, true)!
	t.back_screen.cursor.row = h - 1
	t.back_screen.cursor.col = w - 1
	t.mode.sync = p[4] == '1'
	t.mode.cursor = p[5] == '1'
	t.dirty = true
	locked_back := p[6] == '1'
	if locked_back { t.back_mutex.lock() }
	mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: u16(p[7].int()), rows: u16(p[8].int()) })
	t.draw(vaxis.Window.new(&screen))!
	if locked_back { t.back_mutex.unlock() }
	mut result := ''
	for cell in screen.buf {
		result += '${hex.encode(cell.char_.grapheme.bytes())}:${cell.char_.width},'
	}
	return '${result}/${screen.cursor_col},${screen.cursor_row},${int(screen.cursor_vis)},${u8(screen.cursor_shape)}/${int(t.dirty)}/${state(&t)}'
}

fn update(p []string, path string) !string {
	mut t := new_terminal(4, 2, 2)!
	t.back_screen = &t.back_screen_pri
	mut file := os.open_file(path, 'w+')!
	defer { file.close() }
	mut bytes := []u8{len: p[1].int()}
	t.pty_writer = zigimg.WriteStream.init_file_streaming(file, mut bytes)
	mut writer := t.get_pty_writer()
	writer.write_all(p[2].bytes())!
	mut result := 'ok'
	t.update(vaxis.TerminalInputEvent(vaxis.TerminalKeyPress{ key: vaxis.Key{ codepoint: u32(p[3].u64()), mods: vaxis.Modifiers.from_int(u8(p[4].int())) } })) or { result = err.msg() }
	writer.write_byte(`!`)!
	writer.flush()!
	return '${result}/${hex.encode(os.read_bytes(path)!)}/${writer.buffered().len}'
}

fn C.read(fd int, buf voidptr, count uint) int

fn cleanup(p []string) !string {
	first := os.open_file('/dev/null', 'r+')!
	second := os.open_file('/dev/null', 'r+')!
	pair := vaxis.TerminalPty{ pty: first, tty: second }
	mut t := new_terminal(4, 2, 2)!
	t.back_screen = &t.back_screen_pri
	t.pty = pair
	t.cmd.pty = pair
	match p[1] {
		'terminal' {
			t.event_queue.push(vaxis.TerminalBell{})
			t.deinit()
		}
		'pty' { pair.deinit() }
		else {
			if p[1] == 'dead' { t.cmd.pid = 2147483647 }
			t.cmd.kill()
			pair.deinit()
		}
	}
	mut scratch := u8(0)
	closed_first := C.read(first.fd, &scratch, 0) < 0
	closed_second := C.read(second.fd, &scratch, 0) < 0
	event := t.try_event()
	bell := if item := event { item is vaxis.TerminalBell } else { false }
	return '${int(closed_first)},${int(closed_second)}/${int(t.should_quit)},${int(t.cmd.pid == none)},${int(bell)}'
}

fn registry() !string {
	mut first := new_terminal(4, 2, 2)!
	mut second := new_terminal(4, 2, 2)!
	first.pty = vaxis.TerminalPty{ pty: os.open_file('/dev/null', 'r+')!, tty: os.open_file('/dev/null', 'r+')! }
	second.pty = vaxis.TerminalPty{ pty: os.open_file('/dev/null', 'r+')!, tty: os.open_file('/dev/null', 'r+')! }
	first_pid := 2147483646
	second_pid := 2147483647
	first.cmd.pid = first_pid
	second.cmd.pid = second_pid
	mut globals := vaxis.terminal_global_state()
	mut entries := map[int]&vaxis.Terminal{}
	entries[first_pid] = &first
	entries[second_pid] = &second
	globals.vts = entries.move()
	globals.count = 2
	defer {
		globals.vts = none
		globals.count = 0
	}
	mut result := ''
	for step in 0 .. 3 {
		if step == 1 { first.deinit() }
		if step == 2 { second.deinit() }
		values := (globals.vts or { panic('registry unexpectedly released') }).clone()
		result += '${globals.count}|${values.len}|${int(first_pid in values)}|${int(second_pid in values)}|${int(globals.vts != none)}\n'
	}
	return result
}

fn trap(name string) ! {
	mut t := new_terminal(4, 2, if name == 'tall' { u16(3) } else { u16(2) })!
	t.back_screen = &t.back_screen_pri
	match name {
		'tall' {
			mut s := vaxis.Screen.new(vaxis.Winsize{ cols: 4, rows: 2 })
			t.draw(vaxis.Window.new(&s))!
		}
		'back' {
			t.back_screen.cursor.col = 3
			t.horizontal_back_tab(1)
		}
		'tabs' {
			t.tab_stops = []u16{}
			t.horizontal_back_tab(1)
		}
		'zero' {
			t.back_screen.width = 0
			t.horizontal_tab(1)
		}
		'kitty' {
			t.back_screen.csi_u_flags = vaxis.KittyFlags.from_int(1)
			t.update(vaxis.TerminalInputEvent(vaxis.TerminalKeyPress{ key: vaxis.Key{ codepoint: u32(`a`) } })) or {
				eprintln('UNEXPECTED: ${err.msg()}')
				return
			}
		}
		else { panic('bad trap') }
	}
	eprintln('UNEXPECTED: returned')
}

fn main() {
	if os.args[1] == 'registry' {
		print(registry() or { panic(err) })
		return
	}
	if os.args[1].starts_with('trap:') {
		trap(os.args[1][5..]) or { eprintln('UNEXPECTED: ${err.msg()}') }
		return
	}
	text := os.read_file(os.args[1]) or { panic(err) }
	mut out := strings.new_builder(4096)
	for line in text.split_into_lines() {
		p := line.split('|')
		result := match p[0] {
			'C' { control(p) or { panic(err) } }
			'D' { draw(p) or { panic(err) } }
			'U' { update(p, os.args[2]) or { panic(err) } }
			'N' { cleanup(p) or { panic(err) } }
			else { panic('bad case') }
		}
		out.writeln(result)
	}
	print(out.str())
}
