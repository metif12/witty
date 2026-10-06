module vxfw

struct ScrollFidelityChild {
mut:
	view            &ScrollView = unsafe { nil }
	failed          bool
	pending_at_draw i32
}

fn (child &ScrollFidelityChild) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(child) }
		draw_fn:  scroll_fidelity_child_draw
	}
}

fn scroll_fidelity_child_draw(ptr voidptr, _ DrawContext) !Surface {
	mut child := unsafe { &ScrollFidelityChild(ptr) }
	if child.failed {
		child.pending_at_draw = child.view.scroll.pending_lines
		child.view.scroll.left = 65536
		return error('OutOfMemory')
	}
	return Surface{
		size:     Size{
			width:  3
			height: 1
		}
		widget:   child.widget()
		buffer:   []
		children: []
	}
}

struct ScrollFidelityBuilder {
	child &ScrollFidelityChild
mut:
	view    &ScrollView = unsafe { nil }
	indexes []usize
	replace bool
}

fn scroll_fidelity_build(ptr voidptr, index usize, _ usize) ?Widget {
	mut builder := unsafe { &ScrollFidelityBuilder(ptr) }
	builder.indexes << index
	if builder.replace {
		builder.view.children = ScrollSlice{
			widgets: []
		}
		builder.replace = false
	}
	if index != 0 { return none }
	return builder.child.widget()
}

fn scroll_fidelity_context(width u16, height u16) DrawContext {
	return DrawContext{
		min:       Size{}
		max:       MaxSize{
			width:  width
			height: height
		}
		cell_size: Size{}
	}
}

fn test_scroll_view_limits_preserve_short_circuit_and_saturating_horizontal_scroll() {
	mut scroll := ViewScroll{
		pending_lines:     65535
		has_more_vertical: false
		left:              0xfffffffe
	}
	assert !scroll.lines_down(255)
	assert scroll.pending_lines == 65535
	assert !scroll.lines_up(255)
	assert scroll.cols_right(255)
	assert scroll.left == 0xffffffff
	scroll.has_more_horizontal = false
	assert !scroll.cols_right(255)
	assert scroll.cols_left(255)
	assert scroll.left == 0xffffff00
	scroll.left = 1
	assert scroll.cols_left(255)
	assert scroll.left == 0
	assert !scroll.cols_left(0)
	scroll.top = 1
	scroll.pending_lines = -65281
	assert scroll.lines_up(255)
	assert scroll.pending_lines == -65536
}

fn test_scroll_view_child_error_precedes_left_cast_and_clears_cursor_request() {
	mut child := ScrollFidelityChild{
		failed: true
	}
	mut view := ScrollView{
		children: ScrollSlice{
			widgets: [child.widget()]
		}
		scroll:   ViewScroll{
			pending_lines: 3
			wants_cursor:  true
		}
	}
	child.view = &view
	if _ := view.widget().draw(scroll_fidelity_context(3, 1)) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	assert child.pending_at_draw == 0
	assert view.item_count == ?u32(1)
	assert view.scroll.pending_lines == 0
	assert view.scroll.left == 65536
	assert view.scroll.has_more_vertical
	assert !view.scroll.wants_cursor
}

fn test_scroll_view_builder_value_survives_callback_replacing_source() {
	child := &ScrollFidelityChild{}
	mut builder := ScrollFidelityBuilder{
		child:   child
		replace: true
	}
	mut view := ScrollView{
		children: ScrollBuilder{
			userdata: &builder
			build_fn: scroll_fidelity_build
		}
	}
	builder.view = &view
	mut event_ctx := EventContext{
		cmds:   []
		redraw: false
	}
	view.next_item(mut event_ctx)
	assert builder.indexes == [usize(1), 0]
	assert view.cursor == 0
	assert event_ctx.consume_event && !event_ctx.redraw
	assert view.children is ScrollSlice
	builder.indexes = []
	builder.replace = true
	view.children = ScrollBuilder{
		userdata: &builder
		build_fn: scroll_fidelity_build
	}
	surface := view.widget().draw(scroll_fidelity_context(3, 1))!
	assert builder.indexes == [usize(0), 1]
	assert surface.children.len == 1
	assert !view.scroll.has_more_vertical
	assert view.item_count == none
	assert view.children is ScrollSlice
}

fn test_scroll_view_out_of_view_maximum_cursor_does_not_wrap_to_array_index() {
	child := &ScrollFidelityChild{}
	mut view := ScrollView{
		children:    ScrollSlice{
			widgets: [child.widget()]
		}
		cursor:      0xffffffff
		draw_cursor: true
	}
	surface := view.draw(scroll_fidelity_context(3, 1))!
	assert surface.children.len == 1
	assert surface.children[0].surface.widget == child.widget()
	assert surface.children[0].surface.children.len == 0
	assert view.cursor == 0xffffffff
	assert view.last_height == 1
	assert view.scroll.top == 0 && view.scroll.vertical_offset == 0
}
