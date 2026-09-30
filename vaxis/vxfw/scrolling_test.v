module vxfw

import vaxis

fn scrolling_widgets() []Widget {
	a := &Text{
		text: 'abc\n  def\n  ghi'
	}
	b := &Text{
		text: 'def'
	}
	c := &Text{
		text: 'ghi'
	}
	d := &Text{
		text: 'jkl\n mno'
	}
	return [a.widget(), b.widget(), c.widget(), d.widget()]
}

fn test_list_view_pinned_variable_height_scroll_and_cursor_sequence() {
	DrawContext.init(.unicode)
	mut list := ListView{
		children:     ListSlice{
			widgets: scrolling_widgets()
		}
		wheel_scroll: 1
	}
	ctx := DrawContext{
		max: MaxSize{
			width:  16
			height: 4
		}
	}
	mut event_ctx := EventContext{}
	mut surface := list.draw(ctx)!
	assert surface.size == Size{
		width:  16
		height: 4
	}
	assert surface.children.len == 2
	assert surface.children[0].surface.read_cell(0, 0).char_.grapheme == '▐'
	wheel := Event(vaxis.Mouse{
		button: .wheel_down
	})
	for i, expected in [
		[u32(0), 1, 3],
		[u32(0), 2, 4],
		[u32(1), 0, 3],
		[u32(1), 0, 3],
	] {
		list.handle_event(mut event_ctx, wheel)!
		surface = list.draw(ctx)!
		assert list.scroll.top == expected[0], 'wheel ${i}'
		assert list.scroll.offset == i32(expected[1]), 'wheel ${i}'
		assert surface.children.len == int(expected[2]), 'wheel ${i}'
	}
	list.handle_event(mut event_ctx, Event(vaxis.Key{
		codepoint: vaxis.escape
	}))!
	surface = list.draw(ctx)!
	assert list.scroll.top == 0 && list.scroll.offset == 0
	for i, expected in [[u32(0), 0, 2], [u32(0), 1, 3], [u32(1), 0, 3]] {
		list.handle_event(mut event_ctx, Event(vaxis.Key{
			codepoint: u32(`j`)
		}))!
		surface = list.draw(ctx)!
		assert list.cursor == u32(i + 1)
		assert list.scroll.top == expected[0]
		assert list.scroll.offset == i32(expected[1])
		assert surface.children.len == int(expected[2])
	}
}

fn test_scroll_view_pinned_out_of_view_children_and_horizontal_scroll() {
	DrawContext.init(.unicode)
	mut view := ScrollView{
		children:     ScrollSlice{
			widgets: scrolling_widgets()
		}
		wheel_scroll: 1
	}
	ctx := DrawContext{
		max: MaxSize{
			width:  3
			height: 4
		}
	}
	mut event_ctx := EventContext{}
	mut surface := view.draw(ctx)!
	assert surface.children.len == 2
	assert view.scroll.has_more_vertical && view.scroll.has_more_horizontal
	for i, expected in [[u32(0), 1, 3], [u32(0), 2, 4], [u32(1), 0, 4],
		[u32(1), 0, 3]] {
		view.handle_event(mut event_ctx, Event(vaxis.Mouse{
			button: .wheel_down
		}))!
		surface = view.draw(ctx)!
		assert view.scroll.top == expected[0], 'wheel ${i}'
		assert view.scroll.vertical_offset == i32(expected[1]), 'wheel ${i}'
		assert surface.children.len == int(expected[2]), 'wheel ${i}'
	}
	assert !view.scroll.has_more_vertical
	view.handle_event(mut event_ctx, Event(vaxis.Mouse{
		button: .wheel_up
	}))!
	surface = view.draw(ctx)!
	assert view.scroll.top == 0 && view.scroll.vertical_offset == 2
	assert surface.children.len == 4
	view.handle_event(mut event_ctx, Event(vaxis.Mouse{
		button: .wheel_left
	}))!
	surface = view.draw(ctx)!
	assert view.scroll.left == 1
	assert surface.children[0].origin.col == -1
	assert view.cursor == 0
	view.handle_event(mut event_ctx, Event(vaxis.Mouse{
		button: .wheel_right
	}))!
	assert view.scroll.left == 0
}

fn test_scrollbars_pinned_visibility_and_drag_capture() {
	DrawContext.init(.unicode)
	mut bars := ScrollBars{
		scroll_view:              ScrollView{
			children:     ScrollSlice{
				widgets: scrolling_widgets()
			}
			wheel_scroll: 1
		}
		estimated_content_height: 7
		estimated_content_width:  5
	}
	ctx := DrawContext{
		max: MaxSize{
			width:  3
			height: 4
		}
	}
	assert bars.draw(ctx)!.children.len == 3
	bars.draw_horizontal_scrollbar = false
	assert bars.draw(ctx)!.children.len == 2
	bars.draw_horizontal_scrollbar = true
	bars.draw_vertical_scrollbar = false
	assert bars.draw(ctx)!.children.len == 2
	bars.draw_horizontal_scrollbar = false
	assert bars.draw(ctx)!.children.len == 1
	bars.draw_horizontal_scrollbar = true
	bars.draw_vertical_scrollbar = true
	bars.draw(ctx)!
	mut event_ctx := EventContext{
		redraw: false
	}
	bars.handle_event(mut event_ctx, Event(vaxis.Mouse{
		row:    0
		col:    2
		type_:  .press
		button: .left
	}))!
	assert bars.is_dragging_vertical_thumb
	assert event_ctx.consume_event
	event_ctx.consume_event = false
	bars.handle_capture(mut event_ctx, Event(vaxis.Mouse{
		row:    2
		col:    0
		type_:  .drag
		button: .left
	}))!
	assert bars.scroll_view.scroll.top == 2
	assert event_ctx.redraw && event_ctx.consume_event
	bars.handle_capture(mut event_ctx, Event(vaxis.Mouse{
		row:    2
		col:    0
		type_:  .release
		button: .left
	}))!
	assert !bars.is_dragging_vertical_thumb
	assert !bars.is_hovering_vertical_thumb
}
