module vxfw

import vaxis

fn surface_fidelity_draw(ptr voidptr, ctx DrawContext) !Surface {
	return Surface.empty(Widget{ userdata: ptr, draw_fn: surface_fidelity_draw })
}

fn surface_fidelity_event(ptr voidptr, mut ctx EventContext, event Event) ! {}

fn surface_fidelity_widget(index int) Widget {
	return Widget{
		userdata:      unsafe { voidptr(index + 1) }
		draw_fn:       surface_fidelity_draw
		event_handler: surface_fidelity_event
	}
}

fn test_surface_accepts_full_source_signed_origin_range_when_clipped() {
	mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 2, rows: 2 })
	leaf_widget := surface_fidelity_widget(1)
	mut leaf := Surface.init(leaf_widget, Size{ width: 1, height: 1 })
	leaf.write_cell(0, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: 'x'
		}
	})
	leaf.cursor = CursorState{
		row:   0
		col:   0
		shape: .beam
	}
	for offset in [-32769, 32768] {
		surface := Surface{
			size:     Size{
				width:  2
				height: 2
			}
			widget:   surface_fidelity_widget(0)
			children: [
				SubSurface{
					origin:  RelativePoint{
						col: offset
						row: offset
					}
					surface: leaf
				},
			]
		}
		surface.render(vaxis.Window.new(&screen), leaf_widget)
		assert !screen.cursor_vis
		assert screen.cursor_shape == .beam
		assert screen.buf.all(it.char_.grapheme == ' ')
	}
}

fn test_surface_render_changes_later_hit_routing_to_stable_sorted_order() {
	first := surface_fidelity_widget(1)
	second := surface_fidelity_widget(2)
	root_widget := Widget{
		userdata: unsafe { voidptr(1) }
		draw_fn:  surface_fidelity_draw
	}
	surface := Surface{
		size:     Size{
			width:  2
			height: 2
		}
		widget:   root_widget
		children: [
			SubSurface{
				origin:  RelativePoint{
					col: -1
					row: -1
				}
				surface: Surface{
					size:   Size{
						width:  2
						height: 2
					}
					widget: first
				}
				z_index: 2
			},
			SubSurface{
				surface: Surface{
					size:   Size{
						width:  2
						height: 2
					}
					widget: second
				}
				z_index: 1
			},
		]
	}
	mut before := []HitResult{}
	surface.hit_test(mut before, Point{})
	assert before.len == 2
	assert before[0].widget.eql(first)
	assert before[0].local == Point{
		row: 1
		col: 1
	}
	assert before[1].widget.eql(second)
	mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 2, rows: 2 })
	surface.render(vaxis.Window.new(&screen), root_widget)
	mut after := []HitResult{}
	surface.hit_test(mut after, Point{})
	assert after.len == 2
	assert after[0].widget.eql(second)
	assert after[1].widget.eql(first)
}

fn test_surface_last_representable_buffer_keeps_cell_styles() {
	surface := Surface.init(surface_fidelity_widget(0), Size{ width: 65535, height: 1 })
	assert surface.buffer.len == 65535
	assert surface.buffer.all(it.default_)
	expected := vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '界'
			width:    2
		}
		style: vaxis.Style{
			bold: true
			fg:   vaxis.ColorIndex{
				index: 7
			}
		}
	}
	surface.write_cell(65534, 0, expected)
	assert surface.read_cell(65534, 0) == expected
}

fn test_surface_trim_resets_cursor_and_retains_both_borrowed_arrays() {
	children := [SubSurface{ surface: Surface.empty(surface_fidelity_widget(1)) }]
	mut original := Surface.init_with_children(surface_fidelity_widget(0), Size{ width: 2, height: 2 },
		children)
	original.cursor = CursorState{
		col:   1
		row:   1
		shape: .beam
	}
	trimmed := original.trim_height(1)
	assert trimmed.cursor == none
	assert trimmed.buffer.data == original.buffer.data
	assert trimmed.children.data == original.children.data
	trimmed.write_cell(1, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: 'a'
		}
	})
	assert original.read_cell(1, 0).char_.grapheme == 'a'
}
