module vxfw

import math
import vaxis

pub type ListBuildFn = fn (voidptr, usize, usize) ?Widget

pub struct ListBuilder {
pub mut:
	userdata voidptr     @[required]
	build_fn ListBuildFn @[required]
}

pub fn (builder ListBuilder) item_at_idx(index usize, cursor usize) ?Widget {
	return builder.build_fn(builder.userdata, index, cursor)
}

pub struct ListSlice {
pub mut:
	widgets []Widget @[required]
}

pub type ListSource = ListSlice | ListBuilder

pub struct ListScroll {
pub mut:
	top           u32
	offset        i32
	pending_lines i32
	has_more      bool = true
	wants_cursor  bool
}

pub fn (mut scroll ListScroll) lines_down(n u8) bool {
	if !scroll.has_more { return false }
	scroll.pending_lines = vxfw_i17_add(scroll.pending_lines, i32(n))
	return true
}

pub fn (mut scroll ListScroll) lines_up(n u8) bool {
	if scroll.top == 0 && scroll.offset == 0 { return false }
	scroll.pending_lines = vxfw_i17_sub(scroll.pending_lines, i32(n))
	return true
}

pub struct ListView {
pub mut:
	children     ListSource @[required]
	draw_cursor  bool = true
	wheel_scroll u8   = 3
	cursor       u32
	item_count   ?u32
	scroll       ListScroll
}

pub fn (view &ListView) widget() Widget {
	return Widget{
		userdata:      unsafe { voidptr(view) }
		event_handler: list_event
		draw_fn:       list_draw
	}
}

fn list_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut view := unsafe { &ListView(ptr) }
	view.handle_event(mut ctx, event)!
}

fn list_draw(ptr voidptr, ctx DrawContext) !Surface {
	mut view := unsafe { &ListView(ptr) }
	return view.draw(ctx)
}

pub fn (mut view ListView) handle_event(mut ctx EventContext, event Event) ! {
	match event {
		vaxis.Mouse {
			if event.button == .wheel_up && view.scroll.lines_up(view.wheel_scroll) {
				ctx.consume_and_redraw()
			}
			if event.button == .wheel_down && view.scroll.lines_down(view.wheel_scroll) {
				ctx.consume_and_redraw()
			}
		}
		vaxis.Key {
			ctrl := vaxis.Modifiers.from_int(4)
			if event.matches(u32(`j`), vaxis.Modifiers{}) || event.matches(u32(`n`), ctrl)
				|| event.matches(vaxis.down, vaxis.Modifiers{}) {
				view.next_item(mut ctx)
				return
			}
			if event.matches(u32(`k`), vaxis.Modifiers{}) || event.matches(u32(`p`), ctrl)
				|| event.matches(vaxis.up, vaxis.Modifiers{}) {
				view.prev_item(mut ctx)
				return
			}
			if event.matches(vaxis.escape, vaxis.Modifiers{}) {
				view.ensure_scroll()
				ctx.consume_and_redraw()
			}
		}
		else {}
	}
}

pub fn (mut view ListView) draw(ctx DrawContext) !Surface {
	if ctx.max.width == none { panic('Assertion failed') }
	if ctx.max.height == none { panic('Assertion failed') }
	match view.children {
		ListSlice {
			view.item_count = vxfw_u32_cast(u64(view.children.widgets.len))
			builder := &ListSlice{
				widgets: view.children.widgets
			}
			return view.draw_builder(ctx, ListBuilder{ userdata: builder, build_fn: list_slice_build })
		}
		ListBuilder {
			return view.draw_builder(ctx, view.children)
		}
	}
}

fn list_slice_build(ptr voidptr, index usize, _ usize) ?Widget {
	slice := unsafe { &ListSlice(ptr) }
	if index >= usize(slice.widgets.len) { return none }
	return slice.widgets[int(index)]
}

pub fn (mut view ListView) next_item(mut ctx EventContext) {
	if count := view.item_count {
		if view.cursor >= if count > 0 {
			count - 1
		} else {
			0
		} {
			ctx.consume_event()
			return
		}
		view.cursor = vxfw_u32_add(view.cursor, 1)
	} else {
		match view.children {
			ListSlice {
				view.item_count = vxfw_u32_cast(u64(view.children.widgets.len))
				if view.children.widgets.len == 0 { panic('integer overflow') }
				if usize(view.cursor) == usize(view.children.widgets.len) - 1 {
					ctx.consume_event()
					return
				}
				view.cursor = vxfw_u32_add(view.cursor, 1)
			}
			ListBuilder {
				previous := view.cursor
				view.cursor = vxfw_u32_add(view.cursor, 1)
				for view.children.item_at_idx(view.cursor, view.cursor) == none {
					if view.cursor > 0 { view.cursor-- }
				}
				if view.cursor == previous {
					ctx.consume_event()
					return
				}
			}
		}
	}
	view.ensure_scroll()
	ctx.consume_and_redraw()
}

pub fn (mut view ListView) prev_item(mut ctx EventContext) {
	if view.cursor == 0 {
		ctx.consume_event()
		return
	}
	if count := view.item_count {
		view.cursor = math.min(vxfw_u32_sub(view.cursor, 1), vxfw_u32_sub(count, 1))
	} else {
		match view.children {
			ListSlice {
				view.item_count = vxfw_u32_cast(u64(view.children.widgets.len))
				previous := vxfw_u32_sub(view.cursor, 1)
				if view.children.widgets.len == 0 { panic('integer overflow') }
				view.cursor = u32(math.min(usize(previous), usize(view.children.widgets.len) - 1))
			}
			ListBuilder {
				previous := view.cursor
				view.cursor--
				for view.children.item_at_idx(view.cursor, view.cursor) == none {
					if view.cursor > 0 { view.cursor-- }
				}
				if view.cursor == previous {
					ctx.consume_event()
					return
				}
			}
		}
	}
	view.ensure_scroll()
	ctx.consume_and_redraw()
}

pub fn (mut view ListView) ensure_scroll() {
	if view.cursor <= view.scroll.top {
		view.scroll.top = view.cursor
		view.scroll.offset = 0
	} else {
		view.scroll.wants_cursor = true
	}
}

fn (mut view ListView) insert_children(ctx DrawContext, builder ListBuilder, mut children []SubSurface, add_height i32) ! {
	if view.scroll.top == 0 { panic('Assertion failed') }
	view.scroll.top = vxfw_u32_sub(view.scroll.top, 1)
	mut upheight := add_height
	for {
		child := builder.item_at_idx(view.scroll.top, view.cursor) or { break }
		offset := if view.draw_cursor { u16(2) } else { u16(0) }
		size := ctx.max.size()
		surface := child.draw(ctx.with_constraints(Size{ width: vxfw_u16_sub(size.width, offset) }, MaxSize{
			width: vxfw_u16_sub(size.width, offset)
		}))!
		upheight = vxfw_i17_sub(upheight, i32(surface.size.height))
		children.insert(0, SubSurface{
			origin:  RelativePoint{
				col: offset
				row: upheight
			}
			surface: surface
		})
		if upheight <= 0 || view.scroll.top == 0 {
			break
		}
		view.scroll.top = vxfw_u32_sub(view.scroll.top, 1)
	}
	view.scroll.offset = upheight
	if view.scroll.top == 0 && upheight > 0 {
		view.scroll.offset = 0
		mut row := i32(0)
		for mut child in children {
			child.origin.row = row
			row = vxfw_i17_add(row, i32(child.surface.size.height))
		}
	}
	view.scroll.offset = upheight
}

fn total_height(children []SubSurface) usize {
	mut height := usize(0)
	for child in children {
		height = vxfw_usize_add(height, usize(child.surface.size.height))
	}
	return height
}

fn (mut view ListView) draw_builder(ctx DrawContext, builder ListBuilder) !Surface {
	defer { view.scroll.wants_cursor = false }
	size := ctx.max.size()
	mut surface := Surface{
		size:     size
		widget:   view.widget()
		buffer:   []vaxis.Cell{}
		children: []SubSurface{}
	}
	if view.draw_cursor { surface.buffer = Surface.create_buffer(size) }
	view.scroll.has_more = true
	mut children := []SubSurface{}
	mut height := vxfw_i17_sub(0, vxfw_i17_add(view.scroll.offset, view.scroll.pending_lines))
	view.scroll.pending_lines = 0
	mut index := usize(view.scroll.top)
	if height > 0 && view.scroll.top == 0 {
		view.scroll.offset = 0
		height = 0
	}
	if height > 0 {
		view.insert_children(ctx, builder, mut children, height)!
		last_index := vxfw_usize_sub(usize(children.len), 1)
		last := children[int(last_index)]
		height = vxfw_i17_add(last.origin.row, i32(last.surface.size.height))
	}
	offset := if view.draw_cursor { u16(2) } else { u16(0) }
	for {
		child := builder.item_at_idx(index, view.cursor) or {
			view.scroll.has_more = false
			break
		}
		child_width := sat_sub(size.width, offset)
		child_surface := child.draw(ctx.with_constraints(Size{ width: child_width }, MaxSize{
			width: child_width
		})) or {
			index = vxfw_usize_add(index, 1)
			return err
		}
		children << SubSurface{
			origin:  RelativePoint{
				col: offset
				row: height
			}
			surface: child_surface
		}
		height = vxfw_i17_add(height, i32(child_surface.size.height))
		current := index
		index = vxfw_usize_add(index, 1)
		if view.scroll.wants_cursor && current < view.cursor {
			continue
		}
		if height >= size.height {
			break
		}
	}
	mut content_height := total_height(children)
	if !view.scroll.has_more && content_height < size.height && view.scroll.top > 0 {
		view.insert_children(ctx, builder, mut children,
			vxfw_i17_cast(i64(usize(size.height) - content_height)))!
		content_height = total_height(children)
	}
	if view.draw_cursor && view.cursor >= view.scroll.top {
		cursor_index := usize(vxfw_u32_sub(view.cursor, view.scroll.top))
		if cursor_index < usize(children.len) {
			child := children[int(cursor_index)]
			cursor_surface := Surface.init_with_children(view.widget(), Size{
				width:  vxfw_u16_add(offset, child.surface.size.width)
				height: child.surface.size.height
			}, [
				SubSurface{
					origin:  RelativePoint{
						col: offset
						row: 0
					}
					surface: child.surface
				},
			])
			for row in u16(0) .. cursor_surface.size.height {
				cursor_surface.write_cell(0, row, vaxis.Cell{
					char_: vaxis.CellCharacter{
						grapheme: '▐'
						width:    1
					}
				})
			}
			children[int(cursor_index)] = SubSurface{
				origin:  RelativePoint{
					row: child.origin.row
					col: 0
				}
				surface: cursor_surface
			}
		}
	}
	if view.scroll.wants_cursor {
		cursor_index := usize(vxfw_u32_sub(view.cursor, view.scroll.top))
		if cursor_index >= usize(children.len) { panic('index out of bounds') }
		sub := children[int(cursor_index)]
		bottom := vxfw_i17_add(sub.origin.row, i32(sub.surface.size.height))
		if bottom > size.height {
			mut origin := i32(size.height)
			for idx := int(cursor_index); idx >= 0; idx-- {
				origin = vxfw_i17_sub(origin, i32(children[idx].surface.size.height))
				children[idx].origin.row = origin
			}
		} else if sub.surface.size.height >= size.height {
			view.scroll.top = view.cursor
			view.scroll.offset = 0
			children = [
				SubSurface{
					origin:  RelativePoint{
						row: 0
						col: 0
					}
					surface: sub.surface
				},
			]
			content_height = sub.surface.size.height
		}
	}
	if !view.scroll.has_more && content_height < size.height {
		if view.scroll.top != 0 { panic('Assertion failed') }
		view.scroll.offset = 0
		mut origin := i32(0)
		for mut child in children {
			child.origin.row = origin
			origin = vxfw_i17_add(origin, i32(child.surface.size.height))
		}
	} else if !view.scroll.has_more {
		mut origin := i32(size.height)
		for idx := children.len - 1; idx >= 0; idx-- {
			origin = vxfw_i17_sub(origin, i32(children[idx].surface.size.height))
			children[idx].origin.row = origin
		}
	}
	mut start := 0
	mut end := children.len
	for idx, child in children {
		if child.origin.row <= 0
			&& vxfw_i17_add(child.origin.row, i32(child.surface.size.height)) > 0 {
			start = idx
			view.scroll.offset = vxfw_i17_sub(0, child.origin.row)
			view.scroll.top = vxfw_u32_add(view.scroll.top, vxfw_u32_cast(u64(idx)))
		}
		if child.origin.row > size.height {
			end = idx
			break
		}
	}
	surface.children = children[start..end]
	return surface
}
