module main

import os
import vaxis as v

fn window(value v.Window, screen &v.Screen) {
	println('W|${value.x_off},${value.y_off},${value.parent_x_off},${value.parent_y_off},${value.width},${value.height},${int(value.screen == screen)}')
}

fn where_(value v.WindowBorderOptions) u8 {
	return match value.where_ {
		v.BorderNone { 0 }
		v.BorderAll { 1 }
		v.BorderTop { 2 }
		v.BorderRight { 3 }
		v.BorderBottom { 4 }
		v.BorderLeft { 5 }
		v.BorderLocations { 6 }
	}
}

fn glyph(value v.WindowBorderOptions) u8 {
	return match value.glyphs {
		v.BorderSingleRounded { 0 }
		v.BorderSingleSquare { 1 }
		v.BorderCustom { 2 }
	}
}

fn locations(value v.BorderLocations) u8 {
	return u8(value.top) | u8(value.right) << 1 | u8(value.bottom) << 2 | u8(value.left) << 3
}

fn main() {
	if os.args.len > 1 {
		println('Locations|${sizeof(v.BorderLocations)}|${sizeof(v.BorderLocations) * 8}')
		println('Window|${sizeof(v.Window)}')
		println('PrintResult|${sizeof(v.PrintResult)}')
		println('ChildOptions|${sizeof(v.WindowChildOptions)}')
		println('BorderOptions|${sizeof(v.WindowBorderOptions)}')
		println('Glyphs|${sizeof(v.BorderGlyphs)}')
		return
	}
	child := v.WindowChildOptions{}
	border := v.WindowBorderOptions{}
	loc := v.BorderLocations{}
	opts := v.PrintOptions{}
	println('D|${child.x_off},${child.y_off},${int(child.width == none)},${int(child.height == none)},${where_(child.border)}')
	println('D|${int(border.style == v.Style{})},${where_(border)},${glyph(border)}')
	println('D|${locations(loc)}')
	println('D|${opts.row_offset},${opts.col_offset},${int(opts.wrap)},${int(opts.commit)}')
	mut screen := v.Screen{}
	offsets := [-65536, -1, 0, 1, 65535]
	sizes := [u16(0), 1, 255, 65535]
	for field in 0 .. 4 {
		for offset in offsets {
			for size in sizes {
				value := v.Window{
					x_off:        if field == 0 { offset } else { 0 }
					y_off:        if field == 1 { offset } else { 0 }
					parent_x_off: if field == 2 { offset } else { 0 }
					parent_y_off: if field == 3 { offset } else { 0 }
					width:        size
					height:       size
					screen:       &screen
				}
				window(value, &screen)
			}
		}
	}
	for col in sizes {
		for row in sizes {
			for overflow in [false, true] {
				value := v.PrintResult{
					col:      col
					row:      row
					overflow: overflow
				}
				println('R|${value.col},${value.row},${int(value.overflow)}')
			}
		}
	}
	for mask in 0 .. 16 {
		value := v.BorderLocations{
			top:    mask & 1 != 0
			right:  mask & 2 != 0
			bottom: mask & 4 != 0
			left:   mask & 8 != 0
		}
		println('L|${locations(value)}')
	}
	for index in 0 .. 7 {
		for g in 0 .. 3 {
			value := v.WindowBorderOptions{
				where_: match index {
					0 {
						v.BorderWhere(v.BorderNone{})
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
							top:  true
							left: true
						}
					}
				}
				glyphs: match g {
					0 {
						v.BorderGlyphs(v.BorderSingleRounded{})
					}
					1 {
						v.BorderSingleSquare{}
					}
					else {
						v.BorderCustom{
							glyphs: ['0', '1', '2', '3', '4', '5']!
						}
					}
				}
				style:  v.Style{
					bold: true
				}
			}
			bits := if value.where_ is v.BorderLocations { locations(value.where_) } else { u8(0) }
			mut line := 'B|${where_(value)},${glyph(value)},${int(value.style.bold)},${bits}'
			if value.glyphs is v.BorderCustom {
				for s in value.glyphs.glyphs {
					line += '|${s}'
				}
			}
			println(line)
		}
	}
	for offset in offsets {
		for w in 0 .. 3 {
			for h in 0 .. 3 {
				value := v.WindowChildOptions{
					x_off:  offset
					y_off:  offset
					width:  if w == 0 {
						none
					} else if w == 1 {
						u16(0)
					} else {
						u16(65535)
					}
					height: if h == 0 {
						none
					} else if h == 1 {
						u16(0)
					} else {
						u16(65535)
					}
				}
				width := value.width or { u16(0) }
				height := value.height or { u16(0) }
				println('C|${value.x_off},${value.y_off},${int(value.width != none)},${width},${int(value.height != none)},${height},${where_(value.border)},${glyph(value.border)}')
			}
		}
	}
	for row in sizes {
		for col in sizes {
			for wrap in [v.PrintWrap.grapheme, .word, .none] {
				for commit in [false, true] {
					value := v.PrintOptions{
						row_offset: row
						col_offset: col
						wrap:       wrap
						commit:     commit
					}
					println('P|${value.row_offset},${value.col_offset},${int(value.wrap)},${int(value.commit)}')
				}
			}
		}
	}
	mut text := 'tl'.bytes()
	mut glyphs := [unsafe { tos(text.data, text.len) }, 'h', 'tr', 'v', 'br', 'bl']!
	custom := v.BorderCustom{
		glyphs: glyphs
	}
	glyphs[0] = 'replacement'
	text[0] = `Z`
	println('A|${custom.glyphs[0]}|${glyphs[0]}|${int(custom.glyphs[0].str == text.data)}')
	value := v.Window{
		x_off:        0
		y_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        7
		height:       3
		screen:       &screen
	}
	screen.width = 13
	screen.height = 9
	println('S|${value.width},${value.height},${value.screen.width},${value.screen.height}')
	mut changed := value
	original := changed
	mut other := v.Screen{}
	changed.x_off = -1
	changed.y_off = 1
	changed.parent_x_off = -2
	changed.parent_y_off = -3
	changed.width = 11
	changed.height = 12
	changed.screen = &other
	println('M|${changed.x_off},${changed.y_off},${changed.parent_x_off},${changed.parent_y_off},${changed.width},${changed.height},${int(changed.screen == &other)},${original.width},${int(original.screen == &screen)}')
	mut result := v.PrintResult{
		col:      1
		row:      2
		overflow: false
	}
	old_result := result
	result.col = 3
	result.row = 4
	result.overflow = true
	println('M|${result.col},${result.row},${int(result.overflow)},${old_result.col},${old_result.row},${int(old_result.overflow)}')
	mut changed_child := v.WindowChildOptions{}
	old_child := changed_child
	changed_child.x_off = -7
	changed_child.y_off = 9
	changed_child.width = u16(0)
	changed_child.height = u16(65535)
	changed_child.border = v.WindowBorderOptions{
		style:  v.Style{
			bold: true
		}
		where_: v.BorderAll{}
		glyphs: v.BorderSingleSquare{}
	}
	child_width := changed_child.width or { panic('missing width') }
	child_height := changed_child.height or { panic('missing height') }
	println('M|${changed_child.x_off},${changed_child.y_off},${child_width},${child_height},${where_(changed_child.border)},${glyph(changed_child.border)},${int(changed_child.border.style.bold)},${int(old_child.width == none)},${where_(old_child.border)}')
	mut changed_loc := v.BorderLocations{}
	old_loc := changed_loc
	changed_loc.top = true
	changed_loc.right = true
	changed_loc.bottom = true
	changed_loc.left = true
	println('M|${locations(changed_loc)},${locations(old_loc)}')
	mut changed_custom := v.BorderCustom{
		glyphs: ['0', '1', '2', '3', '4', '5']!
	}
	old_custom := changed_custom
	changed_custom.glyphs[0] = 'new'
	println('M|${changed_custom.glyphs[0]},${old_custom.glyphs[0]}')
	mut changed_border := v.WindowBorderOptions{}
	old_border := changed_border
	changed_border.style = v.Style{
		bold: true
	}
	changed_border.where_ = v.BorderAll{}
	changed_border.glyphs = v.BorderSingleSquare{}
	println('M|${int(changed_border.style.bold)},${where_(changed_border)},${glyph(changed_border)},${int(old_border.style.bold)},${where_(old_border)},${glyph(old_border)}')
	mut changed_opts := v.PrintOptions{}
	old_opts := changed_opts
	changed_opts.row_offset = 17
	changed_opts.col_offset = 19
	changed_opts.wrap = .word
	changed_opts.commit = false
	println('M|${changed_opts.row_offset},${changed_opts.col_offset},${int(changed_opts.wrap)},${int(changed_opts.commit)},${old_opts.row_offset},${old_opts.col_offset},${int(old_opts.wrap)},${int(old_opts.commit)}')
	winsizes := [v.Winsize{ rows: 0, cols: 0, x_pixel: 0, y_pixel: 0 },
		v.Winsize{ rows: 1, cols: 1, x_pixel: 7, y_pixel: 9 },
		v.Winsize{ rows: 2, cols: 3, x_pixel: 640, y_pixel: 480 },
		v.Winsize{ rows: 0, cols: 65535, x_pixel: 65535, y_pixel: 65535 }]
	for size in winsizes {
		mut vx := v.Vaxis.new(v.VaxisOptions{})
		vx.screen = v.Screen.new(size)
		root := vx.window()
		window(root, &vx.screen)
		println('V|${vx.screen.width_pix},${vx.screen.height_pix},${vx.screen.buf.len},${int(root.screen == &vx.screen)},${int(vx.screen.cursor_vis)},${int(vx.screen.width_method)}')
	}
}
