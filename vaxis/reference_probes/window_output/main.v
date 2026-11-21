module main

import os
import encoding.hex
import strings
import vaxis as v

fn n(p []string, i int) int {
	return p[i].int()
}

fn u(p []string, i int) u16 {
	return u16(n(p, i))
}

fn win(screen &v.Screen, width u16, height u16, x int, y int, px int, py int) v.Window {
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

fn segment(text string, index u8) v.CellSegment {
	return v.CellSegment{
		text:  text
		style: v.Style{
			fg:   v.ColorIndex{
				index: index
			}
			bold: index == 2
		}
		link:  v.CellHyperlink{
			uri:    if index == 1 { 'one' } else { 'two' }
			params: 'id=probe'
		}
	}
}

fn cell(mut out strings.Builder, c v.Cell, original string) {
	color := match c.style.fg {
		v.ColorDefault { u16(0) }
		v.ColorIndex { u16(c.style.fg.index) + 1 }
		else { panic('unexpected color') }
	}

	pointer := uint(c.char_.grapheme.str)
	start := uint(original.str)
	offset := if c.char_.grapheme.len > 0 && pointer >= start
		&& pointer + uint(c.char_.grapheme.len) <= start + uint(original.len) {
		i64(pointer - start)
	} else {
		i64(-1)
	}
	out.write_string('${hex.encode(c.char_.grapheme.bytes())}/${c.char_.width},${int(c.default_)},${int(c.wrapped)},${color},${int(c.style.bold)},${c.link.uri},${c.link.params},${offset};')
}

fn trap(name string) {
	mut screen := v.Screen{}
	mut w := win(&screen, 0, 0, 0, 0, 0, 0)
	mut opts := v.PrintOptions{
		commit: false
	}
	mut text := 'a'
	if name.starts_with('trap_width_') {
		screen.width_method = .no_zwj
		w = v.Window{
			...w
			width:  65535
			height: 1
		}
		w.print_segment(v.CellSegment{ text: '👩\u200d'.repeat(130) }, v.PrintOptions{
			wrap: if name.ends_with('word') {
				.word
			} else if name.ends_with('none') {
				.none
			} else {
				.grapheme
			}
		})
	} else if name == 'trap_fill_x' {
		w = v.Window{
			...w
			x_off: 65535
			width: 1
		}
		w.fill(v.Cell{})
	} else if name == 'trap_fill_y' {
		w = v.Window{
			...w
			y_off:  65535
			height: 1
		}
		w.fill(v.Cell{})
	} else {
		if name == 'trap_row_initial' {
			opts = v.PrintOptions{
				...opts
				row_offset: 65535
			}
		} else if name == 'trap_row_final' {
			opts = v.PrintOptions{
				...opts
				row_offset: 65535
			}
			text = ''
		} else if name in ['trap_col', 'trap_wrapped'] {
			w = v.Window{
				...w
				width:  65535
				height: 1
			}
			opts = v.PrintOptions{
				...opts
				col_offset: 65534
				commit:     name == 'trap_wrapped'
			}
			text = '界'
		} else if name == 'trap_word_sum' {
			w = v.Window{
				...w
				width: 65535
			}
			opts = v.PrintOptions{
				...opts
				wrap:       .word
				col_offset: 65535
			}
		} else if name == 'trap_word_whitespace' {
			opts = v.PrintOptions{
				...opts
				wrap:       .word
				row_offset: 65535
			}
			text = ' '
		} else if name == 'trap_word_defer' {
			w = v.Window{
				...w
				width: 1
			}
			opts = v.PrintOptions{
				...opts
				wrap:       .word
				row_offset: 65535
			}
			text = '\n'
		} else if name.starts_with('trap_unicode_') {
			text = '\xff\xcc\x81'
			opts = v.PrintOptions{
				...opts
				wrap: if name.ends_with('word') {
					.word
				} else if name.ends_with('none') {
					.none
				} else {
					.grapheme
				}
			}
		} else {
			panic('invalid trap')
		}
		w.print_segment(v.CellSegment{ text: text }, opts)
	}
	println('UNEXPECTED')
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1])
		return
	}
	input := os.read_file(os.args[1]) or { panic(err) }
	mut out := strings.new_builder(65536)
	mut number := 0
	for row in input.split_into_lines() {
		if row == '' { continue
		 }
		p := row.split('|')
		mut screen := v.Screen{
			width:  u(p, 1)
			height: u(p, 2)
		}
		size := if p[0] == 'F' { n(p, 3) } else { int(screen.width) * int(screen.height) }
		screen.buf = []v.Cell{len: size, init: v.Cell{
			char_:    v.CellCharacter{
				grapheme: 'o'
			}
			default_: true
		}}
		w := win(&screen, u(p, 4), u(p, 5), n(p, 6), n(p, 7), n(p, 8), n(p, 9))
		out.write_string('${number}|')
		number++
		if p[0] == 'F' {
			if n(p, 10) == 0 {
				w.fill(v.Cell{
					char_:   v.CellCharacter{
						grapheme: 'x'
						width:    2
					}
					style:   v.Style{
						fg: v.ColorIndex{
							index: 9
						}
					}
					wrapped: true
				})
			} else {
				w.clear()
			}
			for value in screen.buf {
				cell(mut out, value, '')
			}
		} else {
			screen.width_method = unsafe { v.GWidthMethod(n(p, 14)) }
			data := hex.decode(p[16]) or { panic(err) }
			text := data.bytestr()
			cut := n(p, 15)
			mut values := []v.CellSegment{}
			if cut < 0 {
				values << segment(text, 1)
			} else {
				values << segment(text.substr_unsafe(0, cut), 1)
				values << segment(text.substr_unsafe(cut, text.len), 2)
			}
			opts := v.PrintOptions{
				wrap:       unsafe { v.PrintWrap(n(p, 10)) }
				row_offset: u(p, 11)
				col_offset: u(p, 12)
				commit:     n(p, 13) != 0
			}
			result := if cut < 0 { w.print_segment(values[0], opts) } else { w.print(values, opts) }
			out.write_string('${result.col},${result.row},${int(result.overflow)}|')
			for value in screen.buf {
				cell(mut out, value, text)
			}
			out.write_string('|')
			unsafe { C.memset(text.str, `Z`, uint(text.len)) }
			for value in screen.buf {
				out.write_string(hex.encode(value.char_.grapheme.bytes()))
			}
		}
		out.write_string('\n')
	}
	print(out.str())
}
