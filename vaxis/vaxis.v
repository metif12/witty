module vaxis

import encoding.base64
import os
import term
import term.termios
import time

// Color represents an RGB color.
pub struct Color {
pub:
	rgb [3]u8
}

// Scheme is the terminal's preferred light or dark color scheme.
pub enum Scheme {
	light
	dark
}

// Style represents text styling attributes.
pub struct Style {
pub:
	fg       Color
	bg       Color
	bold     bool
	italic   bool
	ul_style UnderlineStyle = .none_
}

pub enum UnderlineStyle {
	none_
	single
	double_
	dashed
	curly
	dotted
}

// Key represents one decoded terminal key event.
pub struct Key {
pub:
	codepoint u32
	mods      Modifiers
}

pub const escape = u32(0x1b)
pub const enter = u32(0x0d)
pub const backspace = u32(0x08)
pub const delete = u32(0x7f)
pub const tab = u32(0x09)
pub const kp_enter = u32(0x010d)
pub const f1 = u32(0x0101)
pub const home = u32(0x0106)
pub const kp_home = u32(0x0206)
pub const end = u32(0x0107)
pub const kp_end = u32(0x0207)
pub const down = u32(0x0108)
pub const kp_down = u32(0x0208)
pub const up = u32(0x0109)
pub const kp_up = u32(0x0209)
pub const page_down = u32(0x010a)
pub const page_up = u32(0x010b)
pub const kp_page_up = u32(0x020b)
pub const kp_add = u32(0x020c)
pub const kp_subtract = u32(0x020d)

pub struct Modifiers {
pub:
	ctrl  bool
	shift bool
}

pub fn (k Key) matches(cp u32, mods Modifiers) bool {
	return k.codepoint == cp && k.mods.ctrl == mods.ctrl && k.mods.shift == mods.shift
}

pub fn (k Key) matches_any(cps []u32, mods Modifiers) bool {
	for cp in cps {
		if k.matches(cp, mods) {
			return true
		}
	}
	return false
}

pub struct Mouse {
pub:
	button MouseButton
	type_  MouseType
	row    int
	col    int
}

pub enum MouseButton {
	none_
	left
	right
	wheel_up
	wheel_down
}

pub enum MouseType {
	press
	release
	motion
}

pub struct Winsize {
pub:
	rows u16
	cols u16
}

pub type InputEvent = Key | Mouse

struct ParsedInput {
	event    InputEvent
	consumed int
}

// Tty incrementally decodes keys and SGR mouse reports from stdin. The V
// terminal helper applies and restores non-canonical input around every poll,
// so callers don't leave the host terminal in a broken state after a crash.
pub struct Tty {
mut:
	pending         []u8
	escape_received u64
}

pub fn Tty.new() Tty {
	return Tty{
		pending: []u8{cap: 32}
	}
}

// poll returns one event when input is available and otherwise returns none.
pub fn (mut tty Tty) poll() ?InputEvent {
	$if !windows {
		// ISIG would turn Ctrl-C into SIGINT before the application can handle
		// it. Temporarily clear it while polling, then restore the exact state.
		mut old_state := termios.Termios{}
		if termios.tcgetattr(0, mut old_state) == 0 {
			mut raw_state := old_state
			raw_state.c_lflag &= termios.invert(termios.flag(1)) // POSIX ISIG
			termios.tcsetattr(0, C.TCSANOW, mut raw_state)
			defer {
				termios.tcsetattr(0, C.TCSANOW, mut old_state)
			}
		}
	}

	if tty.pending.len == 0 {
		raw := term.key_pressed(blocking: false, echo: false)
		if raw < 0 {
			return none
		}
		tty.append_raw(raw)
	} else {
		// Escape reports can arrive in more than one read. Give the terminal a
		// short opportunity to publish the remainder without blocking the UI.
		for {
			raw := term.key_pressed(blocking: false, echo: false)
			if raw < 0 {
				break
			}
			tty.append_raw(raw)
		}
	}

	if parsed := parse_input(tty.pending) {
		tty.pending.delete_many(0, parsed.consumed)
		if tty.pending.len == 0 {
			tty.escape_received = 0
		}
		return parsed.event
	}

	if tty.pending.len == 1 && tty.pending[0] == u8(escape) {
		now := time.sys_mono_now()
		if tty.escape_received == 0 {
			tty.escape_received = now
		} else if now - tty.escape_received >= 20 * u64(time.millisecond) {
			tty.pending.clear()
			tty.escape_received = 0
			return InputEvent(Key{
				codepoint: escape
			})
		}
	}
	return none
}

fn (mut tty Tty) append_raw(value i64) {
	mut raw := u64(value)
	for _ in 0 .. 8 {
		byte := u8(raw & 0xff)
		if byte == 0 {
			break
		}
		tty.pending << byte
		raw >>= 8
	}
}

fn parse_input(data []u8) ?ParsedInput {
	if data.len == 0 {
		return none
	}

	if data[0] == u8(escape) {
		if data.len == 1 {
			return none
		}
		if data[1] == `[` {
			return parse_csi(data)
		}
		if data.len >= 3 && data[1] == `O` {
			code := match data[2] {
				`P` { f1 }
				`A` { up }
				`B` { down }
				`H` { home }
				`F` { end }
				else { escape }
			}
			return ParsedInput{
				event: InputEvent(Key{
					codepoint: code
				})
				consumed: 3
			}
		}
		return ParsedInput{
			event: InputEvent(Key{
				codepoint: escape
			})
			consumed: 1
		}
	}

	byte := data[0]
	if byte > 0 && byte <= 26 {
		return ParsedInput{
			event: InputEvent(Key{
				codepoint: u32(`a` + byte - 1)
				mods: Modifiers{
					ctrl: true
				}
			})
			consumed: 1
		}
	}
	if byte == `\r` || byte == `\n` {
		return parsed_key(enter, Modifiers{}, 1)
	}
	if byte == 0x7f || byte == 0x08 {
		return parsed_key(backspace, Modifiers{}, 1)
	}
	if byte >= `A` && byte <= `Z` {
		return parsed_key(u32(byte + 32), Modifiers{
			shift: true
		}, 1)
	}

	char_len := utf8_sequence_length(byte)
	if data.len < char_len {
		return none
	}
	runes := data[..char_len].bytestr().runes()
	if runes.len == 0 {
		return parsed_key(u32(byte), Modifiers{}, 1)
	}
	return parsed_key(u32(runes[0]), Modifiers{}, char_len)
}

fn parse_csi(data []u8) ?ParsedInput {
	mut final_index := -1
	for i in 2 .. data.len {
		byte := data[i]
		if (byte >= `A` && byte <= `Z`) || (byte >= `a` && byte <= `z`) || byte == `~` {
			final_index = i
			break
		}
	}
	if final_index < 0 {
		return none
	}

	sequence := data[..final_index + 1].bytestr()
	if sequence.starts_with('\x1b[<') && (sequence.ends_with('M') || sequence.ends_with('m')) {
		parts := sequence[3..sequence.len - 1].split(';')
		if parts.len == 3 {
			button_code := parts[0].int()
			mut button := MouseButton.none_
			if button_code & 64 != 0 {
				button = if button_code & 1 == 0 { .wheel_up } else { .wheel_down }
			} else {
				button = match button_code & 3 {
					0 { .left }
					2 { .right }
					else { .none_ }
				}
			}
			type_ := if button_code & 32 != 0 {
				MouseType.motion
			} else if sequence.ends_with('m') {
				MouseType.release
			} else {
				MouseType.press
			}
			return ParsedInput{
				event: InputEvent(Mouse{
					button: button
					type_: type_
					row: max_int(parts[2].int() - 1, 0)
					col: max_int(parts[1].int() - 1, 0)
				})
				consumed: final_index + 1
			}
		}
	}

	code := match sequence {
		'\x1b[A' { up }
		'\x1b[B' { down }
		'\x1b[H', '\x1b[1~', '\x1b[7~' { home }
		'\x1b[F', '\x1b[4~', '\x1b[8~' { end }
		'\x1b[5~' { page_up }
		'\x1b[6~' { page_down }
		'\x1b[11~' { f1 }
		else { escape }
	}
	return parsed_key(code, Modifiers{}, final_index + 1)
}

fn parsed_key(codepoint u32, mods Modifiers, consumed int) ParsedInput {
	return ParsedInput{
		event: InputEvent(Key{
			codepoint: codepoint
			mods: mods
		})
		consumed: consumed
	}
}

fn utf8_sequence_length(first u8) int {
	if first & 0x80 == 0 {
		return 1
	}
	if first & 0xe0 == 0xc0 {
		return 2
	}
	if first & 0xf0 == 0xe0 {
		return 3
	}
	if first & 0xf8 == 0xf0 {
		return 4
	}
	return 1
}

// TextInput implements the editing behavior needed by the theme search box.
pub struct TextInput {
mut:
	text string
}

pub fn TextInput.new() TextInput {
	return TextInput{}
}

pub fn (mut t TextInput) deinit() {
	t.text = ''
}

pub fn (t TextInput) real_length() int {
	return t.text.runes().len
}

pub fn (t TextInput) get_text() string {
	return t.text
}

pub fn (mut t TextInput) clear_retaining_capacity() {
	t.text = ''
}

pub fn (mut t TextInput) update(key Key) {
	if key.codepoint == backspace || key.codepoint == delete {
		mut runes := t.text.runes()
		if runes.len > 0 {
			runes.delete_last()
			t.text = runes.string()
		}
		return
	}
	if key.mods.ctrl || key.codepoint < 0x20 || key.codepoint > 0x10ffff {
		return
	}
	t.text += rune(key.codepoint).str()
}

pub fn terminal_size() Winsize {
	cols, rows := term.get_terminal_size()
	return Winsize{
		rows: u16(max_int(rows, 1))
		cols: u16(max_int(cols, 1))
	}
}

pub fn detect_color_scheme() Scheme {
	parts := os.getenv('COLORFGBG').split(';')
	if parts.len > 0 {
		background := parts.last().int()
		if background >= 0 && background <= 6 {
			return .dark
		}
	}
	return .light
}

pub fn begin_session(title string) {
	print('\x1b[?1049h\x1b[?25l\x1b[?1003h\x1b[?1006h\x1b]0;${title}\a')
	flush_stdout()
}

pub fn end_session() {
	print('\x1b[?1006l\x1b[?1003l\x1b[?25h\x1b[0m\x1b[?1049l')
	flush_stdout()
}

pub fn clear_screen() string {
	return '\x1b[2J\x1b[H'
}

pub fn position(row int, col int) string {
	return '\x1b[${max_int(row, 0) + 1};${max_int(col, 0) + 1}H'
}

pub fn hide_cursor() string {
	return '\x1b[?25l'
}

pub fn show_cursor(row int, col int) string {
	return '${position(row, col)}\x1b[?25h'
}

pub fn styled(text string, style Style) string {
	mut codes := ['38;2;${style.fg.rgb[0]};${style.fg.rgb[1]};${style.fg.rgb[2]}',
		'48;2;${style.bg.rgb[0]};${style.bg.rgb[1]};${style.bg.rgb[2]}']
	if style.bold {
		codes << '1'
	}
	if style.italic {
		codes << '3'
	}
	match style.ul_style {
		.none_ {}
		.single { codes << '4' }
		.double_ { codes << '4:2' }
		.curly { codes << '4:3' }
		.dotted { codes << '4:4' }
		.dashed { codes << '4:5' }
	}
	return '\x1b[${codes.join(';')}m${text}\x1b[0m'
}

pub fn hyperlink(text string, uri string, style Style) string {
	return '\x1b]8;;${uri}\x1b\\${styled(text, style)}\x1b]8;;\x1b\\'
}

pub fn copy_to_system_clipboard(text string) {
	print('\x1b]52;c;${base64.encode_str(text)}\a')
	flush_stdout()
}

pub fn truncate(text string, width int) string {
	if width <= 0 {
		return ''
	}
	runes := text.runes()
	if runes.len <= width {
		return text
	}
	return runes[..width].string()
}

fn max_int(a int, b int) int {
	return if a > b { a } else { b }
}
