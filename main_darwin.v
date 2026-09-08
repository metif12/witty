module main

import input
import internal_os
import macos
import os
import pty
import terminal
import time
import global_state

// C interop declarations needed in this module.
#include <unistd.h>

#include <signal.h>

#include <sys/wait.h>

fn C.fork() int

fn C.execvp(file &char, argv &&char) int

fn C.dup2(oldfd int, newfd int) int

fn C.close(fd int) int

fn C.read(fd int, buf voidptr, count usize) int

fn C.write(fd int, buf voidptr, count usize) int

fn C.kill(pid int, sig int) int

fn C.waitpid(pid int, status &int, options int) int

fn C._exit(status int)

fn C.setenv(name &char, value &char, overwrite int) int

// CoreGraphics C functions for drawing.
fn C.CGContextSetRGBFillColor(ctx voidptr, r f64, g f64, b f64, a f64)

fn C.CGContextFillRect(ctx voidptr, rect C.CGRect)

fn C.CGContextSetTextMatrix(ctx voidptr, t C.CGAffineTransform)

fn C.CGContextSetRGBStrokeColor(ctx voidptr, r f64, g f64, b f64, a f64)

fn C.CGContextSetLineWidth(ctx voidptr, width f64)

fn C.CGContextStrokeRect(ctx voidptr, rect C.CGRect)

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

// Encode a Unicode codepoint as UTF-8 bytes into buf.
fn encode_utf8(cp u32, mut buf []u8) {
	if cp < 0x80 {
		buf << u8(cp)
	} else if cp < 0x800 {
		buf << u8(0xC0 | (cp >> 6))
		buf << u8(0x80 | (cp & 0x3F))
	} else if cp < 0x10000 {
		buf << u8(0xE0 | (cp >> 12))
		buf << u8(0x80 | ((cp >> 6) & 0x3F))
		buf << u8(0x80 | (cp & 0x3F))
	} else {
		buf << u8(0xF0 | (cp >> 18))
		buf << u8(0x80 | ((cp >> 12) & 0x3F))
		buf << u8(0x80 | ((cp >> 6) & 0x3F))
		buf << u8(0x80 | (cp & 0x3F))
	}
}

fn clamp01(v f64) f64 {
	if v < 0.0 {
		return 0.0
	}
	if v > 1.0 {
		return 1.0
	}
	return v
}

// ============================================================
// Per-tab state
// ============================================================

@[heap]
struct TermState {
mut:
	term      &terminal.Terminal = unsafe { nil }
	stream    terminal.ReadonlyStream
	pty_fd    int = -1
	child_pid int = -1
	cell_w    f64 = 8.0
	cell_h    f64 = 16.0
	font      voidptr // CTFontRef (shared)
	cols      int = 80
	rows      int = 24
	view      voidptr // the VTTerminalView* for this tab
	// Mouse/selection state
	left_click_pin   ?terminal.Pin
	left_click_x     f64
	left_click_y     f64
	left_click_count u8
	left_click_time  u64
	// Title state: explicit OSC title wins; OSC 7 pwd is fallback when unset.
	tab_title  string
	seen_title bool
}

// Keep tab states alive for the process lifetime.
// AppKit stores userdata pointers in Objective-C objects; without a V-side
// strong reference, GC can reclaim TermState for non-primary tabs.
struct TabStateRegistry {
mut:
	states []&TermState
}

struct TabStateRegistrySingleton {
mut:
	reg TabStateRegistry
}

const tab_state_registry_instance = &TabStateRegistrySingleton{}

fn retain_tab_state(state &TermState) {
	mut reg := unsafe { &tab_state_registry_instance.reg }
	reg.states << state
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

fn default_tab_title() string {
	cwd := os.getwd()
	if cwd.len > 0 {
		return cwd
	}
	return 'Witty'
}

fn parse_osc7_pwd(url string) ?string {
	uri := internal_os.parse_uri(url, internal_os.UriParseOptions{
		raw_path: url.starts_with('kitty-shell-cwd://')
	}) or { return none }
	if uri.scheme != 'file' && uri.scheme != 'kitty-shell-cwd' {
		return none
	}
	if uri.host.len == 0 || !(internal_os.hostname_is_local(uri.host) or { false }) {
		return none
	}
	return uri.path
}

fn set_tab_title(mut state TermState, title string) {
	if state.tab_title == title {
		return
	}
	state.tab_title = title
	if state.view != unsafe { nil } {
		macos.set_view_title(state.view, title)
	}
}

fn apply_window_title(mut state TermState, title string) {
	if title.len >= 256 {
		return
	}
	// Empty title resets to pwd fallback (or blank if pwd is unknown).
	if title.len == 0 {
		state.seen_title = false
		mut pwd := state.term.get_pwd() or { '' }
		if pwd.len >= 256 {
			pwd = ''
		}
		set_tab_title(mut state, pwd)
		return
	}
	state.seen_title = true
	set_tab_title(mut state, title)
}

fn apply_report_pwd(mut state TermState, url string) {
	if url.len == 0 {
		state.term.set_pwd('') or {}
		if !state.seen_title {
			apply_window_title(mut state, '')
		}
		return
	}

	pwd := parse_osc7_pwd(url) or { return }
	state.term.set_pwd(pwd) or {}
	if !state.seen_title {
		set_tab_title(mut state, pwd)
	}
}

fn handle_stream_side_effects(mut state TermState, event terminal.StreamEvent) {
	match event.key {
		.window_title {
			apply_window_title(mut state, event.payload.str1)
		}
		.report_pwd {
			apply_report_pwd(mut state, event.payload.str1)
		}
		else {}
	}
}

// ============================================================
// spawn_terminal — creates a new terminal + PTY + child process
// ============================================================

fn spawn_terminal(cfg AppConfig) !&TermState {
	// Heap-allocate the Terminal via raw memdup so every byte is preserved.
	// Terminal contains ScreenSet which has a self-referential `active`
	// pointer into its own `primary` field. A V struct literal copy can
	// lose internal state, so we memdup the exact bytes then fix up
	// the one known self-referential pointer.
	mut init_term := terminal.Terminal.init(terminal.Options{
		cols: cfg.cols
		rows: cfg.rows
	})!
	mut term := unsafe { &terminal.Terminal(memdup(&init_term, int(sizeof(terminal.Terminal)))) }
	// Fix up the self-referential active pointer to point into the heap copy.
	term.screens.active = &term.screens.primary

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
		p.child_pre_exec() or { C._exit(1) }
		C.setenv(c'TERM', c'xterm-256color', 1)
		argv := [cfg.shell.str, unsafe { nil }]
		C.execvp(cfg.shell.str, argv.data)
		C._exit(1)
	}

	// ---- Parent process ----
	p.close_slave()

	mut state := &TermState{
		term: term
		pty_fd: p.master
		child_pid: pid
		font: cfg.font
		cols: int(cfg.cols)
		rows: int(cfg.rows)
	}
	// Construct ReadonlyStream manually. We cannot use ReadonlyStream.init()
	// because it takes Terminal by value, copies it, then stores &copy —
	// a dangling pointer. Instead we set the handler's terminal pointer
	// directly to our heap-allocated Terminal.
	state.stream = terminal.ReadonlyStream{
		handler: terminal.ReadonlyHandler{
			terminal: state.term
		}
		stream: terminal.Stream.init()
	}
	return state
}

// ============================================================
// main
// ============================================================

fn main() {
	mut global := global_state.get_state_mut()
	global.init() or {
		eprintln('invalid CLI invocation: ${err}')
		return
	}
	defer { global.deinit() }
	ghostty_cli_try_action()

	cfg := get_app_config()

	// 1. Init macOS app
	macos.app_init()

	// 2. Set callbacks (once — they dispatch via per-view userdata)
	macos.set_draw_callback(on_draw)
	macos.set_key_callback(on_key)
	macos.set_resize_callback(on_resize)
	macos.set_paste_callback(on_paste)
	macos.set_action_callback(on_action)
	macos.set_mouse_callback(on_mouse)

	// 3. Create window (first tab)
	view := macos.create_window(cfg.pixel_w, cfg.pixel_h, default_tab_title())

	// 4. Spawn terminal for this tab
	mut state := spawn_terminal(cfg) or {
		eprintln('terminal init failed: ${err}')
		return
	}
	state.view = view
	state.tab_title = default_tab_title()
	state.seen_title = false
	macos.view_set_userdata(view, voidptr(state))
	retain_tab_state(state)

	// 5. Spawn read thread for this tab

	// 6. Run the app
	spawn read_pty_thread(state.pty_fd, state.view)
	macos.app_run()
}

// ============================================================
// Tab actions
// ============================================================

fn do_new_tab() {
	cfg := get_app_config()
	view := macos.new_tab(cfg.pixel_w, cfg.pixel_h, default_tab_title())
	if view == unsafe { nil } {
		return
	}
	mut state := spawn_terminal(cfg) or {
		eprintln('new tab failed: ${err}')
		macos.close_tab(view)
		return
	}
	state.view = view
	state.tab_title = default_tab_title()
	state.seen_title = false
	macos.view_set_userdata(view, voidptr(state))
	retain_tab_state(state)
	spawn read_pty_thread(state.pty_fd, state.view)
}

fn do_close_tab(userdata voidptr) {
	if userdata == unsafe { nil } {
		return
	}
	mut state := unsafe { &TermState(userdata) }
	// Clear userdata first so the read thread and draw callback
	// see nil and bail out before we tear anything down.
	macos.view_set_userdata(state.view, unsafe { nil })
	if state.child_pid > 0 {
		// Ensure the child shell exits so any blocked PTY read wakes up.
		C.kill(state.child_pid, C.SIGHUP)
		C.kill(state.child_pid, C.SIGTERM)
		mut status := 0
		C.waitpid(state.child_pid, &status, C.WNOHANG)
		state.child_pid = -1
	}
	if state.pty_fd >= 0 {
		C.close(state.pty_fd)
		state.pty_fd = -1
	}
	macos.close_tab(state.view)
}

// ============================================================
// Draw callback — renders terminal grid via CoreGraphics
// Metal infrastructure is initialized on each view but not yet
// activated. When the Metal rendering pipeline is complete,
// call macos.metal_activate_layer(view) to switch from CGContext
// to Metal command buffers.
// ============================================================

fn on_draw(userdata voidptr, ctx voidptr, width f64, height f64) {
	if userdata == unsafe { nil } {
		return
	}
	mut state := unsafe { &TermState(userdata) }

	cell_w := state.cell_w
	cell_h := state.cell_h

	mut default_bg := terminal.RGB{
		r: 0x2b
		g: 0x31
		b: 0x3c
	}
	if bg := state.term.colors.background.get() {
		default_bg = bg
	}

	mut default_fg := terminal.RGB{
		r: 0xe6
		g: 0xe8
		b: 0xee
	}
	if fg := state.term.colors.foreground.get() {
		default_fg = fg
	}

	mut cursor_rgb := default_fg
	if cc := state.term.colors.cursor.get() {
		cursor_rgb = cc
	}

	// Fill background using terminal default background color.
	C.CGContextSetRGBFillColor(ctx, f64(default_bg.r) / 255.0, f64(default_bg.g) / 255.0, f64(default_bg.b) / 255.0, 1.0)
	C.CGContextFillRect(ctx, C.CGRect{
		origin: C.CGPoint{
			x: 0
			y: 0
		}
		size: C.CGSize{
			width: width
			height: height
		}
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

	palette := state.term.colors.palette.entries

	for row_idx in 0 .. num_rows {
		row := pages.get_active_row(u32(row_idx))

		// Draw background colors for cells that have non-default bg
		for col_idx in 0 .. num_cols {
			if col_idx >= row.cells.len {
				break
			}
			cell := row.cells[col_idx]
			bg := cell.style.bg_rgb(&cell, palette) or { continue }
			C.CGContextSetRGBFillColor(ctx, f64(bg.r) / 255.0, f64(bg.g) / 255.0, f64(bg.b) / 255.0, 1.0)
			C.CGContextFillRect(ctx, C.CGRect{
				origin: C.CGPoint{
					x: f64(col_idx) * cell_w
					y: f64(row_idx) * cell_h
				}
				size: C.CGSize{
					width: cell_w
					height: cell_h
				}
			})
		}

		// Draw text in colored runs: group consecutive cells with same fg color
		mut run_start := 0
		for run_start < num_cols {
			// Skip empty leading cells
			if run_start >= row.cells.len || row.cells[run_start].codepoint == 0 {
				run_start++
				continue
			}

			// Determine foreground color for this cell
			first_cell := row.cells[run_start]
			mut fg_r := f64(default_fg.r) / 255.0
			mut fg_g := f64(default_fg.g) / 255.0
			mut fg_b := f64(default_fg.b) / 255.0
			if first_cell.style.fg_color == .rgb {
				fg_r = f64(first_cell.style.fg_r) / 255.0
				fg_g = f64(first_cell.style.fg_g) / 255.0
				fg_b = f64(first_cell.style.fg_b) / 255.0
			} else if first_cell.style.fg_color == .palette {
				c := palette[int(first_cell.style.fg_palette)]
				fg_r = f64(c.r) / 255.0
				fg_g = f64(c.g) / 255.0
				fg_b = f64(c.b) / 255.0
			}

			// Collect consecutive cells with the same fg color
			mut run_buf := []u8{cap: num_cols * 4}
			cp := first_cell.codepoint
			if cp >= 32 {
				encode_utf8(cp, mut run_buf)
			}

			mut run_end := run_start + 1
			for run_end < num_cols && run_end < row.cells.len {
				cell := row.cells[run_end]
				if cell.codepoint == 0 {
					break
				}
				// Check if fg color matches the run
				if cell.style.fg_color != first_cell.style.fg_color {
					break
				}
				if cell.style.fg_color == .rgb && (cell.style.fg_r != first_cell.style.fg_r
					|| cell.style.fg_g != first_cell.style.fg_g
					|| cell.style.fg_b != first_cell.style.fg_b) {
					break
				}
				if cell.style.fg_color == .palette
					&& cell.style.fg_palette != first_cell.style.fg_palette {
					break
				}
				c2 := cell.codepoint
				if c2 >= 32 {
					encode_utf8(c2, mut run_buf)
				}
				run_end++
			}

			// Draw this run
			if run_buf.len > 0 {
				y_pos := f64(row_idx) * cell_h + cell_h * 0.8
				x_pos := f64(run_start) * cell_w
				macos.draw_text(ctx, run_buf.data, run_buf.len, state.font, x_pos, y_pos, fg_r, fg_g, fg_b)
			}

			run_start = run_end
		}
	}

	// Draw selection highlight
	if sel := state.term.screens.active.selection {
		sel_start := if sel.start_pin.before(sel.end_pin) { sel.start_pin } else { sel.end_pin }
		sel_end := if sel.start_pin.before(sel.end_pin) { sel.end_pin } else { sel.start_pin }

		for sy in int(sel_start.y) .. int(sel_end.y) + 1 {
			if sy >= num_rows {
				break
			}
			sx_start := if sy == int(sel_start.y) { int(sel_start.x) } else { 0 }
			sx_end := if sy == int(sel_end.y) { int(sel_end.x) + 1 } else { num_cols }

			base_r := f64(default_bg.r) / 255.0
			base_g := f64(default_bg.g) / 255.0
			base_b := f64(default_bg.b) / 255.0
			C.CGContextSetRGBFillColor(ctx, clamp01(base_r + 0.20), clamp01(base_g + 0.20), clamp01(base_b + 0.30), 0.55)
			C.CGContextFillRect(ctx, C.CGRect{
				origin: C.CGPoint{
					x: f64(sx_start) * cell_w
					y: f64(sy) * cell_h
				}
				size: C.CGSize{
					width: f64(sx_end - sx_start) * cell_w
					height: cell_h
				}
			})
		}
	}

	// Draw cursor using terminal cursor style and color.
	if state.term.modes.get(.cursor_visible) {
		cx := state.term.screens.active.cursor.x
		cy := state.term.screens.active.cursor.y
		x := f64(cx) * cell_w
		y := f64(cy) * cell_h
		cursor_style := state.term.screens.active.cursor.cursor_style
		cr := f64(cursor_rgb.r) / 255.0
		cg := f64(cursor_rgb.g) / 255.0
		cb := f64(cursor_rgb.b) / 255.0

		match cursor_style {
			.block {
				C.CGContextSetRGBFillColor(ctx, cr, cg, cb, 0.90)
				C.CGContextFillRect(ctx, C.CGRect{
					origin: C.CGPoint{
						x: x
						y: y
					}
					size: C.CGSize{
						width: cell_w
						height: cell_h
					}
				})
			}
			.block_hollow {
				C.CGContextSetRGBStrokeColor(ctx, cr, cg, cb, 0.95)
				C.CGContextSetLineWidth(ctx, 1.5)
				C.CGContextStrokeRect(ctx, C.CGRect{
					origin: C.CGPoint{
						x: x + 0.5
						y: y + 0.5
					}
					size: C.CGSize{
						width: cell_w - 1.0
						height: cell_h - 1.0
					}
				})
			}
			.bar {
				bar_w := if cell_w * 0.12 < 1.5 { 1.5 } else { cell_w * 0.12 }
				C.CGContextSetRGBFillColor(ctx, cr, cg, cb, 0.95)
				C.CGContextFillRect(ctx, C.CGRect{
					origin: C.CGPoint{
						x: x
						y: y
					}
					size: C.CGSize{
						width: bar_w
						height: cell_h
					}
				})
			}
			.underline {
				line_h := if cell_h * 0.10 < 1.5 { 1.5 } else { cell_h * 0.10 }
				C.CGContextSetRGBFillColor(ctx, cr, cg, cb, 0.95)
				C.CGContextFillRect(ctx, C.CGRect{
					origin: C.CGPoint{
						x: x
						y: y + cell_h - line_h
					}
					size: C.CGSize{
						width: cell_w
						height: line_h
					}
				})
			}
		}
	}
}

// ============================================================
// Key callback — encode key events and write to PTY
// ============================================================

// macOS NSEvent modifier flag masks
const ns_shift_mask = u64(1 << 17)
const ns_ctrl_mask = u64(1 << 18)
const ns_alt_mask = u64(1 << 19)
const ns_cmd_mask = u64(1 << 20)

fn on_key(userdata voidptr, key_action macos.KeyEventAction, keycode u16, modflags u64, chars &u8, len int, uchars &u8, ulen int) {
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
		if runes.len > 0 {
			u32(runes[0])
		} else {
			u32(0)
		}
	} else {
		u32(0)
	}

	// Determine consumed mods (shift is consumed if text differs from unshifted)
	consumed := input.Mods{
		shift: mods.shift && utf8_text != unshifted_text
	}

	action := match key_action {
		.press { input.KeyAction.press }
		.repeat { input.KeyAction.repeat }
		.release { input.KeyAction.release }
	}

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
// Menu action constants (must match VT_ACTION_* in appkit.m)
// ============================================================

const vt_action_copy = 1
const vt_action_select_all = 2
const vt_action_new_tab = 3
const vt_action_close_tab = 4

// ============================================================
// Paste callback — write pasted text to PTY
// ============================================================

fn on_paste(userdata voidptr, text &u8, len int) {
	if userdata == unsafe { nil } {
		return
	}
	state := unsafe { &TermState(userdata) }
	if state.pty_fd < 0 || len <= 0 {
		return
	}
	if state.term.modes.get(.bracketed_paste) {
		start := '\x1b[200~'
		finish := '\x1b[201~'
		C.write(state.pty_fd, start.str, usize(start.len))
		C.write(state.pty_fd, text, usize(len))
		C.write(state.pty_fd, finish.str, usize(finish.len))
		return
	}
	C.write(state.pty_fd, text, usize(len))
}

// ============================================================
// Menu action callback — handle Copy, Select All, New/Close Tab
// ============================================================

fn on_action(userdata voidptr, action_id int) {
	if userdata == unsafe { nil } {
		return
	}
	mut state := unsafe { &TermState(userdata) }
	mut screen := unsafe { state.term.screens.active }
	match action_id {
		vt_action_copy {
			if sel := screen.selection {
				text := screen.selection_string(terminal.SelectionString{
					sel: sel
					trim: true
				}) or { return }
				if text.len > 0 {
					macos.clipboard_set_text(text)
				}
			}
		}
		vt_action_select_all {
			if sel := screen.select_all() {
				screen.select(sel) or {}
				macos.request_display(state.view)
			}
		}
		vt_action_new_tab {
			do_new_tab()
		}
		vt_action_close_tab {
			do_close_tab(userdata)
		}
		else {}
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
		mut p := pty.Pty{
			master: state.pty_fd
		}
		p.set_size(pty.Winsize{
			ws_row: u16(new_rows)
			ws_col: u16(new_cols)
			ws_xpixel: u16(width)
			ws_ypixel: u16(height)
		}) or {}
	}
}

// ============================================================
// Mouse callback — handle mouse events for selection
// ============================================================

// Mouse event types (must match appkit.m)
const mouse_left_down = 0
const mouse_left_up = 1
const mouse_left_dragged = 2
const mouse_right_down = 3
const mouse_right_up = 4

// Double-click timing threshold in milliseconds
const double_click_interval_ms = 500

fn on_mouse(userdata voidptr, event_type int, x f64, y f64, modflags u64) {
	if userdata == unsafe { nil } {
		return
	}
	mut state := unsafe { &TermState(userdata) }

	// Convert pixel coordinates to cell coordinates
	col := int(x / state.cell_w)
	row := int(y / state.cell_h)
	if col < 0 || row < 0 || col >= state.cols || row >= state.rows {
		// Allow dragging outside bounds for edge selection
		if event_type != mouse_left_dragged {
			return
		}
	}
	clamped_col := if col < 0 {
		0
	} else if col >= state.cols {
		state.cols - 1
	} else {
		col
	}
	clamped_row := if row < 0 {
		0
	} else if row >= state.rows {
		state.rows - 1
	} else {
		row
	}
	pin := terminal.Pin{
		x: u32(clamped_col)
		y: u32(clamped_row)
	}

	match event_type {
		mouse_left_down {
			now := time.sys_mono_now()
			elapsed := now - state.left_click_time

			// Check for multi-click (within timing threshold and same approximate position)
			if elapsed < u64(double_click_interval_ms * time.millisecond) {
				state.left_click_count += 1
			} else {
				state.left_click_count = 1
			}
			state.left_click_time = now
			state.left_click_pin = pin
			state.left_click_x = x
			state.left_click_y = y

			mut screen := unsafe { state.term.screens.active }

			if state.left_click_count == 2 {
				// Double-click: select word
				boundary := [u32(` `), u32(`\t`), u32(`"`), u32(`'`), u32(`(`), u32(`)`), u32(`[`),
					u32(`]`), u32(`{`), u32(`}`), u32(`<`), u32(`>`), u32(`,`), u32(`;`), u32(`:`)]
				if sel := screen.select_word(pin, boundary) {
					screen.select(sel) or {}
				}
			} else if state.left_click_count >= 3 {
				// Triple-click: select line
				if sel := screen.select_line(terminal.SelectLine{ pin: pin }) {
					screen.select(sel) or {}
				}
			} else {
				// Single-click: clear existing selection
				screen.clear_selection()
			}

			macos.request_display(state.view)
		}
		mouse_left_dragged {
			if state.left_click_count == 0 {
				return
			}
			click_pin := state.left_click_pin or { return }
			mut screen := unsafe { state.term.screens.active }

			if state.left_click_count == 1 {
				// Single-click drag: character-level selection
				if !click_pin.eql(pin) {
					start := if pin.before(click_pin) { pin } else { click_pin }
					end := if pin.before(click_pin) { click_pin } else { pin }
					sel := terminal.Selection.init(start, end, false)
					screen.select(sel) or {}
				}
			} else if state.left_click_count == 2 {
				// Double-click drag: word-level selection
				boundary := [u32(` `), u32(`\t`), u32(`"`), u32(`'`), u32(`(`), u32(`)`), u32(`[`),
					u32(`]`), u32(`{`), u32(`}`), u32(`<`), u32(`>`), u32(`,`), u32(`;`), u32(`:`)]
				if sel := screen.select_word_between(click_pin, pin, boundary) {
					screen.select(sel) or {}
				}
			} else if state.left_click_count >= 3 {
				// Triple-click drag: line-level selection
				if sel := screen.select_line(terminal.SelectLine{ pin: pin }) {
					screen.select(sel) or {}
				}
			}

			macos.request_display(state.view)
		}
		mouse_left_up {
			// Copy selection to clipboard on mouse up (copy-on-select)
			mut screen := unsafe { state.term.screens.active }
			if sel := screen.selection {
				text := screen.selection_string(terminal.SelectionString{
					sel: sel
					trim: true
				}) or { return }
				if text.len > 0 {
					macos.clipboard_set_text(text)
				}
			}
		}
		else {}
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
		if userdata == unsafe { nil } {
			break
		}
		mut state := unsafe { &TermState(userdata) }
		state.stream.stream.next_slice(data.bytes())
		for event in state.stream.stream.events {
			state.stream.handler.vt(event) or {}
			handle_stream_side_effects(mut state, event)
		}
		state.stream.stream.clear_events()
		macos.request_display(view)
	}
}
