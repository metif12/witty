module main

import os
import strconv
import strings
import encoding.hex
import vaxis as v

__global (
	observed      = &v.Vaxis(unsafe { nil })
	observed_path string
)

fn observe_exit() {
	if observed_path != '' && observed != unsafe { nil } {
		os.write_file(observed_path, state(observed)) or { eprintln('OBSERVER ERROR: ${err}') }
	}
}

// Fixture typed view of the existing byte-backed packed-modifier carrier.
fn mouse_mods(raw u8) v.MouseModifiers {
	return unsafe { *(&v.MouseModifiers(&raw)) }
}

fn number(p []string, i int) u16 {
	return u16(strconv.parse_uint(p[i], 10, 16) or { panic(err) })
}

fn decode(text string) string {
	return (hex.decode(text) or { panic(err) }).bytestr()
}

fn hn(value u64, n u64) u64 {
	mut h := value
	for shift in 0 .. 8 {
		h = (h ^ u64(u8(n >> u32(shift * 8)))) * u64(1099511628211)
	}
	return h
}

fn hs(value u64, text string) u64 {
	mut h := hn(value, u64(text.len))
	for byte in text {
		h = (h ^ u64(byte)) * u64(1099511628211)
	}
	return h
}

fn color(c v.Color) u32 {
	return match c {
		v.ColorDefault { 0 }
		v.ColorIndex { u32(0x1000000) + u32(c.index) }
		v.ColorRgb { u32(0x2000000) + (u32(c.rgb[0]) << 16) + (u32(c.rgb[1]) << 8) + c.rgb[2] }
	}
}

fn style_hash(value u64, s v.Style) u64 {
	mut h := hn(hn(hn(value, color(s.fg)), color(s.bg)), color(s.ul))
	h = hn(h, u64(s.ul_style))
	for b in [s.bold, s.dim, s.italic, s.blink, s.reverse, s.invisible, s.strikethrough] {
		h = hn(h, u64(b))
	}
	return h
}

fn state(value &v.Vaxis) string {
	mut h := u64(14695981039346656037)
	for c in value.screen_last.buf {
		h = style_hash(hs(hs(hs(h, c.char_), c.uri), c.uri_id), c.style)
		scale := u64(c.scale.scale()) | (u64(c.scale.numerator()) << 3) | (u64(c.scale.denominator()) << 7) | (u64(c.scale.vertical_alignment()) << 11)
		h = hn(hn(hn(hn(h, u64(c.skipped)), u64(c.skip)), u64(c.default_)), scale)
	}
	return '${u8(value.refresh)},${value.state.cursor.row},${value.state.cursor.col},${u8(value.screen_last.mouse_shape)},${u8(value.screen_last.cursor_shape)},${value.screen_last.width},${value.screen_last.height},${value.screen_last.buf.len},${h.str()},${u8(value.caps.unicode)},${u8(value.sgr)}'
}

fn cell(i int, pattern u16, seed u16, text string, width u8) v.Cell {
	if pattern == 0 || ((pattern == 4 || pattern == 6) && i > 0) {
		return v.Cell{
			default_: true
		}
	}
	n := u8(int(seed) + i)
	mut c := v.Cell{
		char_:    v.CellCharacter{
			grapheme: text
			width:    width
		}
		default_: pattern == 2 && n % 3 == 0
		wrapped:  pattern == 3 || n % 5 == 0
		style:    v.Style{
			fg:            match n % 4 {
				0 {
					v.Color(v.ColorDefault{})
				}
				1 {
					v.Color(v.ColorIndex{
						index: n % 16
					})
				}
				2 {
					v.Color(v.ColorIndex{
						index: n
					})
				}
				else {
					v.Color(v.ColorRgb{
						rgb: [n, n ^ 0xaa, 255 - n]!
					})
				}
			}
			bg:            v.ColorRgb{
				rgb: [255 - n, n, n ^ 0x55]!
			}
			ul:            if n % 2 == 0 { v.Color(v.ColorIndex{
					index: n
				}) } else { v.Color(v.ColorRgb{
					rgb: [n, 255 - n, n]!
				}) }
			ul_style:      unsafe { v.UnderlineStyle(n % 6) }
			bold:          n & 1 != 0
			dim:           n & 2 != 0
			italic:        n & 4 != 0
			blink:         n & 8 != 0
			reverse:       n & 16 != 0
			invisible:     n & 32 != 0
			strikethrough: n & 64 != 0
		}
		link:     if n % 3 == 0 {
			v.CellHyperlink{}
		} else {
			v.CellHyperlink{
				uri:    if n % 3 == 1 { 'u:one' } else { 'u:two' }
				params: if n % 2 == 0 { 'id=a' } else { 'id=b' }
			}
		}
	}
	if pattern == 4 { c.scale = v.CellScale.init(2, 1, 1, .top) }
	if pattern == 5 {
		c.scale = v.CellScale.init(n % 2, n % 15 + 1, u8(n + u8(3)) % 15 + 1,
			unsafe { v.VerticalAlignment(n % 3) })
	}
	if pattern == 6 {
		c.image = v.ImagePlacement{
			img_id:  u32(seed) + 1
			options: v.ImageDrawOptions{
				pixel_offset: v.ImagePixelOffset{
					x: seed
					y: 65535 - seed
				}
				z_index:      -i32(seed)
				clip_region:  v.ImageClipRegion{
					x:      seed
					height: 65535
				}
				size:         v.ImageCellSize{
					rows: 1
					cols: 2
				}
			}
		}
	}
	return c
}

fn record(p []string, id int) string {
	opts := v.VaxisOptions{}
	initial := v.Vaxis.new(opts)
	mut value := &v.Vaxis{
		...initial
	}
	defer { value.deinit() }
	mut out := strings.new_builder(512)
	out.write_string('${id}|')
	if p[0] == 'U' {
		if p[2] == '-' {
			os.unsetenv('HOSTNAME')
		} else {
			os.setenv('HOSTNAME', decode(p[2]), true)
		}
		bytes := value.set_terminal_working_directory(decode(p[1])) or {
			return out.str() + 'E${err.msg()}\n'
		}
		out.write_string(hex.encode(bytes.bytes()))
	} else if p[0] == 'M' {
		value.screen.width = number(p, 1)
		value.screen.height = number(p, 2)
		value.screen.width_pix = number(p, 3)
		value.screen.height_pix = number(p, 4)
		value.state.pixel_mouse = number(p, 5) != 0
		m := value.translate_mouse(v.Mouse{
			col:     number(p, 6)
			row:     number(p, 7)
			xoffset: number(p, 8)
			yoffset: number(p, 9)
			button:  unsafe { v.MouseButton(number(p, 10)) }
			type_:   unsafe { v.MouseType(number(p, 11)) }
			mods:    mouse_mods(u8(number(p, 12)))
		})
		out.write_string('${m.col},${m.row},${m.xoffset},${m.yoffset},${u8(m.button)},${u8(m.type_)},${u8(m.mods.shift()) | (u8(m.mods.alt()) << 1) | (u8(m.mods.ctrl()) << 2)}')
	} else {
		w := number(p, 1)
		h := number(p, 2)
		pattern := number(p, 3)
		seed := number(p, 4)
		flags := number(p, 5)
		text := decode(p[10])
		width := u8(number(p, 11))
		value.screen = v.Screen.new(v.Winsize{ cols: w, rows: h })
		value.screen_last = v.InternalScreen.new(w, h)
		value.state.alt_screen = flags & 1 != 0
		value.refresh = flags & 2 != 0
		value.caps.kitty_graphics = flags & 4 != 0
		value.caps.explicit_width = flags & 8 != 0
		value.caps.scaled_text = flags & 16 != 0
		value.sgr = if flags & 32 != 0 { .legacy } else { .standard }
		value.enable_workarounds = flags & 64 == 0
		value.screen.cursor_vis = flags & 128 != 0
		value.caps.unicode = unsafe { v.GWidthMethod(seed % 3) }
		value.screen.mouse_shape = unsafe { v.MouseShape(number(p, 6)) }
		value.screen.cursor_shape = unsafe { v.CursorShape(number(p, 7)) }
		value.screen.cursor_row = number(p, 8)
		value.screen.cursor_col = number(p, 9)
		value.state.cursor = v.SessionCursor{
			row: seed % 3
			col: seed % 4
		}
		for i in 0 .. value.screen.buf.len {
			value.screen.buf[i] = cell(i, pattern, seed, text, width)
		}
		for i in 0 .. value.screen_last.buf.len {
			value.screen_last.buf[i].skipped = (i + int(seed)) % 5 == 0
			value.screen_last.buf[i].skip = (i + int(seed)) % 7 == 0
			value.screen_last.buf[i].scale = v.CellScale.init(u8(seed % 8), u8(seed % 16), u8((
				seed + 1) % 16), .top)
		}
		for frame in 0 .. 3 {
			if frame == 2 && value.screen.buf.len > 0 {
				value.screen.buf[0].char_.grapheme = 'z'
				value.screen.buf[0].char_.width = 1
				value.screen.buf[0].style = v.Style{
					...value.screen.buf[0].style
					bold: !value.screen.buf[0].style.bold
				}
				value.screen.buf[0].scale = v.CellScale{}
				value.screen.buf[0].image = none
			}
			bytes := if p[0] == 'P' {
				value.pretty_print() or {
					out.write_string('E${err.msg()}')
					''
				}
			} else {
				value.render()
			}
			out.write_string(hex.encode(bytes.bytes()))
			out.write_string('/${state(value)}|')
		}
	}
	out.write_u8(`\n`)
	return out.str()
}

fn trap(name string, path string) {
	opts := v.VaxisOptions{}
	initial := v.Vaxis.new(opts)
	mut value := &v.Vaxis{
		...initial
	}
	observed = value
	observed_path = path
	at_exit(observe_exit) or { panic(err) }
	value.refresh = true
	if name.starts_with('mouse') {
		value.screen = v.Screen{
			width:  1
			height: 1
		}
		value.state.pixel_mouse = true
		value.translate_mouse(v.Mouse{
			xoffset: if name == 'mouse_y' { u16(0) } else { u16(1) }
			yoffset: 1
		})
	} else if name == 'render_size' {
		value.screen.width = 65535
		value.screen.height = 65535
		value.render()
	} else if name == 'render_last' {
		value.screen = v.Screen.new(v.Winsize{ cols: 1, rows: 1 })
		value.render()
	} else if name.starts_with('cursor') {
		value.state.alt_screen = true
		value.screen.cursor_vis = true
		value.screen.cursor_col = if name == 'cursor_col' { u16(65535) } else { u16(0) }
		value.screen.cursor_row = if name == 'cursor_row' { u16(65535) } else { u16(0) }
		value.render()
	} else if name == 'pretty_index' {
		value.screen = v.Screen.new(v.Winsize{ cols: 2, rows: 32768 })
		for mut c in value.screen.buf {
			c.default_ = true
		}
		value.pretty_print() or { panic(err) }
	} else if name == 'render_col' {
		value.screen = v.Screen.new(v.Winsize{ cols: 65535, rows: 1 })
		value.screen_last = v.InternalScreen.new(65535, 1)
		for i in 0 .. value.screen.buf.len {
			value.screen.buf[i] = v.Cell{
				char_: v.CellCharacter{
					grapheme: 'x'
					width:    250
				}
			}
		}
		value.render()
	} else {
		value.screen = v.Screen.new(v.Winsize{ cols: 300, rows: 3 })
		value.screen_last = v.InternalScreen.new(300, 3)
		value.caps.scaled_text = true
		value.screen.buf[0] = v.Cell{
			char_: v.CellCharacter{
				grapheme: 'X'
				width:    u8(if name == 'scaled_unknown' {
					0
				} else if name == 'scaled_overflow' {
					100
				} else {
					1
				})
			}
			scale: v.CellScale.init(u8(if name == 'denominator' { 1 } else { 3 }), 1, u8(if name == 'denominator' {
				0
			} else {
				1
			}), .top)
		}
		if name == 'scaled_bounds' {
			value.screen.buf[0].scale = v.CellScale.init(2, 1, 1, .top)
			value.screen_last.width = 65535
		}
		value.render()
	}
	panic('UNEXPECTED returning trap')
}

fn main() {
	if os.args.len > 2 && os.args[1] == '--trap' {
		trap(os.args[2], os.args[3])
		return
	}
	input := os.read_file(os.args[1]) or { panic(err) }
	mut id := 0
	for line in input.split_into_lines() {
		if line == '' { continue
		 }
		print(record(line.split('|'), id))
		id++
	}
}
