module main

import os
import strconv
import strings
import vaxis

const glyphs = ['▐', '░', 'X', '界', '']
const codes = [vaxis.right, vaxis.left, vaxis.up, vaxis.down, vaxis.page_up, vaxis.page_down, vaxis.end,
	vaxis.home, u32(`a`)]

fn uint(parts []string, index int) usize {
	return usize(strconv.parse_uint(parts[index], 10, 64) or { panic(err) })
}

fn style(index usize) vaxis.Style {
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
	output.write_string('${value.char_.grapheme}/${value.char_.width}/${color(value.style.fg)}/${color(value.style.bg)}/${color(value.style.ul)}/${u8(value.style.ul_style)}/${flags}/${u8(value.default_)}/${u8(value.wrapped)}/${value.link.uri}/${value.link.params};')
}

fn window(mut output strings.Builder, value vaxis.Window) {
	output.write_string('${value.x_off},${value.y_off},${value.parent_x_off},${value.parent_y_off},${value.width},${value.height};')
}

fn key(parts []string, code_index int, mods_index int) vaxis.Key {
	return vaxis.Key{
		codepoint: codes[int(uint(parts, code_index))]
		mods:      vaxis.Modifiers.from_int(u8(uint(parts, mods_index)))
	}
}

fn trap(mode string) {
	mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 1, rows: 2 })
	win := vaxis.Window.new(&screen)
	maximum := ~usize(0)
	bar := if mode == 'overflow_view' {
		vaxis.Scrollbar{
			total:     maximum
			view_size: maximum - 1
		}
	} else if mode == 'overflow_top' {
		vaxis.Scrollbar{
			total:     maximum
			view_size: 1
			top:       maximum
		}
	} else {
		vaxis.Scrollbar{
			total:     2
			view_size: 1
			top:       65536
		}
	}
	bar.draw(win)
}

fn main() {
	if os.args[1].starts_with('overflow_') || os.args[1] == 'row_cast' {
		trap(os.args[1])
		return
	}
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(4 * 1024 * 1024)
	for line in contents.split_into_lines() {
		parts := line.split('|')
		match parts[0] {
			'A' {
				mut screen := vaxis.Screen{}
				parent := vaxis.Window{
					width:        u16(uint(parts, 1))
					height:       u16(uint(parts, 2))
					x_off:        parts[3].int()
					y_off:        parts[4].int()
					parent_x_off: parts[5].int()
					parent_y_off: parts[6].int()
					screen:       &screen
				}
				cols := u16(uint(parts, 7))
				rows := u16(uint(parts, 8))
				window(mut output, vaxis.alignment_center(parent, cols, rows))
				window(mut output, vaxis.alignment_top_left(parent, cols, rows))
				window(mut output, vaxis.alignment_top_right(parent, cols, rows))
				window(mut output, vaxis.alignment_bottom_left(parent, cols, rows))
				window(mut output, vaxis.alignment_bottom_right(parent, cols, rows))
			}
			'I' {
				mut view := vaxis.ScrollView{
					scroll: vaxis.ScrollViewScroll{
						x: uint(parts, 1)
						y: uint(parts, 2)
					}
				}
				view.input(key(parts, 3, 4))
				output.write_string('${u64(view.scroll.x).str()},${u64(view.scroll.y).str()};')
			}
			'R' {
				mut scroll := vaxis.ScrollViewScroll{
					x: uint(parts, 1)
					y: uint(parts, 2)
				}
				scroll.restrict_to(uint(parts, 3), uint(parts, 4))
				output.write_string('${u64(scroll.x).str()},${u64(scroll.y).str()};')
			}
			'G' {
				mut screen := vaxis.Screen{}
				parent := vaxis.Window{
					width:  u16(uint(parts, 1))
					height: u16(uint(parts, 2))
					screen: &screen
				}
				mut view := vaxis.ScrollView{
					scroll:             vaxis.ScrollViewScroll{
						x: uint(parts, 4)
						y: uint(parts, 5)
					}
					vertical_scrollbar: none
				}
				if uint(parts, 3) != 0 {
					view.vertical_scrollbar = vaxis.ScrollViewVerticalScrollbar{}
				}
				bounds := view.bounds(parent)
				col := uint(parts, 6)
				row := uint(parts, 7)
				output.write_string('${u64(bounds.x1).str()},${u64(bounds.y1).str()},${u64(bounds.x2).str()},${u64(bounds.y2).str()};${u8(bounds.below(row))},${u8(bounds.above(row))},${u8(bounds.row_inside(row))},${u8(bounds.col_inside(col))},${u8(bounds.inside(col,
					row))};')
			}
			'B', 'C' {
				mut screen := vaxis.Screen.new(vaxis.Winsize{
					cols: u16(uint(parts, 1))
					rows: u16(uint(parts, 2))
				})
				win := vaxis.Window.new(&screen).child(vaxis.WindowChildOptions{
					x_off:  parts[3].int()
					y_off:  parts[4].int()
					width:  u16(uint(parts, 5))
					height: u16(uint(parts, 6))
				})
				if parts[0] == 'B' {
					bar := vaxis.Scrollbar{
						character: vaxis.CellCharacter{
							grapheme: glyphs[int(uint(parts, 7))]
							width:    u8(uint(parts, 8))
						}
						style:     style(uint(parts, 9))
						top:       uint(parts, 10)
						total:     uint(parts, 11)
						view_size: uint(parts, 12)
					}
					bar.draw(win)
				} else {
					mut view := vaxis.ScrollView{
						scroll:             vaxis.ScrollViewScroll{
							x: uint(parts, 7)
							y: uint(parts, 8)
						}
						vertical_scrollbar: none
					}
					if uint(parts, 11) != 0 {
						view.vertical_scrollbar = vaxis.ScrollViewVerticalScrollbar{
							character: vaxis.CellCharacter{
								grapheme: glyphs[int(uint(parts, 12))]
								width:    u8(uint(parts, 13))
							}
							fg:        style(2)
							bg:        style(1)
						}
					}
					view.input(key(parts, 14, 15))
					output.write_string('${u64(view.scroll.x).str()},${u64(view.scroll.y).str()};')
					view.draw(win, vaxis.ScrollViewContentSize{
						cols: uint(parts, 9)
						rows: uint(parts, 10)
					})
					bounds := view.bounds(win)
					col := uint(parts, 16)
					row := uint(parts, 17)
					output.write_string('${u64(view.scroll.x).str()},${u64(view.scroll.y).str()},${u64(bounds.x1).str()},${u64(bounds.y1).str()},${u64(bounds.x2).str()},${u64(bounds.y2).str()};${u8(bounds.below(row))},${u8(bounds.above(row))},${u8(bounds.row_inside(row))},${u8(bounds.col_inside(col))},${u8(bounds.inside(col,
						row))};')
					view.write_cell(win, col, row, vaxis.Cell{
						char_:   vaxis.CellCharacter{
							grapheme: '#'
							width:    2
						}
						style:   style(2)
						link:    vaxis.CellHyperlink{
							uri:    'https://example.test/'
							params: 'id=content'
						}
						wrapped: true
					})
					if bounds.inside(col, row) {
						if value := win.read_cell(u16(col - view.scroll.x),
							u16(row - view.scroll.y))
						{
							cell(mut output, value)
						} else {
							output.write_string('none;')
						}
					} else {
						output.write_string('none;')
					}
				}
				for value in screen.buf {
					cell(mut output, value)
				}
			}
			else {
				panic('InvalidMode')
			}
		}

		output.write_u8(`\n`)
	}
	print(output.str())
}
