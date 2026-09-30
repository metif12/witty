module vxfw

import vaxis

fn empty_draw(_ voidptr, _ DrawContext) !Surface {
	return Surface.empty(Widget{ draw_fn: empty_draw })
}

fn test_surface_source_constraints_and_hit_bounds() {
	widget := Widget{
		draw_fn: empty_draw
	}
	surface := Surface.init(widget, Size{ width: 10, height: 10 })
	assert surface.satisfies_constraints(Size{ width: 1, height: 1 }, Size{
		width:  20
		height: 20
	})
	assert !surface.satisfies_constraints(Size{ width: 10, height: 10 }, Size{
		width:  20
		height: 20
	})
	assert !surface.satisfies_constraints(Size{ width: 1, height: 1 }, Size{
		width:  10
		height: 10
	})
	sub := SubSurface{
		origin:  RelativePoint{
			row: 2
			col: 2
		}
		surface: surface
	}
	for point in [Point{ row: 2, col: 2 }, Point{ row: 3, col: 3 },
		Point{ row: 11, col: 11 }] {
		assert sub.contains_point(point)
	}
	for point in [Point{ row: 1, col: 1 }, Point{ row: 12, col: 12 },
		Point{ row: 2, col: 12 }, Point{ row: 12, col: 2 }] {
		assert !sub.contains_point(point)
	}
}

fn test_surface_trim_preserves_source_buffer_view() {
	widget := Widget{
		draw_fn: empty_draw
	}
	surface := Surface.init(widget, Size{ width: 3, height: 3 })
	trimmed := surface.trim_height(1)
	trimmed.write_cell(1, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: 'x'
		}
	})
	assert surface.read_cell(1, 0).char_.grapheme == 'x'
	assert trimmed.buffer.len == 3
}

fn test_draw_context_global_width_and_command_defaults() {
	ctx := DrawContext{}
	DrawContext.init(.unicode)
	assert ctx.string_width('👩\u200d💻') == 2
	DrawContext.init(.no_zwj)
	assert ctx.string_width('👩\u200d💻') == 4
	DrawContext.init(.unicode)
	mut events := EventContext{}
	assert events.phase == .at_target
	assert events.redraw
	assert !events.consume_event
	events.consume_and_redraw()
	assert events.consume_event
}

fn test_surface_render_stable_z_order_clipping_and_focused_cursor() {
	widget := Widget{
		draw_fn: empty_draw
	}
	mut vx := vaxis.Vaxis.new(vaxis.VaxisOptions{})
	defer { vx.deinit() }
	vx.resize(vaxis.Winsize{ cols: 3, rows: 2 })
	first := Surface.init(widget, Size{ width: 2, height: 1 })
	first.write_cell(0, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: 'a'
		}
	})
	mut second := Surface.init(widget, Size{ width: 2, height: 1 })
	second.write_cell(0, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: 'b'
		}
	})
	second.cursor = CursorState{
		col:   1
		shape: .beam
	}
	back := Surface.init(widget, Size{ width: 1, height: 1 })
	back.write_cell(0, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: 'z'
		}
	})
	surface := Surface{
		size:     Size{
			width:  3
			height: 2
		}
		widget:   widget
		children: [
			SubSurface{
				surface: first
				z_index: 1
			},
			SubSurface{
				surface: second
				z_index: 1
			},
			SubSurface{
				surface: back
				z_index: 0
			},
		]
	}
	surface.render(vx.window(), widget)
	assert surface.children.map(it.z_index) == [u8(0), 1, 1]
	assert vx.screen.buf[0].char_.grapheme == 'b'
	assert vx.screen.cursor_vis
	assert vx.screen.cursor_col == 1
	assert vx.screen.cursor_shape == .beam
}
