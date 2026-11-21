module main

import os
import encoding.hex
import strconv
import strings
import vaxis

fn uint(parts []string, index int) uint {
	return uint(strconv.parse_uint(parts[index], 10, 64) or { panic(err) })
}

fn bytes(value string) string {
	return (hex.decode(value) or { panic(err) }).bytestr()
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

fn state(mut output strings.Builder, input vaxis.TextInput) {
	b := input.buf
	output.write_string('${b.buffer.len},${u64(b.cursor).str()},${u64(b.gap_size).str()};')
	if b.cursor <= uint(b.buffer.len) && b.gap_size <= uint(b.buffer.len) - b.cursor {
		output.write_string('${hex.encode(b.first_half())}/${hex.encode(b.second_half())};')
	} else {
		output.write_string('invalid;')
	}
	output.write_string('${input.draw_offset},${input.prev_cursor_col},${input.prev_cursor_idx},${input.scroll_offset};')
}

fn trap(mode string) {
	mut input := vaxis.TextInput.new()
	input.buf.insert_slice_at_cursor('abc')
	if mode == 'trap_count' {
		input.buf.clear_and_free()
		input.buf.insert_slice_at_cursor('a'.repeat(65536))
		input.graphemes_before_cursor()
	} else if mode == 'trap_width' {
		input.buf.clear_and_free()
		input.buf.insert_slice_at_cursor('界'.repeat(32768))
		input.width_to_cursor()
	} else if mode.starts_with('trap_utf8_') {
		input.buf.clear_and_free()
		input.buf.insert_slice_at_cursor(bytes('ffcc81'))
		if mode == 'trap_utf8_left' {
			input.cursor_left()
		} else if mode == 'trap_utf8_delete' {
			input.delete_before_cursor()
		} else if mode == 'trap_utf8_count' {
			input.graphemes_before_cursor()
		} else if mode == 'trap_utf8_width' {
			input.width_to_cursor()
		} else if mode == 'trap_utf8_right' {
			input.buf.move_gap_left(3)
			input.cursor_right()
		} else if mode == 'trap_utf8_after' {
			input.buf.move_gap_left(3)
			input.delete_after_cursor()
		}
	} else if mode == 'trap_right' {
		input.buf.move_gap_right(1)
	} else if mode == 'trap_right_order' {
		input.buf.cursor = uint(input.buf.buffer.len + 1)
		input.buf.gap_size = ~uint(0)
		input.buf.move_gap_right(0)
	} else if mode == 'trap_right_add' {
		input.buf.cursor = ~uint(0)
		input.buf.move_gap_right(1)
	} else if mode == 'trap_right_end' {
		input.buf.gap_size = ~uint(0)
		input.buf.move_gap_right(1)
	} else if mode == 'trap_gap_left' {
		input.buf.gap_size = ~uint(0)
		input.buf.grow_gap_left(1)
	} else if mode == 'trap_grow' {
		input.buf.grow(~uint(0))
	} else if mode == 'trap_first_half' {
		input.buf.cursor = uint(1) << 32
		input.buf.first_half()
	} else if mode == 'trap_second_half' {
		input.buf.cursor = ~uint(0)
		input.buf.gap_size = 1
		input.buf.second_half()
	} else if mode == 'trap_left_add' {
		input.buf.cursor = ~uint(0)
		input.buf.gap_size = ~uint(0)
		input.buf.move_gap_left(0)
	} else if mode == 'trap_left_zero' {
		input.buf.cursor = uint(input.buf.buffer.len + 1)
		input.buf.gap_size = 0
		input.buf.move_gap_left(0)
	} else if mode == 'trap_gap_right_add' {
		input.buf.grow_gap_right(~uint(0))
	} else if mode == 'trap_gap_right_sub' {
		input.buf.cursor = uint(input.buf.buffer.len + 1)
		input.buf.gap_size = 0
		input.buf.grow_gap_right(0)
	} else if mode == 'trap_insert_add' {
		input.buf.cursor = ~uint(0)
		input.buf.insert_slice_at_cursor('x')
	} else if mode == 'trap_slice_short' {
		mut output := []u8{len: 2}
		input.slice_to_cursor_into(mut output)
	} else if mode == 'trap_slice_alias' {
		input.slice_to_cursor_into(mut input.buf.buffer)
	} else if mode == 'trap_unicode' {
		input.insert_slice_at_cursor(bytes('ffcc81'))
	}
	println('UNEXPECTED')
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1])
		return
	}
	mut output := strings.new_builder(1024)
	codes := [vaxis.backspace, vaxis.delete, vaxis.left, vaxis.right, vaxis.home, vaxis.end, u32(`a`),
		u32(`b`), u32(`d`), u32(`e`), u32(`f`), u32(`k`), u32(`u`), u32(`w`), u32(`x`)]
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		parts := line.split('|')
		mut input := vaxis.TextInput.new()
		match parts[0] {
			'I' {
				for _ in 0 .. int(uint(parts, 2)) {
					input.insert_slice_at_cursor(bytes(parts[1]))
				}
			}
			'B' {
				input.buf.insert_slice_at_cursor(bytes(parts[1]))
				input.buf.move_gap_left(uint(parts, 2))
				input.buf.move_gap_right(uint(parts, 3))
				input.buf.grow_gap_right(uint(parts, 5))
				input.buf.grow_gap_left(uint(parts, 4))
			}
			'S' {
				input.buf.insert_slice_at_cursor(bytes(parts[1]))
				input.buf.move_gap_left(uint(parts, 2))
				mut buffer := []u8{len: int(input.buf.cursor + uint(parts, 3)), init: 0xa5}
				prefix := input.slice_to_cursor_into(mut buffer)
				output.write_string('${u8(uint(prefix.data) == uint(buffer.data))};${hex.encode(prefix)};${hex.encode(buffer)};')
			}
			'D' {
				input.insert_slice_at_cursor(bytes(parts[1]))
				for _ in 0 .. int(uint(parts, 2)) {
					input.cursor_left()
				}
				input.draw_offset = u16(uint(parts, 6))
				input.prev_cursor_col = 19
				input.prev_cursor_idx = 23
				mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 16, rows: 2 })
				screen.width_method = unsafe { vaxis.GWidthMethod(uint(parts, 5)) }
				win := vaxis.Window.new(&screen).child(vaxis.WindowChildOptions{
					width:  u16(uint(parts, 3))
					height: u16(uint(parts, 4))
				})
				input.draw_in_window_with_style(win, style(uint(parts, 7)))
				output.write_string('${screen.cursor_col},${screen.cursor_row},${u8(screen.cursor_vis)};')
				for value in screen.buf {
					cell(mut output, value)
				}
				screen.deinit()
			}
			'E' {
				input.buf.insert_slice_at_cursor(bytes(parts[1]))
				input.buf.move_gap_left(uint(parts, 2))
				match uint(parts, 3) {
					0 { input.cursor_left() }
					1 { input.cursor_right() }
					2 { input.delete_before_cursor() }
					3 { input.delete_after_cursor() }
					else {}
				}

				input.draw_offset = u16(uint(parts, 5))
				mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 16, rows: 2 })
				screen.width_method = unsafe { vaxis.GWidthMethod(uint(parts, 4)) }
				win := vaxis.Window.new(&screen).child(vaxis.WindowChildOptions{
					width:  u16(uint(parts, 6))
					height: 1
				})
				output.write_string('${input.graphemes_before_cursor()},${input.width_to_cursor_method(screen.width_method)};')
				input.draw_in_window_with_style(win, style(uint(parts, 7)))
				output.write_string('${screen.cursor_col},${screen.cursor_row},${u8(screen.cursor_vis)};')
				for value in screen.buf {
					cell(mut output, value)
				}
				screen.deinit()
			}
			'U' {
				input.insert_slice_at_cursor(bytes(parts[1]))
				for _ in 0 .. int(uint(parts, 2)) {
					input.cursor_left()
				}
				input.update(vaxis.Key{
					codepoint: codes[int(uint(parts, 3))]
					mods:      vaxis.Modifiers.from_int(u8(uint(parts, 4)))
					text:      if parts[5] == 'none' { none } else { bytes(parts[5]) }
				})
			}
			else {
				panic('mode')
			}
		}

		state(mut output, input)
		input.deinit()
		output.write_string('\n')
	}
	print(output.str())
}
