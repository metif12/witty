module main

import input
import macos
import os
import pty
import terminal

// C interop declarations needed in this module.
#include <unistd.h>
#include <signal.h>

fn C.fork() int
fn C.execvp(file &char, argv &&char) int
fn C.dup2(oldfd int, newfd int) int
fn C.close(fd int) int
fn C.read(fd int, buf voidptr, count usize) isize
fn C.write(fd int, buf voidptr, count usize) isize
fn C._exit(status int)
fn C.setenv(name &char, value &char, overwrite int) int

// CoreGraphics C functions for drawing.
fn C.CGContextSetRGBFillColor(ctx voidptr, r f64, g f64, b f64, a f64)
fn C.CGContextFillRect(ctx voidptr, rect C.CGRect)
fn C.CGContextSetTextMatrix(ctx voidptr, t C.CGAffineTransform)

// CGRect and CGAffineTransform for CoreGraphics calls.
struct C.CGRect {
	origin C.CGPoint
	size   C.CGSize
}

struct C.CGPoint {
	x f64
	y f64
}

struct C.CGSize {
	width  f64
	height f64
}

struct C.CGAffineTransform {
	a  f64
	b  f64
	c  f64
	d  f64
	tx f64
	ty f64
}

// ============================================================
// Per-tab state
// ============================================================

@[heap]
struct TermState {
mut:
	term      terminal.Terminal
	stream    terminal.ReadonlyStream
	pty_fd    int = -1
	child_pid int = -1
	cell_w    f64 = 8.0
	cell_h    f64 = 16.0
	font      voidptr // CTFontRef (shared)
	cols      int = 80
	rows      int = 24
	view      voidptr // the VTTerminalView* for this tab
}

// ============================================================
// Shared app config
// ============================================================

struct AppConfig {
	pixel_w int = 640
	pixel_h int = 384
	cols    u16 = 80
	rows    u16 = 24
	shell   string
	font    voidptr // shared CTFontRef
}

fn get_app_config() AppConfig {
	shell := os.getenv_opt('SHELL') or { '/bin/zsh' }
	ct_font := macos.create_font('Menlo', 13.0)
	return AppConfig{
		shell: shell
		font: ct_font
	}
}

// ============================================================
// spawn_terminal — creates a new terminal + PTY + child process
// ============================================================

fn spawn_terminal(cfg AppConfig) !&TermState {
	mut term := terminal.Terminal.init(terminal.Options{
		cols: cfg.cols
		rows: cfg.rows
	})!

	mut p := pty.Pty.open(pty.Winsize{
		ws_row: cfg.rows
		ws_col: cfg.cols
		ws_xpixel: u16(cfg.pixel_w)
		ws_ypixel: u16(cfg.pixel_h)
	})!

	pid := C.fork()
	if pid < 0 {
		return error('fork failed')
	}
	if pid == 0 {
		// ---- Child process ----
		C.dup2(p.slave, 0)
		C.dup2(p.slave, 1)
		C.dup2(p.slave, 2)
		p.child_pre_exec() or {
			C._exit(1)
		}
		C.setenv(c'TERM', c'xterm-256color', 1)
		argv := [cfg.shell.str, unsafe { nil }]
		C.execvp(cfg.shell.str, argv.data)
		C._exit(1)
	}

	// ---- Parent process ----
	p.close_slave()

	mut stream := terminal.ReadonlyStream.init(mut term)
	mut state := &TermState{
		term: term
		stream: stream
		pty_fd: p.master
		child_pid: pid
		font: cfg.font
		cols: int(cfg.cols)
		rows: int(cfg.rows)
	}
	return state
}

// ============================================================
// main
// ============================================================

fn main() {
	cfg := get_app_config()

	// 1. Init macOS app
	macos.app_init()

	// 2. Set callbacks (once — they dispatch via per-view userdata)
	macos.set_draw_callback(on_draw)
	macos.set_key_callback(on_key)
	macos.set_resize_callback(on_resize)

	// 3. Create window (first tab)
	view := macos.create_window(cfg.pixel_w, cfg.pixel_h, 'vterminal')

	// 4. Spawn terminal for this tab
	mut state := spawn_terminal(cfg) or {
		eprintln('terminal init failed: ${err}')
		return
	}
	state.view = view
	macos.view_set_userdata(view, voidptr(state))

	// 5. Spawn read thread for this tab
	spawn read_pty_thread(state.pty_fd, state.view)

	// 6. Run the app
	macos.app_run()
}

// ============================================================
// Tab actions
// ============================================================

fn do_new_tab() {
	cfg := get_app_config()
	view := macos.new_tab(cfg.pixel_w, cfg.pixel_h, 'vterminal')
	if view == unsafe { nil } {
		return
	}
	mut state := spawn_terminal(cfg) or {
		eprintln('new tab failed: ${err}')
		macos.close_tab(view)
		return
	}
	state.view = view
	macos.view_set_userdata(view, voidptr(state))
	spawn read_pty_thread(state.pty_fd, state.view)
}

fn do_close_tab(userdata voidptr) {
	if userdata == unsafe { nil } {
		return
	}
	state := unsafe { &TermState(userdata) }
	if state.pty_fd >= 0 {
		C.close(state.pty_fd)
	}
	macos.close_tab(state.view)
}

// ============================================================
// Draw callback — renders terminal grid via CoreGraphics
// ============================================================

fn on_draw(userdata voidptr, ctx voidptr, width f64, height f64) {
	if userdata == unsafe { nil } {
		return
	}
	mut state := unsafe { &TermState(userdata) }

	cell_w := state.cell_w
	cell_h := state.cell_h

	// Fill background black
	C.CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 1.0)
	C.CGContextFillRect(ctx, C.CGRect{
		origin: C.CGPoint{ x: 0, y: 0 }
		size: C.CGSize{ width: width, height: height }
	})

	// Set text matrix for flipped view (CoreText draws upward by default).
	C.CGContextSetTextMatrix(ctx, C.CGAffineTransform{
		a: 1
		b: 0
		c: 0
		d: -1
		tx: 0
		ty: 0
	})

	pages := &state.term.screens.active.pages
	num_rows := if int(pages.rows) < state.rows { int(pages.rows) } else { state.rows }
	num_cols := if int(pages.cols) < state.cols { int(pages.cols) } else { state.cols }

	for row_idx in 0 .. num_rows {
		row := pages.get_active_row(u32(row_idx))

		// Build a string for this row
		mut row_str := []u8{cap: num_cols}
		for col_idx in 0 .. num_cols {
			if col_idx < row.cells.len {
				cp := row.cells[col_idx].codepoint
				if cp >= 32 && cp < 127 {
					row_str << u8(cp)
				} else if cp == 0 {
					row_str << u8(` `)
				} else {
					row_str << u8(`?`)
				}
			} else {
				row_str << u8(` `)
			}
		}

		// Trim trailing spaces
		mut end := row_str.len
		for end > 0 && row_str[end - 1] == u8(` `) {
			end--
		}
		if end == 0 {
			continue
		}

		y_pos := f64(row_idx) * cell_h + cell_h * 0.8
		macos.draw_text(ctx, row_str.data, end, state.font, 0.0, y_pos,
			1.0, 1.0, 1.0)
	}

	// Draw cursor
	cx := state.term.screens.active.cursor.x
	cy := state.term.screens.active.cursor.y
	C.CGContextSetRGBFillColor(ctx, 0.8, 0.8, 0.8, 0.7)
	C.CGContextFillRect(ctx, C.CGRect{
		origin: C.CGPoint{ x: f64(cx) * cell_w, y: f64(cy) * cell_h }
		size: C.CGSize{ width: cell_w, height: cell_h }
	})
}

// ============================================================
// Key callback — encode key events and write to PTY
// ============================================================

// macOS NSEvent modifier flag masks
const ns_shift_mask = u64(1 << 17)
const ns_ctrl_mask = u64(1 << 18)
const ns_alt_mask = u64(1 << 19)
const ns_cmd_mask = u64(1 << 20)

fn on_key(userdata voidptr, keycode u16, modflags u64, chars &u8, len int, uchars &u8, ulen int, is_repeat bool) {
	if userdata == unsafe { nil } {
		return
	}
	state := unsafe { &TermState(userdata) }
	if state.pty_fd < 0 {
		return
	}

	// Map macOS virtual keycode to input.Key
	key := input.mac_keycode_to_key(u32(keycode))

	// Build modifier state from NSEvent modifier flags
	mods := input.Mods{
		shift: (modflags & ns_shift_mask) != 0
		ctrl: (modflags & ns_ctrl_mask) != 0
		alt: (modflags & ns_alt_mask) != 0
		super_: (modflags & ns_cmd_mask) != 0
	}

	// --- App-level bindings (Cmd+key) ---
	if mods.super_ && !mods.ctrl && !mods.alt {
		if !mods.shift {
			match key {
				.key_t {
					do_new_tab()
					return
				}
				.key_w {
					do_close_tab(userdata)
					return
				}
				else {}
			}
		}
		if mods.shift {
			match key {
				.bracket_left {
					macos.select_tab(-1)
					return
				}
				.bracket_right {
					macos.select_tab(1)
					return
				}
				else {}
			}
		}
	}

	// Get the UTF-8 text generated by this key
	utf8_text := if len > 0 {
		unsafe { tos(chars, len) }
	} else {
		''
	}

	// Get the unshifted codepoint (for Kitty protocol)
	unshifted_text := if ulen > 0 {
		unsafe { tos(uchars, ulen) }
	} else {
		''
	}
	unshifted_cp := if unshifted_text.len > 0 {
		runes := unshifted_text.runes()
		if runes.len > 0 { u32(runes[0]) } else { u32(0) }
	} else {
		u32(0)
	}

	// Determine consumed mods (shift is consumed if text differs from unshifted)
	consumed := input.Mods{
		shift: mods.shift && utf8_text != unshifted_text
	}

	action := if is_repeat { input.KeyAction.repeat } else { input.KeyAction.press }

	event := input.KeyEvent{
		action: action
		key: key
		mods: mods
		consumed_mods: consumed
		utf8: utf8_text
		unshifted_codepoint: unshifted_cp
	}

	// Encode using the terminal's current mode state
	opts := input.Options{
		cursor_key_application: state.term.modes.get(.cursor_keys)
		keypad_key_application: state.term.modes.get(.keypad_keys)
		alt_esc_prefix: state.term.modes.get(.alt_esc_prefix)
	}

	encoded := input.encode(event, opts)
	if encoded.len > 0 {
		C.write(state.pty_fd, encoded.str, usize(encoded.len))
	}
}

// ============================================================
// Resize callback — update terminal and PTY size
// ============================================================

fn on_resize(userdata voidptr, width f64, height f64) {
	if userdata == unsafe { nil } {
		return
	}
	mut state := unsafe { &TermState(userdata) }
	new_cols := int(width / state.cell_w)
	new_rows := int(height / state.cell_h)
	if new_cols <= 0 || new_rows <= 0 {
		return
	}
	if new_cols == state.cols && new_rows == state.rows {
		return
	}
	state.cols = new_cols
	state.rows = new_rows
	state.term.resize(u16(new_cols), u16(new_rows)) or {}
	if state.pty_fd >= 0 {
		mut p := pty.Pty{ master: state.pty_fd }
		p.set_size(pty.Winsize{
			ws_row: u16(new_rows)
			ws_col: u16(new_cols)
			ws_xpixel: u16(width)
			ws_ypixel: u16(height)
		}) or {}
	}
}

// ============================================================
// PTY read thread — reads shell output, feeds terminal
// ============================================================

fn read_pty_thread(fd int, view voidptr) {
	mut buf := [4096]u8{}
	for {
		n := C.read(fd, &buf[0], usize(4096))
		if n <= 0 {
			break
		}
		data := unsafe { tos(&buf[0], int(n)) }
		userdata := macos.view_get_userdata(view)
		if userdata != unsafe { nil } {
			mut state := unsafe { &TermState(userdata) }
			state.stream.next_slice(data) or {}
		}
		macos.request_display(view)
	}
}
