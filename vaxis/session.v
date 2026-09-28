module vaxis

import os
import strings
import datastruct
import sync
import sync.stdatomic

pub struct Capabilities {
pub mut:
	kitty_keyboard       bool
	kitty_graphics       bool
	rgb                  bool
	unicode              GWidthMethod = .wcwidth
	sgr_pixels           bool
	color_scheme_updates bool
	explicit_width       bool
	scaled_text          bool
	multi_cursor         bool
}

pub struct VaxisOptions {
pub:
	kitty_keyboard_flags KittyFlags = KittyFlags{}
	system_clipboard     bool
}

pub enum SgrMode as u8 {
	standard
	legacy
}

pub struct SessionCursor {
pub mut:
	row u16
	col u16
}

pub struct VaxisState {
pub mut:
	alt_screen           bool
	kitty_keyboard       bool
	bracketed_paste      bool
	mouse                bool
	pixel_mouse          bool
	color_scheme_updates bool
	in_band_resize       bool
	changed_default_fg   bool
	changed_default_bg   bool
	changed_cursor_color bool
	cursor               SessionCursor
}

@[heap]
pub struct Vaxis {
pub mut:
	screen             Screen
	screen_last        InternalScreen
	caps               Capabilities
	opts               VaxisOptions
	refresh            bool
	queries_done       &stdatomic.AtomicVal[bool] = unsafe { nil }
	query_lock         &sync.Mutex = unsafe { nil }
	query_condition    datastruct.Condition
	next_img_id        u32                        = 1
	sgr                SgrMode                    = .standard
	enable_workarounds bool                       = true
	state              VaxisState
}

pub fn Vaxis.new(opts VaxisOptions) Vaxis {
	return Vaxis{
		opts:         opts
		screen:       Screen{}
		screen_last:  InternalScreen.new(0, 0)
		queries_done: stdatomic.new_atomic(true)
		query_lock: sync.new_mutex()
		query_condition: datastruct.Condition.init()
	}
}

pub fn (mut vx Vaxis) deinit() string {
	sequence := vx.reset_state()
	vx.screen.deinit()
	vx.screen_last.deinit()
	vx.query_condition.deinit()
	vx.query_lock.destroy()
	return sequence
}

pub fn (mut vx Vaxis) reset_state() string {
	mut out := strings.new_builder(128)
	out.write_string('\x1b[?25h\x1b[m')
	if vx.screen.cursor_shape != .default {
		out.write_string('\x1b[0 q')
	}
	if vx.state.kitty_keyboard {
		out.write_string('\x1b[<u')
		vx.state.kitty_keyboard = false
	}
	if vx.state.mouse {
		out.write_string(vx.set_mouse_mode(false))
	}
	if vx.state.bracketed_paste {
		out.write_string(vx.set_bracketed_paste(false))
	}
	if vx.state.alt_screen {
		out.write_string('\x1b[H\x1b[J')
		out.write_string(vx.exit_alt_screen())
	} else {
		out.write_string('\r')
		for _ in 0 .. int(vx.state.cursor.row) {
			out.write_string('\x1bM')
		}
		out.write_string('\x1b[J')
	}
	if vx.state.color_scheme_updates {
		out.write_string('\x1b[?2031l')
		vx.state.color_scheme_updates = false
	}
	if vx.state.in_band_resize {
		out.write_string('\x1b[?2048l')
		vx.state.in_band_resize = false
	}
	if vx.state.changed_default_fg {
		out.write_string('\x1b]110\x1b\\')
		vx.state.changed_default_fg = false
	}
	if vx.state.changed_default_bg {
		out.write_string('\x1b]111\x1b\\')
		vx.state.changed_default_bg = false
	}
	if vx.state.changed_cursor_color {
		out.write_string('\x1b]112\x1b\\')
		vx.state.changed_cursor_color = false
	}
	return out.str()
}

pub fn (mut vx Vaxis) resize(winsize Winsize) string {
	vx.screen.deinit()
	vx.screen = Screen.new(winsize)
	vx.screen.width_method = vx.caps.unicode
	vx.screen_last.deinit()
	vx.screen_last = InternalScreen.new(winsize.cols, winsize.rows)
	mut out := strings.new_builder(64)
	if vx.state.alt_screen {
		out.write_string('\x1b[H')
	} else {
		for _ in 0 .. int(vx.state.cursor.row) {
			out.write_string('\x1bM')
		}
		out.write_string('\r')
	}
	vx.state.cursor.row = 0
	vx.state.cursor.col = 0
	out.write_string('\x1b[m\x1b[J')
	return out.str()
}

pub fn (mut vx Vaxis) window() Window {
	return Window.new(&vx.screen)
}

pub fn (mut vx Vaxis) enter_alt_screen() string {
	vx.state.alt_screen = true
	return '\x1b[?1049h'
}

pub fn (mut vx Vaxis) exit_alt_screen() string {
	vx.state.alt_screen = false
	return '\x1b[?1049l'
}

// This is the exact pinned queryTerminalSend sequence. The TTY loop handles
// responses and wakes the query wait on the DA1 report.
pub fn (mut vx Vaxis) query_terminal_send() string {
	vx.queries_done.store(false)
	return '\x1b[?1016$p\x1b[?2027$p\x1b[?2031$p\x1b[?2048h' +
		'\x1b[H\x1b]66;w=1; \x1b\\\x1b[6n' +
		'\x1b[H\x1b]66;s=2; \x1b\\\x1b[> q\x1b[6n' +
		'\x1b[>0q\x1b[?u\x1b_Gi=1,a=q\x1b\\\x1b[c'
}

// query_terminal is pinned vaxis' blocking capability probe. The DA1 reader
// callback signals the condition; application events stay in the loop queue.
pub fn (mut vx Vaxis) query_terminal(mut tty Tty, timeout_ns u64) ! {
	tty.write(vx.query_terminal_send())!
	vx.query_lock.lock()
	vx.query_condition.timed_wait(mut vx.query_lock, timeout_ns) or {}
	vx.query_lock.unlock()
	vx.queries_done.store(true)
	tty.write(vx.enable_detected_features())!
}

pub fn (mut vx Vaxis) enable_detected_features() string {
	mut out := strings.new_builder(32)
	$if windows {
		vx.sgr = .legacy
	} $else {
		if _ := os.getenv_opt('TERMUX_VERSION') {
			vx.sgr = .legacy
		}
		if _ := os.getenv_opt('VHS_RECORD') {
			vx.caps.unicode = .wcwidth
			vx.caps.kitty_keyboard = false
			vx.sgr = .legacy
		}
		if os.getenv('TERM_PROGRAM') == 'vscode' {
			vx.sgr = .legacy
		}
		if _ := os.getenv_opt('VAXIS_FORCE_LEGACY_SGR') {
			vx.sgr = .legacy
		}
		if _ := os.getenv_opt('VAXIS_FORCE_WCWIDTH') {
			vx.caps.unicode = .wcwidth
		}
		if _ := os.getenv_opt('VAXIS_FORCE_UNICODE') {
			vx.caps.unicode = .unicode
		}
		if vx.caps.kitty_keyboard {
			out.write_string('\x1b[>${vx.opts.kitty_keyboard_flags.int()}u')
			vx.state.kitty_keyboard = true
		}
		if vx.caps.unicode == .unicode && !vx.caps.explicit_width {
			out.write_string('\x1b[?2027h')
		}
	}
	return out.str()
}

pub fn (mut vx Vaxis) queue_refresh() {
	vx.refresh = true
}

pub fn (mut vx Vaxis) set_bracketed_paste(enable bool) string {
	vx.state.bracketed_paste = enable
	return if enable { '\x1b[?2004h' } else { '\x1b[?2004l' }
}

pub fn (mut vx Vaxis) set_mouse_shape(shape MouseShape) {
	vx.screen.mouse_shape = shape
}

pub fn (mut vx Vaxis) set_mouse_mode(enable bool) string {
	if enable {
		vx.state.mouse = true
		if vx.caps.sgr_pixels {
			vx.state.pixel_mouse = true
			return '\x1b[?1002;1003;1004;1016h'
		}
		return '\x1b[?1002;1003;1004;1006h'
	}
	return '\x1b[?1002;1003;1004;1006;1016l'
}

pub fn (vx &Vaxis) translate_mouse(mouse Mouse) Mouse {
	if vx.screen.width == 0 || vx.screen.height == 0 {
		return mouse
	}
	if vx.state.pixel_mouse {
		assert mouse.xoffset == 0
		assert mouse.yoffset == 0
		xextra := vx.screen.width_pix % vx.screen.width
		yextra := vx.screen.height_pix % vx.screen.height
		xcell := (vx.screen.width_pix - xextra) / vx.screen.width
		ycell := (vx.screen.height_pix - yextra) / vx.screen.height
		if xcell == 0 || ycell == 0 {
			return mouse
		}
		return Mouse{
			button:  mouse.button
			type_:   mouse.type_
			col:     mouse.col / xcell
			row:     mouse.row / ycell
			xoffset: mouse.col % xcell
			yoffset: mouse.row % ycell
			mods:    mouse.mods
		}
	}
	return mouse
}
