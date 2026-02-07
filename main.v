module main

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

// CoreGraphics / CoreText C functions for drawing.
fn C.CGContextSetRGBFillColor(ctx voidptr, r f64, g f64, b f64, a f64)
fn C.CGContextFillRect(ctx voidptr, rect C.CGRect)
fn C.CGContextSetTextMatrix(ctx voidptr, t C.CGAffineTransform)
fn C.CGContextSetTextPosition(ctx voidptr, x f64, y f64)
fn C.CTFontCreateWithName(name voidptr, size f64, matrix voidptr) voidptr
fn C.CTLineCreateWithAttributedString(attr_str voidptr) voidptr
fn C.CTLineDraw(line voidptr, ctx voidptr)
fn C.CFRelease(obj voidptr)
fn C.CFStringCreateWithCString(alloc voidptr, cstr &char, encoding u32) voidptr
fn C.CFAttributedStringCreate(alloc voidptr, str voidptr, attrs voidptr) voidptr
fn C.CFDictionaryCreate(alloc voidptr, keys &voidptr, values &voidptr, count isize, key_cbs voidptr, val_cbs voidptr) voidptr

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
// Global state — stored as C-side voidptr to avoid __global
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
	font      voidptr // CTFontRef
	cols      int = 80
	rows      int = 24
}

fn get_state() &TermState {
	ptr := macos.get_userdata()
	if ptr == unsafe { nil } {
		return unsafe { nil }
	}
	return unsafe { &TermState(ptr) }
}

fn main() {
	cols := u16(80)
	rows := u16(24)
	pixel_w := 640
	pixel_h := 384

	// 1. Init macOS app
	macos.app_init()

	// 2. Create terminal
	mut term := terminal.Terminal.init(terminal.Options{
		cols: cols
		rows: rows
	}) or {
		eprintln('terminal init failed: ${err}')
		return
	}

	// 3. Open PTY
	mut p := pty.Pty.open(pty.Winsize{
		ws_row: rows
		ws_col: cols
		ws_xpixel: u16(pixel_w)
		ws_ypixel: u16(pixel_h)
	}) or {
		eprintln('pty open failed: ${err}')
		return
	}

	// 4. Fork and exec the shell
	shell := os.getenv_opt('SHELL') or { '/bin/zsh' }
	pid := C.fork()
	if pid < 0 {
		eprintln('fork failed')
		return
	}
	if pid == 0 {
		// ---- Child process ----
		C.dup2(p.slave, 0)
		C.dup2(p.slave, 1)
		C.dup2(p.slave, 2)
		// Pre-exec pty setup (setsid, TIOCSCTTY, close master+slave)
		p.child_pre_exec() or {
			C._exit(1)
		}
		C.setenv(c'TERM', c'xterm-256color', 1)
		argv := [shell.str, unsafe { nil }]
		C.execvp(shell.str, argv.data)
		C._exit(1)
	}

	// ---- Parent process ----
	p.close_slave()

	// 5. Create CTFont for Menlo
	menlo_name := C.CFStringCreateWithCString(unsafe { nil }, c'Menlo', u32(0x08000100))
	ct_font := C.CTFontCreateWithName(menlo_name, 13.0, unsafe { nil })
	C.CFRelease(menlo_name)

	// 6. Set up global state
	mut stream := terminal.ReadonlyStream.init(mut term)
	mut state := &TermState{
		term: term
		stream: stream
		pty_fd: p.master
		child_pid: pid
		font: ct_font
		cols: int(cols)
		rows: int(rows)
	}
	macos.set_userdata(voidptr(state))

	// 7. Set callbacks
	macos.set_draw_callback(on_draw)
	macos.set_key_callback(on_key)
	macos.set_resize_callback(on_resize)

	// 8. Spawn read thread
	spawn read_pty_thread(p.master)

	// 9. Create window and run
	macos.create_window(pixel_w, pixel_h, 'vterminal')
	macos.app_run()
}

// ============================================================
// Draw callback — renders terminal grid via CoreGraphics
// ============================================================

fn on_draw(ctx voidptr, width f64, height f64) {
	mut state := get_state()
	if state == unsafe { nil } {
		return
	}

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

	font_key := macos.ct_font_attribute_name()

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

		// Null-terminate for CFStringCreateWithCString
		mut trimmed := row_str[..end].clone()
		trimmed << u8(0)

		cf_str := C.CFStringCreateWithCString(unsafe { nil }, trimmed.data, u32(0x08000100))
		if cf_str == unsafe { nil } {
			continue
		}

		// Create attributed string with our font
		keys := [font_key]
		vals := [state.font]
		attrs := C.CFDictionaryCreate(unsafe { nil }, keys.data, vals.data,
			isize(1), unsafe { nil }, unsafe { nil })

		attr_str := C.CFAttributedStringCreate(unsafe { nil }, cf_str, attrs)
		if attr_str != unsafe { nil } {
			line := C.CTLineCreateWithAttributedString(attr_str)
			if line != unsafe { nil } {
				y_pos := f64(row_idx) * cell_h + cell_h * 0.8
				C.CGContextSetTextPosition(ctx, 0.0, y_pos)
				C.CTLineDraw(line, ctx)
				C.CFRelease(line)
			}
			C.CFRelease(attr_str)
		}

		C.CFRelease(attrs)
		C.CFRelease(cf_str)
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
// Key callback — forward keystrokes to PTY
// ============================================================

fn on_key(chars &u8, len int) {
	state := get_state()
	if state == unsafe { nil } || state.pty_fd < 0 {
		return
	}
	C.write(state.pty_fd, chars, usize(len))
}

// ============================================================
// Resize callback — update terminal and PTY size
// ============================================================

fn on_resize(width f64, height f64) {
	mut state := get_state()
	if state == unsafe { nil } {
		return
	}
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

fn read_pty_thread(fd int) {
	mut buf := [4096]u8{}
	for {
		n := C.read(fd, &buf[0], usize(4096))
		if n <= 0 {
			break
		}
		data := unsafe { tos(&buf[0], int(n)) }
		mut state := get_state()
		if state != unsafe { nil } {
			state.stream.next_slice(data) or {}
		}
		macos.request_display()
	}
}
