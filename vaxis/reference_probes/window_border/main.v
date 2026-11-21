module main

import os
import strings
import vaxis as v

// Observation only: atexit runs after the normal V panic diagnostic/exit path.
__global (
	observed_screen = &v.Screen(unsafe { nil })
	observed_glyphs [6]string
	observed_path   string
)

fn observe_exit() {
	if observed_path != '' && observed_screen != unsafe { nil } {
		value := buffer_hash(observed_screen.buf, &observed_glyphs, true)
		os.write_file(observed_path, '${value:x}\n') or { eprintln('OBSERVER ERROR: ${err}') }
	}
}

fn style(index int) v.Style {
	return match index {
		0 {
			v.Style{}
		}
		1 {
			v.Style{
				fg:            v.ColorIndex{
					index: 9
				}
				bg:            v.ColorRgb{
					rgb: [u8(1), 2, 3]!
				}
				ul:            v.ColorIndex{
					index: 7
				}
				ul_style:      .dashed
				bold:          true
				dim:           true
				italic:        true
				blink:         true
				reverse:       true
				invisible:     true
				strikethrough: true
			}
		}
		2 {
			v.Style{
				fg:       v.ColorRgb{
					rgb: [u8(251), 129, 3]!
				}
				bg:       v.ColorIndex{
					index: 17
				}
				ul:       v.ColorRgb{
					rgb: [u8(7), 8, 9]!
				}
				ul_style: .curly
				italic:   true
			}
		}
		3 {
			v.Style{
				bg:      v.ColorIndex{
					index: 2
				}
				reverse: true
			}
		}
		else {
			panic('invalid style')
		}
	}
}

fn seed() v.Cell {
	return v.Cell{
		char_:    v.CellCharacter{
			grapheme: 'o'
			width:    3
		}
		style:    style(3)
		link:     v.CellHyperlink{
			uri:    'old'
			params: 'id=old'
		}
		default_: true
		wrapped:  true
		scale:    v.CellScale.init(2, 3, 4, .bottom)
	}
}

fn mix(hash u64, byte u8) u64 {
	return (hash ^ u64(byte)) * u64(1099511628211)
}

fn mix_number(hash u64, number u64) u64 {
	mut result := hash
	for index in 0 .. 8 {
		result = mix(result, u8(number >> (index * 8)))
	}
	return result
}

fn mix_bytes(hash u64, bytes string) u64 {
	mut result := mix_number(hash, u64(bytes.len))
	for byte in bytes {
		result = mix(result, byte)
	}
	return result
}

fn buffer_hash(cells []v.Cell, glyphs &[6]string, custom bool) u64 {
	mut hash := mix_number(u64(14695981039346656037), u64(cells.len))
	for cell in cells {
		hash = mix_bytes(hash, cell.char_.grapheme)
		hash = mix(hash, cell.char_.width)
		mut style_id := u8(255)
		for index in 0 .. 4 {
			if cell.style.eql(style(index)) {
				style_id = u8(index)
				break
			}
		}
		hash = mix(hash, style_id)
		hash = mix_bytes(hash, cell.link.uri)
		hash = mix_bytes(hash, cell.link.params)
		hash = mix(hash, u8(cell.default_))
		hash = mix(hash, u8(cell.wrapped))
		hash = mix(hash, u8(cell.image != none))
		hash = mix(hash, cell.scale.scale())
		hash = mix(hash, cell.scale.numerator())
		hash = mix(hash, cell.scale.denominator())
		hash = mix(hash, u8(cell.scale.vertical_alignment()))
		mut glyph_id := u8(255)
		if custom && cell.char_.grapheme.len > 0 {
			for index in 0 .. 6 {
				glyph := unsafe { (*glyphs)[index] }
				if glyph.len == cell.char_.grapheme.len && glyph.str == cell.char_.grapheme.str {
					glyph_id = u8(index)
					break
				}
			}
		}
		hash = mix(hash, glyph_id)
	}
	return hash
}

fn location(index int) v.BorderWhere {
	return match index {
		0 {
			v.BorderNone{}
		}
		1 {
			v.BorderAll{}
		}
		2 {
			v.BorderTop{}
		}
		3 {
			v.BorderRight{}
		}
		4 {
			v.BorderBottom{}
		}
		5 {
			v.BorderLeft{}
		}
		else {
			v.BorderLocations{
				top:    ((index - 6) & 1) != 0
				right:  ((index - 6) & 2) != 0
				bottom: ((index - 6) & 4) != 0
				left:   ((index - 6) & 8) != 0
			}
		}
	}
}

fn window(screen &v.Screen, width u16, height u16, x int, y int, px int, py int) v.Window {
	return v.Window{
		width:        width
		height:       height
		x_off:        x
		y_off:        y
		parent_x_off: px
		parent_y_off: py
		screen:       screen
	}
}

fn trap(name string, path string) {
	mut screen := v.Screen{
		width:  4
		height: 2
		buf:    []v.Cell{len: 8, init: seed()}
	}
	mut width := u16(4)
	mut height := u16(2)
	mut x := 0
	mut y := 0
	mut px := 0
	mut py := 0
	mut cx := 0
	mut cy := 0
	mut where_ := v.BorderWhere(v.BorderAll{})
	match name {
		'trap_init_width' {
			width = 65535
			cx = -1
		}
		'trap_init_height' {
			height = 65535
			cy = -1
		}
		'trap_init_x' {
			x = 65535
			cx = 1
		}
		'trap_init_y' {
			y = 65535
			cy = 1
		}
		'trap_init_parent_x' {
			px = -65536
			cx = -1
		}
		'trap_init_parent_y' {
			py = -65536
			cy = -1
		}
		'trap_top_x' {
			x = 65535
			where_ = v.BorderTop{}
		}
		'trap_bottom_y' {
			y = 65535
			where_ = v.BorderBottom{}
		}
		'trap_left_y' {
			y = 65535
			where_ = v.BorderLeft{}
		}
		'trap_right_x' {
			x = 65535
			where_ = v.BorderRight{}
		}
		'trap_inner_x' {
			x = 65535
			width = 0
			height = 0
			where_ = v.BorderLeft{}
		}
		'trap_inner_y' {
			y = 65535
			width = 0
			height = 0
			where_ = v.BorderTop{}
		}
		'trap_top_bottom_order' {
			screen.buf = screen.buf[..4]
			where_ = v.BorderLocations{
				top:    true
				bottom: true
			}
		}
		'trap_left_right_order' {
			screen.width = 2
			screen.height = 3
			screen.buf = screen.buf[..2]
			width = 2
			height = 3
			where_ = v.BorderLocations{
				left:  true
				right: true
			}
		}
		'trap_empty_buffer' {
			screen.buf = screen.buf[..0]
			where_ = v.BorderTop{}
		}
		'trap_large_index' {
			screen.width = 65535
			screen.height = 65535
			screen.buf = screen.buf[..1]
			width = 1
			height = 1
			y = 32769
			where_ = v.BorderTop{}
		}
		else {
			panic('invalid trap')
		}
	}

	observed_glyphs = ['A', 'H', 'B', 'V', 'C', 'D']!
	observed_screen = &screen
	observed_path = path
	at_exit(observe_exit) or { panic(err) }
	w := window(&screen, width, height, x, y, px, py)
	w.child(v.WindowChildOptions{
		x_off:  cx
		y_off:  cy
		border: v.WindowBorderOptions{
			where_: where_
			glyphs: v.BorderCustom{
				glyphs: observed_glyphs
			}
		}
	})
	println('UNEXPECTED')
}

fn n(parts []string, index int) int {
	return parts[index].int()
}

fn u(parts []string, index int) u16 {
	return u16(n(parts, index))
}

fn optional(parts []string, index int) ?u16 {
	value := n(parts, index)
	return if value < 0 { none } else { u16(value) }
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1], os.args[2])
		return
	}
	input := os.read_file(os.args[1]) or { panic(err) }
	mut out := strings.new_builder(65536)
	mut number := 0
	for line in input.split_into_lines() {
		if line == '' { continue
		 }
		parts := line.split('|')
		length := n(parts, 2)
		mut screen := v.Screen{
			width:  u(parts, 0)
			height: u(parts, 1)
		}
		size := if length < 0 { int(screen.width) * int(screen.height) } else { length }
		screen.buf = []v.Cell{len: size, init: seed()}
		w := window(&screen, u(parts, 3), u(parts, 4), n(parts, 5), n(parts, 6), n(parts, 7),
			n(parts, 8))
		glyph_mode := n(parts, 14)
		glyphs := if glyph_mode == 3 { ['', 'wide界', '\x00', '\xff\x1b', 'e\u0301', 'end']! } else { [
				'A',
				'H',
				'B',
				'V',
				'C',
				'D',
			]! }
		mut owned := [][]u8{len: 6}
		mut borrowed := [6]string{}
		for i in 0 .. 6 {
			owned[i] = glyphs[i].bytes()
			if owned[i].len == 0 {
				owned[i] = [u8(0)]
			}
			borrowed[i] = unsafe { tos(owned[i].data, glyphs[i].len) }
		}
		kind := match glyph_mode {
			0 {
				v.BorderGlyphs(v.BorderSingleRounded{})
			}
			1 {
				v.BorderGlyphs(v.BorderSingleSquare{})
			}
			else {
				v.BorderGlyphs(v.BorderCustom{
					glyphs: borrowed
				})
			}
		}

		mut opts := v.WindowChildOptions{
			x_off:  n(parts, 9)
			y_off:  n(parts, 10)
			width:  optional(parts, 11)
			height: optional(parts, 12)
			border: v.WindowBorderOptions{
				where_: location(n(parts, 13))
				style:  style(n(parts, 15))
				glyphs: kind
			}
		}
		result := w.child(opts)
		before := buffer_hash(screen.buf, &borrowed, glyph_mode >= 2)
		if n(parts, 16) != 0 {
			for bytes in owned {
				unsafe { C.memset(bytes.data, `Z`, uint(bytes.len)) }
			}
			opts = v.WindowChildOptions{
				...opts
				border: v.WindowBorderOptions{
					...opts.border
					style: style(3)
				}
			}
		}
		after := buffer_hash(screen.buf, &borrowed, glyph_mode >= 2)
		out.write_string('${number}|${result.width},${result.height},${result.x_off},${result.y_off},${result.parent_x_off},${result.parent_y_off},${int(result.screen == &screen)}|${before:x}|${after:x}\n')
		number++
	}
	print(out.str())
}
