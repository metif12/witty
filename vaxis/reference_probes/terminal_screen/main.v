module main

import os
import encoding.hex
import strconv
import strings
import vaxis

fn uint(parts []string, i int) uint {
	return uint(strconv.parse_uint(parts[i], 10, 64) or { panic(err) })
}

fn style(index uint) vaxis.Style {
	return match index {
		1 {
			vaxis.Style{
				fg:            vaxis.ColorIndex{
					index: 3
				}
				bg:            vaxis.ColorIndex{
					index: 4
				}
				ul:            vaxis.ColorIndex{
					index: 5
				}
				ul_style:      .curly
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
			vaxis.Style{
				fg:       vaxis.ColorRgb{
					rgb: [u8(1), 2, 3]!
				}
				bg:       vaxis.ColorRgb{
					rgb: [u8(5), 8, 13]!
				}
				ul:       vaxis.ColorRgb{
					rgb: [u8(21), 34, 55]!
				}
				ul_style: .dashed
				italic:   true
			}
		}
		3 {
			vaxis.Style{
				ul_style: .double_
				bold:     true
			}
		}
		else {
			vaxis.Style{}
		}
	}
}

fn color(value vaxis.Color) u32 {
	return match value {
		vaxis.ColorDefault { u32(0) }
		vaxis.ColorIndex { u32(0x1000000) | u32(value.index) }
		vaxis.ColorRgb { u32(0x2000000) | (u32(value.rgb[0]) << 16) | (u32(value.rgb[1]) << 8) | u32(value.rgb[2]) }
	}
}

fn cell(mut output strings.Builder, value vaxis.Cell) {
	flags := u8(value.style.bold) | (u8(value.style.dim) << 1) | (u8(value.style.italic) << 2) | (u8(value.style.blink) << 3) | (u8(value.style.reverse) << 4) | (u8(value.style.invisible) << 5) | (u8(value.style.strikethrough) << 6)
	output.write_string('${hex.encode(value.char_.grapheme.bytes())}/${value.char_.width}/${color(value.style.fg)}/${color(value.style.bg)}/${color(value.style.ul)}/${u8(value.style.ul_style)}/${flags}/${u8(value.default_)}/${u8(value.wrapped)}/${value.link.uri}/${value.link.params};')
	output.write_string('${value.scale.scale()},${value.scale.numerator()},${value.scale.denominator()},${u8(value.scale.vertical_alignment())},')
	if img := value.image {
		output.write_string('${img.img_id};')
	} else {
		output.write_string('none;')
	}
}

// Keep the Screen borrowed so optimized GC root tracking does not traverse
// its entire buffer for every serialized cell. This only changes the probe.
fn values(mut out strings.Builder, screen &vaxis.TerminalScreen) {
	out.write_string('${screen.width},${screen.height};${screen.scrolling_region.top},${screen.scrolling_region.bottom},${screen.scrolling_region.left},${screen.scrolling_region.right};')
	cursor := screen.cursor
	out.write_string('${cursor.col},${cursor.row},${u8(cursor.pending_wrap)},${u8(cursor.shape)},${u8(cursor.visible)},${screen.csi_u_flags.int()};')
	cell(mut out, vaxis.Cell{
		style: cursor.style
		link:  vaxis.CellHyperlink{
			uri:    cursor.uri
			params: cursor.uri_id
		}
	})
	for value in screen.buf {
		cell(mut out, vaxis.Cell{
			char_:   vaxis.CellCharacter{
				grapheme: value.char_
				width:    value.width
			}
			style:   value.style
			wrapped: value.wrapped
			link:    vaxis.CellHyperlink{
				uri:    value.uri
				params: value.uri_id
			}
		})
		out.write_string('${u8(value.dirty)};')
	}
}

fn seed(mut screen vaxis.TerminalScreen, offset int) {
	for i in 0 .. screen.buf.len {
		screen.buf[i] = vaxis.TerminalScreenCell{
			char_:   '${i + offset}'.clone()
			uri:     'u${i + offset}'.clone()
			uri_id:  'i${i + offset}'.clone()
			style:   style(uint((i + offset) % 4))
			width:   u8(i % 3)
			wrapped: i % 2 == 0
			dirty:   i % 3 != 0
		}
	}
	screen.cursor.uri = 'cursor'
	screen.cursor.uri_id = 'id'
	screen.cursor.style = style(2)
	screen.cursor.shape = .beam
	screen.cursor.visible = false
	screen.csi_u_flags = vaxis.KittyFlags.from_int(17)
}

fn trap(mode string) {
	if mode == 'trap_zero_w' || mode == 'trap_zero_h' {
		vaxis.TerminalScreen.new(if mode == 'trap_zero_w' { u16(0) } else { 1 }, if mode == 'trap_zero_h' {
			u16(0)
		} else {
			1
		}) or { panic(err) }
	} else {
		mut screen := vaxis.TerminalScreen.new(2, 2) or { panic(err) }
		seed(mut screen, 0)
		if mode == 'trap_read' {
			screen.read_cell(0, 2)
		} else if mode == 'trap_read_add' {
			screen.read_cell(~uint(0), 0)
		} else if mode == 'trap_right' {
			screen.cursor.col = 65535
			screen.cursor_right(1)
		} else if mode == 'trap_down' {
			screen.cursor.row = 1
			screen.cursor_down(~uint(0))
		} else if mode == 'trap_index' {
			screen.cursor.row = 65535
			screen.index() or { panic(err) }
		} else if mode == 'trap_print' {
			screen.width = 65535
			screen.height = 3
			screen.cursor.row = 2
			screen.print('x', 1, false) or { panic(err) }
		} else if mode == 'trap_delete_count' {
			screen.width = 1
			screen.height = 65535
			screen.scrolling_region.bottom = 65535
			screen.scrolling_region.right = 0
			screen.delete_line(1) or { panic(err) }
		} else if mode == 'trap_erase_below_count' {
			mut tall := vaxis.TerminalScreen.new(256, 256) or { panic(err) }
			tall.erase_below()
		} else if mode == 'trap_erase' {
			screen.width = 65535
			screen.height = 3
			screen.cursor.row = 2
			screen.erase_line()
		} else if mode == 'trap_enum' {
			screen.sgr(vaxis.TerminalCsi{ params: '4:6'.bytes(), final: `m` })
		} else if mode == 'trap_sgr' {
			screen.sgr(vaxis.TerminalCsi{ params: '256'.bytes(), final: `m` })
		} else if mode == 'trap_self_to' {
			screen.copy_to(mut screen) or { panic(err) }
		} else if mode == 'trap_copy' {
			mut dst := vaxis.TerminalScreen.new(1, 1) or { panic(err) }
			screen.copy_to(mut dst) or { panic(err) }
		} else if mode == 'hang_insert' {
			screen.cursor.row = 1
			screen.insert_line(1) or { panic(err) }
		}
	}
	println('UNEXPECTED')
}

fn main() {
	if os.args[1].starts_with('trap_') || os.args[1].starts_with('hang_') {
		trap(os.args[1])
		return
	}
	mut out := strings.new_builder(1024)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		parts := line.split('|')
		mut screen := vaxis.TerminalScreen.new(u16(uint(parts, 1)), u16(uint(parts, 2))) or {
			panic(err)
		}
		if parts[0] == 'N' {
			values(mut out, screen)
			screen.deinit()
			out.write_string('\n')
			continue
		}
		seed(mut screen, 0)
		screen.scrolling_region = vaxis.TerminalScrollingRegion{
			top:    u16(uint(parts, 3))
			bottom: u16(uint(parts, 4))
			left:   u16(uint(parts, 5))
			right:  u16(uint(parts, 6))
		}
		screen.cursor.col = u16(uint(parts, 7))
		screen.cursor.row = u16(uint(parts, 8))
		screen.cursor.pending_wrap = uint(parts, 9) != 0
		op := uint(parts, 10)
		n := uint(parts, 11)
		match op {
			0 {
				screen.print((hex.decode(parts[12]) or { panic(err) }).bytestr(),
					u8(uint(parts, 13)), uint(parts, 14) != 0) or { panic(err) }
			}
			1 {
				screen.index() or { panic(err) }
			}
			2 {
				screen.cursor_up(u16(n))
			}
			3 {
				screen.cursor_left(u16(n))
			}
			4 {
				screen.cursor_right(u16(n))
			}
			5 {
				screen.cursor_down(n)
			}
			6 {
				screen.erase_right()
			}
			7 {
				screen.erase_left()
			}
			8 {
				screen.erase_line()
			}
			9 {
				screen.delete_line(n) or { panic(err) }
			}
			10 {
				screen.insert_line(n) or { panic(err) }
			}
			11 {
				screen.erase_below()
			}
			12 {
				screen.erase_above()
			}
			13 {
				screen.erase_all()
			}
			14 {
				screen.delete_characters(n) or { panic(err) }
			}
			15 {
				screen.reverse_index() or { panic(err) }
			}
			16 {
				screen.scroll_down(n) or { panic(err) }
			}
			17 {
				screen.sgr(vaxis.TerminalCsi{
					params: (hex.decode(parts[12]) or { panic(err) })
					final:  `m`
				})
			}
			18 {
				mut dst := vaxis.TerminalScreen.new(screen.width, screen.height) or { panic(err) }
				seed(mut dst, 100)
				screen.copy_to(mut dst) or { panic(err) }
				if n != 0 { screen.copy_to(mut dst) or { panic(err) } }
				values(mut out, dst)
				dst.deinit()
			}
			19 {
				screen.buf[0].erase(screen.cursor.style.bg)
			}
			20 {
				screen.buf[0].copy_from(screen.buf[int(n % uint(screen.buf.len))]) or {
					panic(err)
				}
			}
			21 {
				out.write_string('${u8(screen.within_scrolling_region())},${u8(screen.cursor.is_inside_scrolling_region(screen.scrolling_region))},${u8(screen.cursor.is_outside_scrolling_region(screen.scrolling_region))};')
				if value := screen.read_cell(uint(parts, 13), uint(parts, 14)) {
					cell(mut out, value)
				} else {
					out.write_string('none;')
				}
			}
			else {
				panic('operation')
			}
		}

		values(mut out, screen)
		screen.deinit()
		out.write_string('\n')
	}
	print(out.str())
}
