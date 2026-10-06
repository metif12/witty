module main

import encoding.hex
import os
import strconv
import strings
import vaxis
import vaxis.vxfw as fw

fn surface_probe_draw(ptr voidptr, ctx fw.DrawContext) !fw.Surface {
	return fw.Surface.empty(widget(unsafe { int(usize(ptr)) - 1 }))
}

fn surface_probe_event(ptr voidptr, mut ctx fw.EventContext, event fw.Event) ! {}

fn widget(index int) fw.Widget {
	mut value := fw.Widget{
		userdata: unsafe { voidptr(usize(index + 1)) }
		draw_fn:  surface_probe_draw
	}
	if index & 1 != 0 { value.event_handler = surface_probe_event }
	if index & 2 != 0 { value.capture_handler = surface_probe_event }
	return value
}

fn id(value fw.Widget) int {
	return unsafe { int(usize(value.userdata)) - 1 }
}

fn cell(index int) vaxis.Cell {
	glyphs := ['r', 'a', '界', 'é']
	return vaxis.Cell{
		char_:   vaxis.CellCharacter{
			grapheme: glyphs[index % 4]
			width:    if index % 4 == 2 { u8(2) } else { u8(1) }
		}
		style:   vaxis.Style{
			fg:   vaxis.ColorIndex{
				index: u8(index % 256)
			}
			bold: index % 2 != 0
		}
		wrapped: index % 3 == 0
	}
}

fn cell_value(mut out strings.Builder, value vaxis.Cell) {
	color := match value.style.fg {
		vaxis.ColorDefault {
			u32(0)
		}
		vaxis.ColorIndex {
			u32(0x1000000) + u32(value.style.fg.index)
		}
		vaxis.ColorRgb {
			u32(0x2000000) + (u32(value.style.fg.rgb[0]) << 16) +
				(u32(value.style.fg.rgb[1]) << 8) + u32(value.style.fg.rgb[2])
		}
	}

	out.write_string('${hex.encode(value.char_.grapheme.bytes())}/${value.char_.width},${int(value.default_)},${int(value.wrapped)},${color},${int(value.style.bold)};')
}

fn hit(mut out strings.Builder, surface fw.Surface, point fw.Point) {
	mut values := []fw.HitResult{}
	surface.hit_test(mut values, point)
	for value in values {
		out.write_string('${id(value.widget)},${value.local.col},${value.local.row};')
	}
}

fn window_root(screen &vaxis.Screen) vaxis.Window {
	return vaxis.Window{
		x_off:        0
		y_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        screen.width
		height:       screen.height
		screen:       screen
	}
}

fn num(parts []string, index int) int {
	return strconv.atoi(parts[index]) or { panic(err) }
}

fn unsigned(parts []string, index int) u16 {
	return u16(num(parts, index))
}

fn optional(parts []string, index int) ?u16 {
	value := num(parts, index)
	return if value < 0 { none } else { u16(value) }
}

fn metadata(mut out strings.Builder, win vaxis.Window, screen &vaxis.Screen) {
	out.write_string('${win.width},${win.height},${win.x_off},${win.y_off},${win.parent_x_off},${win.parent_y_off},${int(win.screen == screen)}')
}

fn trap(mode string) {
	mut screen := vaxis.Screen{}
	mut win := window_root(&screen)
	mut surface := fw.Surface{
		children: []fw.SubSurface{}
		size:     fw.Size{
			width:  1
			height: 1
		}
		widget:   widget(0)
		buffer:   [vaxis.Cell{}]
	}
	if mode == 'trap_create' {
		fw.Surface.create_buffer(fw.Size{ width: 256, height: 256 })
	} else if mode == 'trap_write_mul' {
		surface.size = fw.Size{
			width:  2
			height: 32769
		}
		surface.write_cell(0, 32768, vaxis.Cell{})
	} else if mode == 'trap_write_add' {
		surface.size = fw.Size{
			width:  255
			height: 258
		}
		surface.write_cell(1, 257, vaxis.Cell{})
	} else if mode == 'trap_write_short' {
		surface.size.width = 2
		surface.write_cell(1, 0, vaxis.Cell{})
	} else if mode == 'trap_read_col' {
		surface.read_cell(1, 0)
	} else if mode == 'trap_read_row' {
		surface.read_cell(0, 1)
	} else if mode == 'trap_read_short' {
		surface.buffer = []vaxis.Cell{}
		surface.read_cell(0, 0)
	} else if mode == 'trap_trim_height' {
		surface.trim_height(2)
	} else if mode == 'trap_trim_mul' {
		surface.size = fw.Size{
			width:  256
			height: 256
		}
		surface.trim_height(256)
	} else if mode == 'trap_trim_short' {
		surface.size.width = 2
		surface.trim_height(1)
	} else if mode == 'trap_hit' {
		mut list := []fw.HitResult{}
		surface.hit_test(mut list, fw.Point{ col: 1, row: 0 })
	} else if mode == 'trap_render_mul' {
		surface.size = fw.Size{
			width:  256
			height: 256
		}
		surface.render(win, widget(0))
	} else if mode == 'trap_render_short' {
		surface.size.width = 2
		surface.render(win, widget(0))
	} else if mode == 'trap_contains_col' || mode == 'trap_contains_row' {
		col := mode.ends_with('col')
		sub := fw.SubSurface{
			origin:  fw.RelativePoint{
				col: if col { 65535 } else { 0 }
				row: if col { 0 } else { 65535 }
			}
			surface: surface
		}
		sub.contains_point(fw.Point{
			col: if col { u16(65535) } else { u16(0) }
			row: if col { u16(0) } else { u16(65535) }
		})
	} else if mode.starts_with('trap_child_') {
		mut x := 0
		mut y := 0
		win = vaxis.Window{
			x_off:        0
			y_off:        0
			parent_x_off: 0
			parent_y_off: 0
			width:        1
			height:       1
			screen:       &screen
		}
		if mode.ends_with('max_x') {
			x = -65536
		} else if mode.ends_with('max_y') {
			y = -65536
		} else if mode.ends_with('abs_x') {
			win = vaxis.Window{
				...win
				x_off: 65535
			}
			x = 1
		} else if mode.ends_with('abs_y') {
			win = vaxis.Window{
				...win
				y_off: 65535
			}
			y = 1
		} else if mode.ends_with('parent_x') {
			win = vaxis.Window{
				...win
				parent_x_off: 65535
			}
			x = 1
		} else if mode.ends_with('parent_y') {
			win = vaxis.Window{
				...win
				parent_y_off: 65535
			}
			y = 1
		} else if mode.ends_with('negative_parent') {
			win = vaxis.Window{
				...win
				parent_x_off: -65536
			}
			x = -1
		} else {
			panic('InvalidTrap')
		}
		win.child(vaxis.WindowChildOptions{ x_off: x, y_off: y, width: 0, height: 0 })
	} else if mode == 'trap_cursor_x' || mode == 'trap_cursor_y' {
		win = if mode.ends_with('x') {
			vaxis.Window{
				...win
				x_off: 65535
			}
		} else {
			vaxis.Window{
				...win
				y_off: 65535
			}
		}
		win.show_cursor(1, 1)
	} else if mode.starts_with('trap_window_') {
		win = if mode.ends_with('parent') {
			vaxis.Window{
				x_off:        0
				y_off:        0
				parent_y_off: 0
				width:        2
				height:       2
				parent_x_off: 65535
				screen:       &screen
			}
		} else {
			vaxis.Window{
				y_off:        0
				parent_x_off: 0
				parent_y_off: 0
				width:        2
				height:       2
				x_off:        65535
				screen:       &screen
			}
		}
		if mode.contains('write') {
			win.write_cell(1, 0, vaxis.Cell{})
		} else {
			win.read_cell(1, 0)
		}
	} else {
		panic('InvalidTrap')
	}
	println('UNEXPECTED')
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1])
		return
	}
	data := os.read_file(os.args[1]) or { panic(err) }
	mut number := 0
	for line in data.split_into_lines() {
		if line.len == 0 { continue
		 }
		p := line.split('|')
		mut out := strings.new_builder(256)
		out.write_string('${number}|')
		number++
		if p[0] == 'S' {
			sub := fw.SubSurface{
				origin:  fw.RelativePoint{
					col: i32(num(p, 1))
					row: i32(num(p, 2))
				}
				surface: fw.Surface{
					buffer:   []vaxis.Cell{}
					children: []fw.SubSurface{}
					size:     fw.Size{
						width:  unsigned(p, 3)
						height: unsigned(p, 4)
					}
					widget:   widget(0)
				}
			}
			out.write_string('${int(sub.contains_point(fw.Point{
				col: unsigned(p, 5)
				row: unsigned(p, 6)
			}))}')
		} else if p[0] == 'W' {
			mut screen := vaxis.Screen{}
			win := vaxis.Window{
				width:        unsigned(p, 1)
				height:       unsigned(p, 2)
				x_off:        num(p, 3)
				y_off:        num(p, 4)
				parent_x_off: num(p, 5)
				parent_y_off: num(p, 6)
				screen:       &screen
			}
			child := win.child(vaxis.WindowChildOptions{
				x_off:  num(p, 7)
				y_off:  num(p, 8)
				width:  optional(p, 9)
				height: optional(p, 10)
			})
			metadata(mut out, child, &screen)
		} else if p[0] == 'N' {
			size := fw.Size{
				width:  unsigned(p, 1)
				height: unsigned(p, 2)
			}
			buffer := fw.Surface.create_buffer(size)
			surface := fw.Surface.init(widget(1), size)
			children := [
				fw.SubSurface{
					origin:  fw.RelativePoint{
						row: 0
						col: 0
					}
					surface: fw.Surface.empty(widget(2))
				},
			]
			with_children := fw.Surface.init_with_children(widget(1), size, children)
			empty := fw.Surface.empty(widget(3))
			mut defaults := 0
			for value in buffer {
				if value.default_ { defaults++ }
			}
			out.write_string('${buffer.len},${surface.buffer.len},${with_children.buffer.len},${defaults},${empty.size.width},${empty.size.height},${empty.buffer.len},${int(with_children.children.data == children.data)}|')
			if buffer.len > 0 {
				cell_value(mut out, buffer[0])
				cell_value(mut out, buffer[buffer.len - 1])
			}
		} else if p[0] == 'O' {
			children := [
				fw.SubSurface{
					origin:  fw.RelativePoint{
						row: 0
						col: 0
					}
					surface: fw.Surface.empty(widget(2))
				},
			]
			mut surface := fw.Surface.init_with_children(widget(1), fw.Size{
				width:  unsigned(p, 1)
				height: unsigned(p, 2)
			}, children)
			surface.cursor = fw.CursorState{
				row:   0
				col:   1
				shape: .beam
			}
			surface.write_cell(unsigned(p, 3), unsigned(p, 4), cell(2))
			cell_value(mut out, surface.read_cell(usize(unsigned(p, 5)), usize(unsigned(p, 6))))
			trimmed := surface.trim_height(unsigned(p, 7))
			out.write_string('|${trimmed.size.height},${trimmed.buffer.len},${int(trimmed.cursor == none)},${int(trimmed.buffer.data == surface.buffer.data)},${int(trimmed.children.data == surface.children.data)},${int(trimmed.widget.eql(surface.widget))}|')
			if trimmed.buffer.len > 0 { trimmed.write_cell(0, 0, cell(3)) }
			for value in surface.buffer {
				cell_value(mut out, value)
			}
			out.write_string('|${int(surface.satisfies_constraints(fw.Size{}, fw.Size{
				width:  surface.size.width + 1
				height: surface.size.height + 1
			}))},${int(surface.satisfies_constraints(surface.size, surface.size))}')
		} else if p[0] == 'T' {
			size := fw.Size{
				width:  unsigned(p, 1)
				height: unsigned(p, 2)
			}
			mut c1 := fw.Surface.init(widget(1), fw.Size{ width: 2, height: 2 })
			for i in 0 .. c1.buffer.len {
				c1.buffer[i] = cell(1)
			}
			c1.cursor = fw.CursorState{
				col:   1
				row:   1
				shape: .beam
			}
			mut c2 := fw.Surface.init(widget(2), fw.Size{ width: 2, height: 2 })
			for i in 0 .. c2.buffer.len {
				c2.buffer[i] = cell(2)
			}
			c2.cursor = fw.CursorState{
				col:   0
				row:   0
				shape: .underline
			}
			mut c3 := fw.Surface.init(widget(3), fw.Size{ width: 1, height: 1 })
			c3.buffer[0] = cell(3)
			children := [
				fw.SubSurface{
					origin:  fw.RelativePoint{
						col: i32(num(p, 3))
						row: i32(num(p, 4))
					}
					surface: c1
					z_index: u8(num(p, 5))
				},
				fw.SubSurface{
					origin:  fw.RelativePoint{
						col: i32(num(p, 6))
						row: i32(num(p, 7))
					}
					surface: c2
					z_index: u8(num(p, 8))
				},
				fw.SubSurface{
					origin:  fw.RelativePoint{
						row: 0
						col: 0
					}
					surface: c3
					z_index: u8(num(p, 8))
				},
			]
			mut surface := fw.Surface.init_with_children(widget(0), size, children)
			for i in 0 .. surface.buffer.len {
				surface.buffer[i] = cell(0)
			}
			surface.cursor = fw.CursorState{
				col:   0
				row:   0
				shape: .block
			}
			mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: size.width, rows: size.height })
			point := fw.Point{
				col: unsigned(p, 10)
				row: unsigned(p, 11)
			}
			hit(mut out, surface, point)
			out.write_string('|')
			surface.render(window_root(&screen), widget(num(p, 9)))
			for value in screen.buf {
				cell_value(mut out, value)
			}
			out.write_string('|${int(screen.cursor_vis)},${screen.cursor_col},${screen.cursor_row},${u8(screen.cursor_shape)}|')
			for child in children {
				out.write_string('${id(child.surface.widget)};')
			}
			out.write_string('|')
			hit(mut out, surface, point)
		} else if p[0] == 'C' {
			mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 4, rows: 3 })
			win := vaxis.Window{
				width:        unsigned(p, 1)
				height:       unsigned(p, 2)
				x_off:        num(p, 3)
				y_off:        num(p, 4)
				parent_x_off: num(p, 5)
				parent_y_off: num(p, 6)
				screen:       &screen
			}
			col := unsigned(p, 7)
			row := unsigned(p, 8)
			win.write_cell(col, row, cell(2))
			if value := win.read_cell(col, row) {
				cell_value(mut out, value)
			} else {
				out.write_string('none;')
			}
			win.show_cursor(col, row)
			win.set_cursor_shape(.beam)
			out.write_string('|${int(screen.cursor_vis)},${screen.cursor_col},${screen.cursor_row},${u8(screen.cursor_shape)}|')
			for value in screen.buf {
				cell_value(mut out, value)
			}
		} else {
			panic('InvalidMode')
		}
		println(out.str())
	}
}
