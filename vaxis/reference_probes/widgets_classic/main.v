module main

import os
import encoding.hex
import strconv
import strings
import vaxis

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
	output.write_string('${hex.encode(value.char_.grapheme.bytes())}/${value.char_.width}/${color(value.style.fg)}/${color(value.style.bg)}/${color(value.style.ul)}/${u8(value.style.ul_style)}/${flags}/${u8(value.default_)}/${u8(value.wrapped)}/${value.link.uri}/${value.link.params};')
	output.write_string('${value.scale.scale()},${value.scale.numerator()},${value.scale.denominator()},${u8(value.scale.vertical_alignment())},')
	if img := value.image {
		output.write_string('${img.img_id};')
	} else {
		output.write_string('none;')
	}
}

fn key(parts []string, code_index int, mods_index int) vaxis.Key {
	return vaxis.Key{
		codepoint: codes[int(uint(parts, code_index))]
		mods:      vaxis.Modifiers.from_int(u8(uint(parts, mods_index)))
	}
}

const clusters = ['a', ' ', 'é', '界', '👩‍💻', '\n', '\r\n', '\t', '\x00', 'é',
	'🏳️‍🌈', '']

fn screen_values(mut output strings.Builder, screen vaxis.Screen) {
	for value in screen.buf {
		cell(mut output, value)
	}
}

fn trap(mode string) {
	mut view := vaxis.View.init(vaxis.ViewConfig{
		width:  if mode == 'trap_src' { u16(1024) } else { 4 }
		height: if mode == 'trap_src' { u16(65) } else { 2 }
	})
	mut screen := vaxis.Screen.new(vaxis.Winsize{
		cols: if mode == 'trap_src' { u16(1024) } else { 4 }
		rows: if mode == 'trap_src' { u16(65) } else { 2 }
	})
	mut win := vaxis.Window.new(&screen)
	match mode {
		'trap_glyph', 'trap_grapheme', 'trap_style_index' {
			mut buffer := vaxis.TextViewBuffer{
				content:  if mode == 'trap_glyph' { 'a'.repeat(256) } else { 'a' }
				grapheme: [
					vaxis.TextViewGrapheme{
						offset: if mode == 'trap_grapheme' { u32(8) } else { 0 }
						len:    if mode == 'trap_glyph' { u16(256) } else { 1 }
					},
				]
				cols:     256
				rows:     1
			}
			if mode == 'trap_style_index' { buffer.style_map[u64(0)] = ~usize(0) }
			mut text := vaxis.TextView{
				scroll_view: vaxis.ScrollView{
					vertical_scrollbar: none
				}
			}
			text.draw(win, buffer)
		}
		'trap_dst' {
			screen.width = 65535
			win = vaxis.Window{
				...win
				width: 1
				x_off: 1
			}
			view.draw(win, vaxis.ViewDrawOptions{})
		}
		'trap_src' {
			view.draw(win, vaxis.ViewDrawOptions{})
		}
		'trap_negx' {
			win = vaxis.Window{
				...win
				x_off: -1
			}
			view.draw(win, vaxis.ViewDrawOptions{})
		}
		'trap_negy' {
			win = vaxis.Window{
				...win
				y_off: -1
			}
			view.draw(win, vaxis.ViewDrawOptions{})
		}
		'trap_bounds' {
			win = vaxis.Window{
				...win
				x_off: 3
			}
			view.draw(win, vaxis.ViewDrawOptions{})
		}
		'trap_zero' {
			view.screen.width = 0
			view.to_win(win, vaxis.ViewRenderConfig{}) or { panic(err) }
		}
		'trap_slice' {
			screen.buf = view.screen.buf[1..]
			view.draw(vaxis.Window{ ...win, width: 2, height: 1 }, vaxis.ViewDrawOptions{})
		}
		'trap_overlap', 'trap_same' {
			own := view.window()
			view.draw(vaxis.Window{
				...own
				x_off: if mode == 'trap_overlap' { 1 } else { 0 }
				width: 2
			}, vaxis.ViewDrawOptions{})
		}
		'trap_lines' {
			vaxis.LineNumbers{
				num_lines: 0
			}.draw(win, 0)
		}
		'trap_highlight' {
			vaxis.LineNumbers{
				num_lines:        2
				highlighted_line: 1
			}.draw(vaxis.Window{ ...win, width: 0 }, 0)
		}
		'trap_scroll' {
			vaxis.LineNumbers{}.draw(win, ~usize(0))
		}
		'trap_digit' {
			println(vaxis.LineNumbers.extract_digit(0, 20))
		}
		'trap_style' {
			mut buffer := vaxis.TextViewBuffer{}
			buffer.update_style(vaxis.TextViewBufferStyle{ begin: 1, end: 0, style: vaxis.Style{} }) or {
				panic(err)
			}
		}
		else {
			panic('unknown trap')
		}
	}
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1])
		return
	}
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(4 * 1024 * 1024)
	for line in contents.split_into_lines() {
		parts := line.split('|')
		match parts[0] {
			'H' {
				value := uint(parts, 1)
				output.write_string('${vaxis.LineNumbers.num_digits(value)};${u64(vaxis.LineNumbers.extract_digit(value, uint(parts,
					2))).str()};')
			}
			'D', 'R', 'P' {
				mut view := vaxis.View.init(vaxis.ViewConfig{
					width:  u16(uint(parts, 1))
					height: u16(uint(parts, 2))
				})
				view.clear()
				for index in 0 .. view.screen.buf.len {
					view.write_cell(u16(index % int(view.screen.width)),
						u16(index / int(view.screen.width)), vaxis.Cell{
						char_:    vaxis.CellCharacter{
							grapheme: clusters[index % 5]
							width:    u8(index % 3)
						}
						style:    style(usize(index % 4))
						link:     vaxis.CellHyperlink{
							uri:    'uri'
							params: 'id=x'
						}
						default_: index % 2 == 0
						wrapped:  index % 3 == 0
						scale:    vaxis.CellScale.init(u8(index % 8), u8(index % 16),
							u8(index % 16), unsafe { vaxis.VerticalAlignment(index % 3) })
						image:    if index % 2 == 0 {
							vaxis.ImagePlacement{
								img_id: 7
							}
						} else {
							none
						}
					})
				}
				mut screen := vaxis.Screen.new(vaxis.Winsize{
					cols: u16(uint(parts, 3))
					rows: u16(uint(parts, 4))
				})
				win := vaxis.Window{
					parent_x_off: 0
					parent_y_off: 0
					x_off:        parts[5].int()
					y_off:        parts[6].int()
					width:        u16(uint(parts, 7))
					height:       u16(uint(parts, 8))
					screen:       &screen
				}
				if parts[0] == 'D' {
					view.draw(win, vaxis.ViewDrawOptions{
						x_off: u16(uint(parts, 9))
						y_off: u16(uint(parts, 10))
					})
				} else if parts[0] == 'R' {
					width := if uint(parts, 11) == 0 { vaxis.ViewExtent(vaxis.ViewExtentFit{}) } else { vaxis.ViewExtent(vaxis.ViewExtentMax{
							value: u16(uint(parts, 12))
						}) }
					height := if uint(parts, 13) == 0 { vaxis.ViewExtent(vaxis.ViewExtentFit{}) } else { vaxis.ViewExtent(vaxis.ViewExtentMax{
							value: u16(uint(parts, 14))
						}) }
					x, y := view.to_win(win, vaxis.ViewRenderConfig{
						x:      u16(uint(parts, 9))
						y:      u16(uint(parts, 10))
						width:  width
						height: height
					}) or { panic(err) }
					output.write_string('${x},${y};')
				} else {
					view.clear()
					view.screen.width_method = unsafe { vaxis.GWidthMethod(uint(parts, 9)) }
					text := clusters[int(uint(parts, 10))]
					segment := vaxis.CellSegment{
						text:  text
						style: style(1)
						link:  vaxis.CellHyperlink{
							uri:    'uri'
							params: 'id=x'
						}
					}
					result := view.print_segment(segment, vaxis.PrintOptions{
						wrap:       unsafe { vaxis.PrintWrap(uint(parts, 11)) }
						commit:     uint(parts, 12) != 0
						col_offset: u16(uint(parts, 13))
						row_offset: u16(uint(parts, 14))
					})
					output.write_string('${view.gwidth(text)};${result.col},${result.row},${u8(result.overflow)};')
					if value := view.read_cell(u16(uint(parts, 13)), u16(uint(parts, 14))) {
						cell(mut output, value)
					} else {
						output.write_string('none;')
					}
				}
				screen_values(mut output, screen)
				if parts[0] == 'P' { screen_values(mut output, view.screen) }
				view.deinit()
			}
			'N' {
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

				vaxis.LineNumbers{
					num_lines:         uint(parts, 7)
					highlighted_line:  uint(parts, 9)
					style:             style(uint(parts, 10))
					highlighted_style: style(uint(parts, 11))
				}.draw(win, uint(parts, 8))
				screen_values(mut output, screen)
			}
			'T' {
				mut buffer := vaxis.TextViewBuffer{}
				mut x := usize(0)
				for raw in parts[1].split(',') {
					cluster := clusters[raw.int()]
					buffer.grapheme << vaxis.TextViewGrapheme{
						offset: u32(buffer.content.len)
						len:    u16(cluster.len)
					}
					buffer.content += cluster
					if cluster == '\n' {
						buffer.cols = if buffer.cols > x { buffer.cols } else { x }
						x = 0
						buffer.rows++
					} else {
						x += usize(vaxis.gwidth(cluster, .unicode))
					}
				}
				adapter := buffer.writer()
				output.write_string('${u8(adapter.buffer == &buffer)},${u8(adapter.writer().buffer == &buffer)};')
				buffer.last_cols = x
				if x > buffer.cols { buffer.cols = x }
				for i in 0 .. 3 {
					buffer.update_style(vaxis.TextViewBufferStyle{
						begin: usize(i)
						end:   usize(buffer.content.len + i)
						style: style(usize(i % 2 + 1))
					}) or { panic(err) }
				}
				output.write_string('${buffer.style_list.len},${buffer.style_map.len};${u64(buffer.rows).str()},${u64(buffer.cols).str()},${u64(buffer.last_cols).str()};')
				mut screen := vaxis.Screen.new(vaxis.Winsize{
					cols: u16(uint(parts, 2))
					rows: u16(uint(parts, 3))
				})
				screen.width_method = unsafe { vaxis.GWidthMethod(uint(parts, 8)) }
				win := vaxis.Window.new(&screen).child(vaxis.WindowChildOptions{
					x_off:  parts[4].int()
					y_off:  parts[5].int()
					width:  u16(uint(parts, 6))
					height: u16(uint(parts, 7))
				})
				mut view := vaxis.TextView{
					scroll_view: vaxis.ScrollView{
						scroll:             vaxis.ScrollViewScroll{
							x: uint(parts, 9)
							y: uint(parts, 10)
						}
						vertical_scrollbar: if uint(parts, 11) == 0 {
							none
						} else {
							vaxis.ScrollViewVerticalScrollbar{}
						}
					}
				}
				view.input(key(parts, 12, 13))
				view.draw(win, buffer)
				output.write_string('${u64(view.scroll_view.scroll.x).str()},${u64(view.scroll_view.scroll.y).str()};')
				screen_values(mut output, screen)
				buffer.clear()
				output.write_string('${buffer.content.len},${buffer.grapheme.len},${buffer.style_list.len},${buffer.style_map.len},${u64(buffer.rows).str()},${u64(buffer.cols).str()},${u64(buffer.last_cols).str()};')
			}
			'I' {
				mut view := vaxis.CodeView{}
				view.input(key(parts, 1, 2))
				output.write_string('${u64(view.scroll_view.scroll.x).str()},${u64(view.scroll_view.scroll.y).str()},${u8(view.scroll_view.vertical_scrollbar != none)};')
				cell(mut output, view.indentation_cell)
			}
			else {
				panic('mode')
			}
		}

		output.write_string('\n')
	}
	print(output.str())
}
