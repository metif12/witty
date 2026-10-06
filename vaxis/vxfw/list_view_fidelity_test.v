module vxfw

import vaxis

struct ListFidelityItem {
mut:
	owner  &ListFidelityFixture = unsafe { nil }
	index  int
	height u16
}

@[heap]
struct ListFidelityFixture {
mut:
	items       []ListFidelityItem
	build_calls []usize
	draw_calls  []int
	holes       u64
	fail        int = -1
}

fn list_fidelity_fixture(heights []u16) &ListFidelityFixture {
	mut fixture := &ListFidelityFixture{}
	for index, height in heights {
		fixture.items << ListFidelityItem{
			owner:  fixture
			index:  index
			height: height
		}
	}
	return fixture
}

fn list_fidelity_widget(item &ListFidelityItem) Widget {
	return Widget{
		userdata: unsafe { voidptr(item) }
		draw_fn:  list_fidelity_draw
	}
}

fn list_fidelity_draw(ptr voidptr, ctx DrawContext) !Surface {
	item := unsafe { &ListFidelityItem(ptr) }
	mut fixture := item.owner
	fixture.draw_calls << item.index
	if fixture.fail == item.index { return error('OutOfMemory') }
	return Surface{
		size:     Size{
			width:  ctx.min.width
			height: item.height
		}
		widget:   list_fidelity_widget(item)
		buffer:   []vaxis.Cell{}
		children: []SubSurface{}
	}
}

fn list_fidelity_build(ptr voidptr, index usize, _ usize) ?Widget {
	mut fixture := unsafe { &ListFidelityFixture(ptr) }
	fixture.build_calls << index
	if index >= usize(fixture.items.len) || fixture.holes & (u64(1) << index) != 0 {
		return none
	}
	return list_fidelity_widget(&fixture.items[int(index)])
}

fn list_fidelity_context(height u16) DrawContext {
	return DrawContext{
		min:       Size{}
		max:       MaxSize{
			width:  16
			height: height
		}
		cell_size: Size{}
	}
}

fn list_fidelity_slice(fixture &ListFidelityFixture) ListSlice {
	mut widgets := []Widget{}
	for index in 0 .. fixture.items.len {
		widgets << list_fidelity_widget(&fixture.items[index])
	}
	return ListSlice{
		widgets: widgets
	}
}

fn test_list_view_scroll_and_cursor_keep_source_visible_children() {
	fixture := list_fidelity_fixture([u16(3), 1, 1, 2])
	mut list := ListView{
		children:     list_fidelity_slice(fixture)
		wheel_scroll: 1
	}
	mut ctx := EventContext{
		cmds:   []
		redraw: false
	}
	draw_ctx := list_fidelity_context(4)
	initial := list.draw(draw_ctx) or { panic(err) }
	assert initial.children.len == 2
	assert initial.children[0].surface.buffer.filter(it.char_.grapheme == '▐').len == 3
	assert (list.item_count or { u32(0) }) == 4
	for expected_offset in [1, 2, 0] {
		list.widget().handle_event(mut ctx, vaxis.Mouse{
			col:    0
			row:    0
			button: .wheel_down
			mods:   vaxis.MouseModifiers{}
			type_:  .press
		}) or { panic(err) }
		view := list.draw(draw_ctx) or { panic(err) }
		assert list.scroll.offset == expected_offset
		assert view.children.len == if expected_offset == 2 {
			4
		} else {
			3
		}
	}
	assert list.scroll.top == 1
	list.handle_event(mut ctx, vaxis.Key{ codepoint: vaxis.escape }) or { panic(err) }
	reset := list.draw(draw_ctx) or { panic(err) }
	assert list.scroll.top == 0
	assert list.scroll.offset == 0
	assert reset.children.len == 2
	for cursor in u32(1) .. 4 {
		list.widget().handle_event(mut ctx, vaxis.Key{ codepoint: u32(`j`) }) or { panic(err) }
		view := list.draw(draw_ctx) or { panic(err) }
		assert list.cursor == cursor
		assert view.children.len == if cursor == 1 {
			2
		} else {
			3
		}
		assert !list.scroll.wants_cursor
	}
	assert list.scroll.top == 1
	assert list.scroll.offset == 0
	assert ctx.consume_event && ctx.redraw
}

fn test_list_view_failed_child_retains_source_state_order() {
	mut fixture := list_fidelity_fixture([u16(1), 2])
	fixture.fail = 1
	mut list := ListView{
		children: list_fidelity_slice(fixture)
		scroll:   ListScroll{
			offset:        1
			pending_lines: 1
			wants_cursor:  true
			has_more:      false
		}
	}
	list.draw(list_fidelity_context(4)) or {
		assert err.msg() == 'OutOfMemory'
		assert (list.item_count or { u32(0) }) == 2
		assert list.scroll.offset == 1
		assert list.scroll.pending_lines == 0
		assert list.scroll.has_more
		assert !list.scroll.wants_cursor
		assert fixture.draw_calls == [0, 1]
		return
	}
	assert false
}

fn test_list_view_builder_backtracks_and_known_end_consumes_without_redraw() {
	mut fixture := list_fidelity_fixture([u16(1), 1, 1])
	fixture.holes = 4
	mut list := ListView{
		children: ListBuilder{
			userdata: fixture
			build_fn: list_fidelity_build
		}
		cursor:   1
	}
	mut ctx := EventContext{
		cmds:   []
		redraw: false
	}
	list.next_item(mut ctx)
	assert fixture.build_calls == [usize(2), 1]
	assert list.cursor == 1
	assert ctx.consume_event && !ctx.redraw
	list.cursor = 0
	list.next_item(mut ctx)
	assert list.cursor == 1 && list.scroll.wants_cursor
	assert ctx.redraw
	mut empty := ListView{
		children:   ListSlice{
			widgets: []
		}
		item_count: u32(0)
	}
	mut empty_ctx := EventContext{
		cmds:   []
		redraw: false
	}
	empty.next_item(mut empty_ctx)
	assert empty.cursor == 0
	assert empty_ctx.consume_event && !empty_ctx.redraw
}

fn test_list_view_large_cursor_is_checked_before_native_int_adaptation() {
	fixture := list_fidelity_fixture([u16(1)])
	mut list := ListView{
		children: list_fidelity_slice(fixture)
		cursor:   0xffffffff
	}
	view := list.draw(list_fidelity_context(4)) or { panic(err) }
	assert view.children.len == 1
	assert view.children[0].surface.buffer.len == 0
	assert list.cursor == 0xffffffff
}

fn test_list_view_managed_storage_adapts_inherited_deinitialized_list_todo() {
	// Source deinitializes its ArrayList and then reuses undefined storage here.
	// V retains managed child storage; this is an adaptation, not source parity.
	fixture := list_fidelity_fixture([u16(0)])
	mut list := ListView{
		children:    list_fidelity_slice(fixture)
		draw_cursor: false
		scroll:      ListScroll{
			wants_cursor: true
		}
	}
	view := list.draw(list_fidelity_context(0)) or { panic(err) }
	assert view.children.len == 1
	assert view.children[0].surface.size.height == 0
	assert !list.scroll.wants_cursor
}
