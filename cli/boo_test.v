module cli

import vaxis
import vaxis.vxfw

fn test_boo_parser_state_source_layout_and_ordinals() {
	assert sizeof(BooParseState) == 1
	assert [BooParseState.normal, .span, .in_tag, .in_closing_tag].map(u8(it)) == [
		u8(0),
		1,
		2,
		3,
	]
}

fn test_boo_all_pinned_frames_update_the_retained_buffer_and_wrap() {
	frames := decompress_boo_frames()!
	assert frames.len == 235
	assert frames[0].contains('<span class="b">')
	mut boo := Boo{
		frames: frames
	}
	mut has_outline := false
	for i in 0 .. frames.len {
		assert int(boo.frame) == i
		boo.update_frame()
		for cell in boo.buffer {
			assert cell.char_.grapheme.len > 0
			assert cell.char_.width == 1
			if cell.style.fg is vaxis.ColorIndex {
				has_outline = true
				assert cell.style.fg.index == 4
			}
		}
	}
	assert boo.frame == 0
	assert has_outline
}

fn test_boo_surface_centers_borrowed_cells_and_wraps_small_screen_warning() {
	vxfw.DrawContext.init(.unicode)
	mut boo := Boo{
		frames: decompress_boo_frames()!
	}
	boo.update_frame()
	surface := boo.widget().draw(vxfw.DrawContext{
		min:       vxfw.Size{}
		cell_size: vxfw.Size{}
		max:       vxfw.MaxSize{
			width:  102
			height: 43
		}
	})!
	assert surface.size == vxfw.Size{
		width:  102
		height: 43
	}
	assert surface.buffer.len == 0
	assert surface.children.len == 1
	child := surface.children[0]
	assert child.origin == vxfw.RelativePoint{
		row: 1
		col: 1
	}
	assert child.surface.size == vxfw.Size{
		width:  100
		height: 41
	}
	assert child.surface.buffer.data == unsafe { voidptr(&boo.buffer[0]) }
	child.surface.write_cell(0, 0, vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: 'x'
		}
	})
	assert boo.buffer[0].char_.grapheme == 'x'
	warning := boo.widget().draw(vxfw.DrawContext{
		min:       vxfw.Size{}
		cell_size: vxfw.Size{}
		max:       vxfw.MaxSize{
			width:  80
			height: 24
		}
	})!
	assert warning.size == vxfw.Size{
		width:  80
		height: 24
	}
	assert warning.children.len == 1
	assert warning.children[0].origin == vxfw.RelativePoint{
		row: 11
		col: 23
	}
	assert warning.children[0].surface.buffer.map(it.char_.grapheme).join('') == 'Screen must be at least 100w x 41h'
	narrow := boo.widget().draw(vxfw.DrawContext{
		min:       vxfw.Size{}
		cell_size: vxfw.Size{}
		max:       vxfw.MaxSize{
			width:  20
			height: 24
		}
	})!
	assert narrow.children[0].surface.size.height == 2
}

fn test_boo_init_tick_and_exit_keys_use_widget_events() {
	mut boo := Boo{
		frames: decompress_boo_frames()!
	}
	widget := boo.widget()
	mut ctx := vxfw.EventContext{
		cmds:   []vxfw.Command{}
		redraw: false
	}
	widget.handle_event(mut ctx, vxfw.Event(vxfw.InitEvent{}))!
	assert boo.frame == 1
	assert ctx.redraw
	assert ctx.cmds.len == 1
	tick := ctx.cmds[0]
	assert tick is vxfw.Tick
	assert tick.widget.eql(widget)
	widget.handle_event(mut ctx, vxfw.Event(vxfw.TickEvent{}))!
	assert boo.frame == 2
	widget.handle_event(mut ctx, vxfw.Event(vaxis.Key{
		codepoint: u32(`c`)
	}))!
	assert !ctx.quit
	widget.handle_event(mut ctx, vxfw.Event(vaxis.Key{
		codepoint: u32(`c`)
		mods:      vaxis.Modifiers.from_int(4)
	}))!
	assert ctx.quit
	ctx.quit = false
	widget.handle_event(mut ctx, vxfw.Event(vaxis.Key{
		codepoint: vaxis.escape
	}))!
	assert ctx.quit
}
