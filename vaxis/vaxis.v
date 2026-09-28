module vaxis

import encoding.base64
import os
import strconv
import term
import term.termios
import unicode

// Color represents an RGB color.
pub struct Color {
pub:
	rgb [3]u8
}

// Scheme is the terminal's preferred light or dark color scheme.
pub enum Scheme as u8 {
	dark
	light
}

// Style represents text styling attributes.
pub struct Style {
pub:
	fg       Color
	bg       Color
	bold     bool
	italic   bool
	ul_style UnderlineStyle = .off
}

pub enum UnderlineStyle as u8 {
	off
	single
	double_
	curly
	dotted
	dashed
}

// Modifiers retains vaxis' packed u8 modifier ABI.
pub struct Modifiers {
mut:
	value u8
}

pub fn Modifiers.init(shift bool, alt bool, ctrl bool, super_ bool, hyper bool, meta bool, caps_lock bool, num_lock bool) Modifiers {
	return Modifiers{
		value: u8(shift) | (u8(alt) << 1) | (u8(ctrl) << 2) | (u8(super_) << 3) |
			(u8(hyper) << 4) | (u8(meta) << 5) | (u8(caps_lock) << 6) | (u8(num_lock) << 7)
	}
}

pub fn Modifiers.from_int(value u8) Modifiers {
	return Modifiers{
		value: value
	}
}

pub fn (m Modifiers) int() u8 {
	return m.value
}

pub fn (m Modifiers) eql(other Modifiers) bool {
	return m.value == other.value
}

pub fn (m Modifiers) shift() bool {
	return m.value & 1 != 0
}

pub fn (m Modifiers) alt() bool {
	return m.value & 2 != 0
}

pub fn (m Modifiers) ctrl() bool {
	return m.value & 4 != 0
}

pub fn (m Modifiers) super_() bool {
	return m.value & 8 != 0
}

pub fn (m Modifiers) hyper() bool {
	return m.value & 16 != 0
}

pub fn (m Modifiers) meta() bool {
	return m.value & 32 != 0
}

pub fn (m Modifiers) caps_lock() bool {
	return m.value & 64 != 0
}

pub fn (m Modifiers) num_lock() bool {
	return m.value & 128 != 0
}

pub fn (mut m Modifiers) set_shift(value bool) {
	m.set(1, value)
}

pub fn (mut m Modifiers) set_alt(value bool) {
	m.set(2, value)
}

pub fn (mut m Modifiers) set_ctrl(value bool) {
	m.set(4, value)
}

pub fn (mut m Modifiers) set_super(value bool) {
	m.set(8, value)
}

pub fn (mut m Modifiers) set_hyper(value bool) {
	m.set(16, value)
}

pub fn (mut m Modifiers) set_meta(value bool) {
	m.set(32, value)
}

pub fn (mut m Modifiers) set_caps_lock(value bool) {
	m.set(64, value)
}

pub fn (mut m Modifiers) set_num_lock(value bool) {
	m.set(128, value)
}

fn (mut m Modifiers) set(mask u8, value bool) {
	if value {
		m.value |= mask
	} else {
		m.value &= ~mask
	}
}

// KittyFlags retains vaxis' packed u5 flag ABI in the low five bits.
pub struct KittyFlags {
	value u8 = 0b11101
}

pub fn KittyFlags.init(disambiguate bool, report_events bool, report_alternate_keys bool, report_all_as_ctl_seqs bool, report_text bool) KittyFlags {
	return KittyFlags{
		value: (u8(disambiguate) | (u8(report_events) << 1) |
			(u8(report_alternate_keys) << 2) | (u8(report_all_as_ctl_seqs) << 3) |
			(u8(report_text) << 4)) & 0x1f
	}
}

pub fn KittyFlags.from_int(value u8) KittyFlags {
	return KittyFlags{
		value: value & 0x1f
	}
}

pub fn (f KittyFlags) int() u8 {
	return f.value
}

pub fn (f KittyFlags) disambiguate() bool {
	return f.value & 1 != 0
}

pub fn (f KittyFlags) report_events() bool {
	return f.value & 2 != 0
}

pub fn (f KittyFlags) report_alternate_keys() bool {
	return f.value & 4 != 0
}

pub fn (f KittyFlags) report_all_as_ctl_seqs() bool {
	return f.value & 8 != 0
}

pub fn (f KittyFlags) report_text() bool {
	return f.value & 16 != 0
}

// Key represents one decoded terminal key event. V has no u21 integer type,
// so codepoints use u32 while retaining vaxis' u21 value domain.
pub struct Key {
pub mut:
	codepoint             u32
	text                  ?string
	shifted_codepoint     ?u32
	base_layout_codepoint ?u32
	mods                  Modifiers
}

// matches follows vaxis' three matching rules: exact, generated text, then
// shifted codepoint.
pub fn (k Key) matches(cp u32, mods Modifiers) bool {
	if k.match_exact(cp, mods) {
		return true
	}
	if k.match_text(cp, mods) {
		return true
	}
	return k.match_shifted_codepoint(cp, mods)
}

pub fn (k Key) matches_any(cps []u32, mods Modifiers) bool {
	for cp in cps {
		if k.matches(cp, mods) {
			return true
		}
	}
	return false
}

pub fn (k Key) match_shortcut(cp u32, mods Modifiers) bool {
	base := k.base_layout_codepoint or { return false }
	return cp == base && k.mods.eql(mods)
}

pub fn (k Key) match_shifted_codepoint(cp u32, mods Modifiers) bool {
	shifted := k.shifted_codepoint or { return false }
	if !k.mods.shift() {
		return false
	}
	mut self_mods := k.mods
	self_mods.set_shift(false)
	self_mods.set_caps_lock(false)
	self_mods.set_num_lock(false)
	// This deliberately compares against `mods`, matching pinned vaxis. The
	// source also constructs a lock-stripped target but does not use it.
	return cp == shifted && self_mods.eql(mods)
}

pub fn (k Key) match_text(cp u32, mods Modifiers) bool {
	text := k.text or { return false }
	mut self_mods := k.mods
	self_mods.set_num_lock(false)
	self_mods.set_shift(false)
	self_mods.set_caps_lock(false)
	mut arg_mods := mods
	mut text_cp := cp
	if cp < 128 && (mods.shift() || mods.caps_lock()) && cp >= `a` && cp <= `z` {
		text_cp -= 32
	}
	arg_mods.set_num_lock(false)
	arg_mods.set_shift(false)
	arg_mods.set_caps_lock(false)
	if text_cp > 0x10ffff || (text_cp >= 0xd800 && text_cp <= 0xdfff) {
		return false
	}
	return text == rune(text_cp).str() && self_mods.eql(arg_mods)
}

pub fn (k Key) match_exact(cp u32, mods Modifiers) bool {
	mut self_mods := k.mods
	self_mods.set_caps_lock(false)
	self_mods.set_num_lock(false)
	mut target_mods := mods
	target_mods.set_caps_lock(false)
	target_mods.set_num_lock(false)
	return k.codepoint == cp && self_mods.eql(target_mods)
}

pub fn (k Key) is_modifier() bool {
	return k.codepoint in [left_shift, left_alt, left_super, left_hyper, left_control, left_meta,
		right_shift, right_alt, right_super, right_hyper, right_control, right_meta]
}

pub const tab = u32(0x09)
pub const enter = u32(0x0d)
pub const escape = u32(0x1b)
pub const space = u32(0x20)
pub const backspace = u32(0x7f)
pub const multicodepoint = u32(1_114_113)
pub const insert = u32(57348)
pub const delete = u32(57349)
pub const left = u32(57350)
pub const right = u32(57351)
pub const up = u32(57352)
pub const down = u32(57353)
pub const page_up = u32(57354)
pub const page_down = u32(57355)
pub const home = u32(57356)
pub const end = u32(57357)
pub const caps_lock = u32(57358)
pub const scroll_lock = u32(57359)
pub const num_lock = u32(57360)
pub const print_screen = u32(57361)
pub const pause = u32(57362)
pub const menu = u32(57363)
pub const f1 = u32(57364)
pub const f2 = u32(57365)
pub const f3 = u32(57366)
pub const f4 = u32(57367)
pub const f5 = u32(57368)
pub const f6 = u32(57369)
pub const f7 = u32(57370)
pub const f8 = u32(57371)
pub const f9 = u32(57372)
pub const f10 = u32(57373)
pub const f11 = u32(57374)
pub const f12 = u32(57375)
pub const f13 = u32(57376)
pub const f14 = u32(57377)
pub const f15 = u32(57378)
pub const f16 = u32(57379)
pub const f17 = u32(57380)
pub const f18 = u32(57381)
pub const f19 = u32(57382)
pub const f20 = u32(57383)
pub const f21 = u32(57384)
pub const f22 = u32(57385)
pub const f23 = u32(57386)
pub const f24 = u32(57387)
pub const f25 = u32(57388)
pub const f26 = u32(57389)
pub const f27 = u32(57390)
pub const f28 = u32(57391)
pub const f29 = u32(57392)
pub const f30 = u32(57393)
pub const f31 = u32(57394)
// V reserves `f32` as a type name, so this is the source `f32` key constant.
pub const f32_key = u32(57395)
pub const f33 = u32(57396)
pub const f34 = u32(57397)
pub const f35 = u32(57398)
pub const kp_0 = u32(57399)
pub const kp_1 = u32(57400)
pub const kp_2 = u32(57401)
pub const kp_3 = u32(57402)
pub const kp_4 = u32(57403)
pub const kp_5 = u32(57404)
pub const kp_6 = u32(57405)
pub const kp_7 = u32(57406)
pub const kp_8 = u32(57407)
pub const kp_9 = u32(57408)
pub const kp_decimal = u32(57409)
pub const kp_divide = u32(57410)
pub const kp_multiply = u32(57411)
pub const kp_subtract = u32(57412)
pub const kp_add = u32(57413)
pub const kp_enter = u32(57414)
pub const kp_equal = u32(57415)
pub const kp_separator = u32(57416)
pub const kp_left = u32(57417)
pub const kp_right = u32(57418)
pub const kp_up = u32(57419)
pub const kp_down = u32(57420)
pub const kp_page_up = u32(57421)
pub const kp_page_down = u32(57422)
pub const kp_home = u32(57423)
pub const kp_end = u32(57424)
pub const kp_insert = u32(57425)
pub const kp_delete = u32(57426)
pub const kp_begin = u32(57427)
pub const media_play = u32(57428)
pub const media_pause = u32(57429)
pub const media_play_pause = u32(57430)
pub const media_reverse = u32(57431)
pub const media_stop = u32(57432)
pub const media_fast_forward = u32(57433)
pub const media_rewind = u32(57434)
pub const media_track_next = u32(57435)
pub const media_track_previous = u32(57436)
pub const media_record = u32(57437)
pub const lower_volume = u32(57438)
pub const raise_volume = u32(57439)
pub const mute_volume = u32(57440)
pub const left_shift = u32(57441)
pub const left_control = u32(57442)
pub const left_alt = u32(57443)
pub const left_super = u32(57444)
pub const left_hyper = u32(57445)
pub const left_meta = u32(57446)
pub const right_shift = u32(57447)
pub const right_control = u32(57448)
pub const right_alt = u32(57449)
pub const right_super = u32(57450)
pub const right_hyper = u32(57451)
pub const right_meta = u32(57452)
pub const iso_level_3_shift = u32(57453)
pub const iso_level_5_shift = u32(57454)

pub const name_map = {
	'plus':                 u32(`+`)
	'minus':                u32(`-`)
	'colon':                u32(`:`)
	'semicolon':            u32(`;`)
	'comma':                u32(`,`)
	'tab':                  tab
	'enter':                enter
	'escape':               escape
	'space':                space
	'backspace':            backspace
	'insert':               insert
	'delete':               delete
	'left':                 left
	'right':                right
	'up':                   up
	'down':                 down
	'page_up':              page_up
	'page_down':            page_down
	'home':                 home
	'end':                  end
	'caps_lock':            caps_lock
	'scroll_lock':          scroll_lock
	'num_lock':             num_lock
	'print_screen':         print_screen
	'pause':                pause
	'menu':                 menu
	'f1':                   f1
	'f2':                   f2
	'f3':                   f3
	'f4':                   f4
	'f5':                   f5
	'f6':                   f6
	'f7':                   f7
	'f8':                   f8
	'f9':                   f9
	'f10':                  f10
	'f11':                  f11
	'f12':                  f12
	'f13':                  f13
	'f14':                  f14
	'f15':                  f15
	'f16':                  f16
	'f17':                  f17
	'f18':                  f18
	'f19':                  f19
	'f20':                  f20
	'f21':                  f21
	'f22':                  f22
	'f23':                  f23
	'f24':                  f24
	'f25':                  f25
	'f26':                  f26
	'f27':                  f27
	'f28':                  f28
	'f29':                  f29
	'f30':                  f30
	'f31':                  f31
	'f32':                  f32_key
	'f33':                  f33
	'f34':                  f34
	'f35':                  f35
	'kp_0':                 kp_0
	'kp_1':                 kp_1
	'kp_2':                 kp_2
	'kp_3':                 kp_3
	'kp_4':                 kp_4
	'kp_5':                 kp_5
	'kp_6':                 kp_6
	'kp_7':                 kp_7
	'kp_8':                 kp_8
	'kp_9':                 kp_9
	'kp_decimal':           kp_decimal
	'kp_divide':            kp_divide
	'kp_multiply':          kp_multiply
	'kp_subtract':          kp_subtract
	'kp_add':               kp_add
	'kp_enter':             kp_enter
	'kp_equal':             kp_equal
	'kp_separator':         kp_separator
	'kp_left':              kp_left
	'kp_right':             kp_right
	'kp_up':                kp_up
	'kp_down':              kp_down
	'kp_page_up':           kp_page_up
	'kp_page_down':         kp_page_down
	'kp_home':              kp_home
	'kp_end':               kp_end
	'kp_insert':            kp_insert
	'kp_delete':            kp_delete
	'kp_begin':             kp_begin
	'media_play':           media_play
	'media_pause':          media_pause
	'media_play_pause':     media_play_pause
	'media_reverse':        media_reverse
	'media_stop':           media_stop
	'media_fast_forward':   media_fast_forward
	'media_rewind':         media_rewind
	'media_track_next':     media_track_next
	'media_track_previous': media_track_previous
	'media_record':         media_record
	'lower_volume':         lower_volume
	'raise_volume':         raise_volume
	'mute_volume':          mute_volume
	'left_shift':           left_shift
	'left_control':         left_control
	'left_alt':             left_alt
	'left_super':           left_super
	'left_hyper':           left_hyper
	'left_meta':            left_meta
	'right_shift':          right_shift
	'right_control':        right_control
	'right_alt':            right_alt
	'right_super':          right_super
	'right_hyper':          right_hyper
	'right_meta':           right_meta
	'iso_level_3_shift':    iso_level_3_shift
	'iso_level_5_shift':    iso_level_5_shift
}

pub struct Mouse {
pub:
	button  MouseButton
	type_   MouseType
	col     u16
	row     u16
	xoffset u16
	yoffset u16
	mods    MouseModifiers
}

pub enum MouseButton as u8 {
	left
	middle
	right
	none_
	wheel_up    = 64
	wheel_down  = 65
	wheel_right = 66
	wheel_left  = 67
	button_8    = 128
	button_9    = 129
	button_10   = 130
	button_11   = 131
}

pub enum MouseType as u8 {
	press
	release
	motion
	drag
}

// MouseModifiers retains vaxis' packed u3 value in the low three bits.
pub struct MouseModifiers {
	value u8
}

fn MouseModifiers.new(shift bool, alt bool, ctrl bool) MouseModifiers {
	return MouseModifiers{
		value: u8(shift) | (u8(alt) << 1) | (u8(ctrl) << 2)
	}
}

pub fn (m MouseModifiers) shift() bool {
	return m.value & 1 != 0
}

pub fn (m MouseModifiers) alt() bool {
	return m.value & 2 != 0
}

pub fn (m MouseModifiers) ctrl() bool {
	return m.value & 4 != 0
}

pub struct Winsize {
pub:
	rows u16
	cols u16
}

pub type InputEvent = Key | Mouse

struct ParsedInput {
	event    ?InputEvent
	consumed int
}

// Tty incrementally decodes keys and SGR mouse reports from stdin. The V
// terminal helper applies and restores non-canonical input around every poll,
// so callers don't leave the host terminal in a broken state after a crash.
pub struct Tty {
mut:
	pending []u8
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
	}
	for {
		raw := term.key_pressed(blocking: false, echo: false)
		if raw < 0 {
			break
		}
		tty.append_raw(raw)
	}

	for tty.pending.len > 0 {
		parsed := parse_input(tty.pending) or { return none }
		tty.pending.delete_many(0, parsed.consumed)
		if event := parsed.event {
			return event
		}
	}
	return none
}

fn (mut tty Tty) append_raw(value i64) {
	if value == 0 {
		tty.pending << u8(0)
		return
	}
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
			return parsed_key(escape, Modifiers{}, 1)
		}
		if data[1] == `[` {
			return parse_csi(data)
		}
		if data[1] == `O` {
			return parse_ss3(data)
		}
		return ParsedInput{
			event:    InputEvent(Key{
				codepoint: u32(data[1])
				mods:      Modifiers.init(false, true, false, false, false, false, false,
					false)
			})
			consumed: 2
		}
	}

	byte := data[0]
	if byte == 0 {
		return parsed_key(u32(`@`), Modifiers.init(false, false, true, false, false, false,
			false, false), 1)
	}
	if byte == 0x08 {
		return parsed_key(backspace, Modifiers{}, 1)
	}
	if byte == 0x09 {
		return parsed_key(tab, Modifiers{}, 1)
	}
	if byte == 0x0a {
		return parsed_key(u32(`j`), Modifiers.init(false, false, true, false, false, false,
			false, false), 1)
	}
	if byte == 0x0d {
		return parsed_key(enter, Modifiers{}, 1)
	}
	if (byte >= 0x01 && byte <= 0x07) || (byte >= 0x0b && byte <= 0x0c)
		|| (byte >= 0x0e && byte <= 0x1a) {
		return ParsedInput{
			event:    InputEvent(Key{
				codepoint: u32(`a` + byte - 1)
				mods:      Modifiers.init(false, false, true, false, false, false, false,
					false)
			})
			consumed: 1
		}
	}
	if byte == 0x7f {
		return parsed_key(backspace, Modifiers{}, 1)
	}

	char_len := utf8_sequence_length(byte)
	if data.len < char_len {
		return none
	}
	runes := data.bytestr().runes()
	if runes.len == 0 {
		return none
	}
	mut consumed := char_len
	mut rune_count := 1
	mut previous := u32(runes[0])
	mut state := unicode.BreakState.default
	for i in 1 .. runes.len {
		current := u32(runes[i])
		if current < 0x20 || current == 0x7f
			|| unicode.grapheme_break(previous, current, &state) {
			break
		}
		consumed += runes[i].str().len
		rune_count++
		previous = current
	}
	codepoint := if rune_count > 1 { multicodepoint } else { u32(runes[0]) }
	return parsed_key_text(codepoint, data[..consumed].bytestr(), Modifiers{}, consumed)
}

fn parse_ss3(data []u8) ?ParsedInput {
	if data.len < 3 {
		return none
	}
	if data[2] == u8(escape) {
		return ParsedInput{
			consumed: 2
		}
	}
	code := match data[2] {
		`A` { up }
		`B` { down }
		`C` { right }
		`D` { left }
		`E` { kp_begin }
		`F` { end }
		`H` { home }
		`P` { f1 }
		`Q` { f2 }
		`R` { f3 }
		`S` { f4 }
		else {
			return ParsedInput{
				consumed: 3
			}
		}
	}
	return parsed_key(code, Modifiers{}, 3)
}

fn parse_csi(data []u8) ?ParsedInput {
	mut final_index := -1
	for i in 2 .. data.len {
		byte := data[i]
		if byte >= 0x40 {
			final_index = i
			break
		}
	}
	if final_index < 0 {
		return none
	}

	sequence := data[..final_index + 1].bytestr()
	final := data[final_index]
	if final == `M` || final == `m` {
		return parse_mouse(data, sequence)
	}

	if final in [`A`, `B`, `C`, `D`, `E`, `F`, `H`, `P`, `Q`, `R`, `S`] {
		code := match final {
			`A` { up }
			`B` { down }
			`C` { right }
			`D` { left }
			`E` { kp_begin }
			`F` { end }
			`H` { home }
			`P` { f1 }
			`Q` { f2 }
			`R` { f3 }
			`S` { f4 }
			else { return ParsedInput{ consumed: sequence.len } }
		}
		mut key := Key{
			codepoint: code
		}
		fields := sequence[2..sequence.len - 1].split(';')
		if fields.len > 1 {
			modifier_parts := fields[1].split(':')
			mask := parse_param_u32(modifier_parts[0], u32(1)) or {
				return ParsedInput{ consumed: sequence.len }
			}
			key.mods = Modifiers.from_int(u8(if mask > 0 { mask - 1 } else { 0 }))
			if modifier_parts.len > 1 && modifier_parts[1] == '3' {
				return ParsedInput{ consumed: sequence.len }
			}
		}
		if fields.len > 2 {
			key.text = parse_codepoint_text(fields[2]) or {
				return ParsedInput{ consumed: sequence.len }
			}
		}
		return ParsedInput{
			event:    InputEvent(key)
			consumed: sequence.len
		}
	}

	if final == `~` {
		fields := sequence[2..sequence.len - 1].split(';')
		number := parse_param_u32(fields[0], none) or {
			return ParsedInput{ consumed: sequence.len }
		}
		code := match number {
			2 { insert }
			3 { delete }
			5 { page_up }
			6 { page_down }
			7 { home }
			8 { end }
			11 { f1 }
			12 { f2 }
			13 { f3 }
			14 { f4 }
			15 { f5 }
			17 { f6 }
			18 { f7 }
			19 { f8 }
			20 { f9 }
			21 { f10 }
			23 { f11 }
			24 { f12 }
			57427 { kp_begin }
			else { return ParsedInput{ consumed: sequence.len } }
		}
		mut key := Key{
			codepoint: code
		}
		if fields.len > 1 {
			modifier_parts := fields[1].split(':')
			mask := parse_param_u32(modifier_parts[0], u32(1)) or {
				return ParsedInput{ consumed: sequence.len }
			}
			key.mods = Modifiers.from_int(u8(if mask > 0 { mask - 1 } else { 0 }))
			if modifier_parts.len > 1 && modifier_parts[1] == '3' {
				return ParsedInput{ consumed: sequence.len }
			}
		}
		if fields.len > 2 {
			key.text = parse_codepoint_text(fields[2]) or {
				return ParsedInput{ consumed: sequence.len }
			}
		}
		return ParsedInput{
			event:    InputEvent(key)
			consumed: sequence.len
		}
	}

	if final == `u` {
		if sequence.len > 2 && sequence[2] == `?` {
			return ParsedInput{ consumed: sequence.len }
		}
		fields := sequence[2..sequence.len - 1].split(';')
		alternate := fields[0].split(':')
		codepoint := parse_param_u32(alternate[0], none) or {
			return ParsedInput{ consumed: sequence.len }
		}
		mut key := Key{
			codepoint: codepoint
		}
		if alternate.len > 1 {
			key.shifted_codepoint = parse_param_u32(alternate[1], none)
		}
		if alternate.len > 2 {
			key.base_layout_codepoint = parse_param_u32(alternate[2], none)
		}
		if fields.len > 1 {
			modifier_parts := fields[1].split(':')
			mask := parse_param_u32(modifier_parts[0], u32(1)) or {
				return ParsedInput{ consumed: sequence.len }
			}
			key.mods = Modifiers.from_int(u8(if mask > 0 { mask - 1 } else { 0 }))
			if modifier_parts.len > 1 && modifier_parts[1] == '3' {
				return ParsedInput{ consumed: sequence.len }
			}
		}
		if fields.len > 2 {
			key.text = parse_codepoint_text(fields[2]) or {
				return ParsedInput{ consumed: sequence.len }
			}
		}
		only_shift := Modifiers.init(true, false, false, false, false, false,
			key.mods.caps_lock(), key.mods.num_lock())
		if key.text == none && key.mods.eql(only_shift) && key.codepoint <= 0xff
			&& key.codepoint >= 0x20 && key.codepoint <= 0x7e {
			upper := if key.codepoint >= `a` && key.codepoint <= `z` {
				key.codepoint - 32
			} else {
				key.codepoint
			}
			key.text = rune(upper).str()
			key.shifted_codepoint = upper
		}
		return ParsedInput{
			event:    InputEvent(key)
			consumed: sequence.len
		}
	}

	return ParsedInput{
		consumed: sequence.len
	}
}

fn parse_mouse(data []u8, sequence string) ?ParsedInput {
	mut button_mask := u64(0)
	mut px := u16(0)
	mut py := u16(0)
	mut xterm := false
	if sequence.len == 3 && sequence[2] == `M` {
		if data.len < 6 {
			return none
		}
		xterm = true
		button_mask = u64(data[3] - 32)
		px = u16(data[4] - 32)
		py = u16(data[5] - 32)
	} else if sequence.len >= 4 && sequence[2] == `<` {
		parts := sequence[3..sequence.len - 1].split(';')
		if parts.len != 3 {
			return ParsedInput{ consumed: sequence.len }
		}
		button_mask = strconv.parse_uint(parts[0], 10, 16) or {
			return ParsedInput{ consumed: sequence.len }
		}
		px = parse_mouse_position(parts[1]) or { return ParsedInput{ consumed: sequence.len } }
		py = parse_mouse_position(parts[2]) or { return ParsedInput{ consumed: sequence.len } }
	} else {
		return ParsedInput{ consumed: sequence.len }
	}
	if button_mask & 0x100 != 0 {
		return ParsedInput{
			consumed: if xterm { 6 } else { sequence.len }
		}
	}
	button := unsafe { MouseButton(u8(button_mask & 0xc3)) }
	motion := button_mask & 0x20 != 0
	type_ := if motion && button != .none_ {
		MouseType.drag
	} else if motion {
		MouseType.motion
	} else if xterm && button == .none_ {
		MouseType.release
	} else if !xterm && sequence.ends_with('m') {
		MouseType.release
	} else {
		MouseType.press
	}
	return ParsedInput{
		event:    InputEvent(Mouse{
			button: button
			type_:  type_
			row:    if py == 0 { u16(0) } else { u16(py - 1) }
			col:    if px == 0 { u16(0) } else { u16(px - 1) }
			mods:   MouseModifiers.new(button_mask & 0x04 != 0, button_mask & 0x08 != 0,
				button_mask & 0x10 != 0)
		})
		consumed: if xterm { 6 } else { sequence.len }
	}
}

fn parse_param_u32(raw string, default ?u32) ?u32 {
	if raw.len == 0 {
		return default
	}
	return u32(strconv.parse_uint(raw, 10, 32) or { return none })
}

fn parse_codepoint_text(raw string) ?string {
	mut result := ''
	for part in raw.split(':') {
		cp := parse_param_u32(part, none) or { return none }
		if cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff) {
			return none
		}
		result += rune(cp).str()
	}
	return result
}

fn parse_mouse_position(raw string) ?u16 {
	if raw.len == 0 {
		return u16(1)
	}
	return u16(strconv.parse_uint(raw, 10, 16) or { return none })
}

fn parsed_key(codepoint u32, mods Modifiers, consumed int) ParsedInput {
	return ParsedInput{
		event:    InputEvent(Key{
			codepoint: codepoint
			mods:      mods
		})
		consumed: consumed
	}
}

fn parsed_key_text(codepoint u32, text string, mods Modifiers, consumed int) ParsedInput {
	return ParsedInput{
		event:    InputEvent(Key{
			codepoint: codepoint
			text:      text
			mods:      mods
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
	if key.mods.ctrl() || key.codepoint < 0x20 || key.codepoint > 0x10ffff {
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
		.off {}
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
