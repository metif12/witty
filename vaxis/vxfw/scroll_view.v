module vxfw

import math
import vaxis

pub type ScrollBuildFn = fn (voidptr, uint, uint) ?Widget

pub struct ScrollBuilder {
pub mut:
	userdata voidptr       @[required]
	build_fn ScrollBuildFn @[required]
}

pub fn (builder ScrollBuilder) item_at_idx(index uint, cursor uint) ?Widget {
	return builder.build_fn(builder.userdata, index, cursor)
}

pub struct ScrollSlice {
pub mut:
	widgets []Widget @[required]
}

pub type ScrollSource = ScrollSlice | ScrollBuilder

pub struct ViewScroll {
pub mut:
	top                 u32
	vertical_offset     i32
	pending_lines       i32
	has_more_vertical   bool = true
	left                u32
	has_more_horizontal bool = true
	wants_cursor        bool
}

pub fn (mut scroll ViewScroll) lines_down(n u8) bool {
	if !scroll.has_more_vertical { return false }
	scroll.pending_lines = vxfw_i17_add(scroll.pending_lines, i32(n))
	return true
}

pub fn (mut scroll ViewScroll) lines_up(n u8) bool {
	if scroll.top == 0 && scroll.vertical_offset == 0 { return false }
	scroll.pending_lines = vxfw_i17_sub(scroll.pending_lines, i32(n))
	return true
}

pub fn (mut scroll ViewScroll) cols_left(n u8) bool {
	if scroll.left == 0 { return false }
	scroll.left = if scroll.left > n { scroll.left - n } else { 0 }
	return true
}

pub fn (mut scroll ViewScroll) cols_right(n u8) bool {
	if !scroll.has_more_horizontal { return false }
	scroll.left = u32(math.min(u64(scroll.left) + n, u64(0xffffffff)))
	return true
}

pub struct ScrollView {
pub mut:
	children         ScrollSource @[required]
	draw_cursor      bool
	cursor_indicator vaxis.Cell = vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '▐'
			width:    1
		}
	}
	wheel_scroll     u8 = 3
	cursor           u32
	last_height      u8
	item_count       ?u32
	scroll           ViewScroll
}

pub fn (view &ScrollView) widget() Widget {
	return Widget{
		userdata:      unsafe { voidptr(view) }
		event_handler: scroll_event
		draw_fn:       scroll_draw
	}
}

fn scroll_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut view := unsafe { &ScrollView(ptr) }
	view.handle_event(mut ctx, event)!
}

fn scroll_draw(ptr voidptr, ctx DrawContext) !Surface {
	mut view := unsafe { &ScrollView(ptr) }
	return view.draw(ctx)
}

pub fn (mut view ScrollView) handle_event(mut ctx EventContext, event Event) ! {
	match event {
		vaxis.Mouse {
			if event.button == .wheel_up && view.scroll.lines_up(view.wheel_scroll) {
				ctx.consume_and_redraw()
				return
			}
			if event.button == .wheel_down && view.scroll.lines_down(view.wheel_scroll) {
				ctx.consume_and_redraw()
				return
			}
			if event.button == .wheel_left && view.scroll.cols_right(view.wheel_scroll) {
				ctx.consume_and_redraw()
				return
			}
			if event.button == .wheel_right && view.scroll.cols_left(view.wheel_scroll) {
				ctx.consume_and_redraw()
				return
			}
		}
		vaxis.Key {
			ctrl := vaxis.Modifiers.from_int(4)
			if event.matches(vaxis.down, vaxis.Modifiers{})
				|| event.matches(u32(`j`), vaxis.Modifiers{}) || event.matches(u32(`n`), ctrl) {
				if view.draw_cursor {
					view.next_item(mut ctx)
					return
				}
				if view.scroll.lines_down(1) { ctx.consume_and_redraw() }
			}
			if event.matches(vaxis.up, vaxis.Modifiers{})
				|| event.matches(u32(`k`), vaxis.Modifiers{}) || event.matches(u32(`p`), ctrl) {
				if view.draw_cursor {
					view.prev_item(mut ctx)
					return
				}
				if view.scroll.lines_up(1) { ctx.consume_and_redraw() }
			}
			if event.matches(vaxis.right, vaxis.Modifiers{})
				|| event.matches(u32(`l`), vaxis.Modifiers{}) || event.matches(u32(`f`), ctrl) {
				if view.scroll.cols_right(1) { ctx.consume_and_redraw() }
			}
			if event.matches(vaxis.left, vaxis.Modifiers{})
				|| event.matches(u32(`h`), vaxis.Modifiers{}) || event.matches(u32(`b`), ctrl) {
				if view.scroll.cols_left(1) { ctx.consume_and_redraw() }
			}
			if event.matches(u32(`d`), ctrl) {
				if view.scroll.lines_down(math.max(view.last_height / 2, u8(1))) {
					ctx.consume_and_redraw()
				}
			}
			if event.matches(u32(`u`), ctrl) {
				if view.scroll.lines_up(math.max(view.last_height / 2, u8(1))) {
					ctx.consume_and_redraw()
				}
			}
			if event.matches(vaxis.escape, vaxis.Modifiers{}) {
				view.ensure_scroll()
				ctx.consume_and_redraw()
			}
		}
		else {}
	}
}

pub fn (mut view ScrollView) draw(ctx DrawContext) !Surface {
	if ctx.max.width == none { panic('Assertion failed') }
	if ctx.max.height == none { panic('Assertion failed') }
	match view.children {
		ScrollSlice {
			view.item_count = vxfw_u32_cast(u64(view.children.widgets.len))
			builder := &ScrollSlice{
				widgets: view.children.widgets
			}
			return view.draw_builder(ctx, ScrollBuilder{
				userdata: builder
				build_fn: scroll_slice_build
			})
		}
		ScrollBuilder {
			builder := view.children
			return view.draw_builder(ctx, builder)
		}
	}
}

fn scroll_slice_build(ptr voidptr, index uint, _ uint) ?Widget {
	slice := unsafe { &ScrollSlice(ptr) }
	if index >= uint(slice.widgets.len) { return none }
	return slice.widgets[int(index)]
}

pub fn (mut view ScrollView) next_item(mut ctx EventContext) {
	if count := view.item_count {
		if view.cursor >= vxfw_u32_sub(count, 1) {
			ctx.consume_event()
			return
		}
		view.cursor = vxfw_u32_add(view.cursor, 1)
	} else {
		match view.children {
			ScrollSlice {
				view.item_count = vxfw_u32_cast(u64(view.children.widgets.len))
				if uint(view.cursor) == vxfw_usize_sub(uint(view.children.widgets.len), 1) {
					ctx.consume_event()
					return
				}
				view.cursor = vxfw_u32_add(view.cursor, 1)
			}
			ScrollBuilder {
				builder := view.children
				previous := view.cursor
				view.cursor = vxfw_u32_add(view.cursor, 1)
				for builder.item_at_idx(view.cursor, view.cursor) == none {
					if view.cursor > 0 { view.cursor = vxfw_u32_sub(view.cursor, 1) }
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

pub fn (mut view ScrollView) prev_item(mut ctx EventContext) {
	if view.cursor == 0 {
		ctx.consume_event()
		return
	}
	if count := view.item_count {
		view.cursor = math.min(vxfw_u32_sub(view.cursor, 1), vxfw_u32_sub(count, 1))
	} else {
		match view.children {
			ScrollSlice {
				view.item_count = vxfw_u32_cast(u64(view.children.widgets.len))
				view.cursor = vxfw_u32_cast(u64(math.min(uint(vxfw_u32_sub(view.cursor, 1)),
					vxfw_usize_sub(uint(view.children.widgets.len), 1))))
			}
			ScrollBuilder {
				builder := view.children
				previous := view.cursor
				view.cursor = vxfw_u32_sub(view.cursor, 1)
				for builder.item_at_idx(view.cursor, view.cursor) == none {
					if view.cursor > 0 { view.cursor = vxfw_u32_sub(view.cursor, 1) }
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

pub fn (mut view ScrollView) ensure_scroll() {
	if view.cursor <= view.scroll.top {
		view.scroll.top = view.cursor
		view.scroll.vertical_offset = 0
	} else {
		view.scroll.wants_cursor = true
	}
}

fn (mut view ScrollView) insert_children(ctx DrawContext, builder ScrollBuilder, mut children []SubSurface, add_height i32) ! {
	if view.scroll.top == 0 { panic('Assertion failed') }
	view.scroll.top = vxfw_u32_sub(view.scroll.top, 1)
	mut upheight := add_height
	for {
		child := builder.item_at_idx(view.scroll.top, view.cursor) or { break }
		offset := if view.draw_cursor { u16(2) } else { u16(0) }
		size := ctx.max.size()
		surface := child.draw(ctx.with_constraints(Size{
			width: vxfw_u16_sub(size.width, offset)
		}, MaxSize{}))!
		upheight = vxfw_i17_sub(upheight, i32(surface.size.height))
		children.insert(0, SubSurface{
			origin:  RelativePoint{
				col: vxfw_i17_sub(i32(offset), vxfw_i17_cast(i64(view.scroll.left)))
				row: upheight
			}
			surface: surface
		})
		if upheight <= 0 || view.scroll.top == 0 { break
		 }
		view.scroll.top = vxfw_u32_sub(view.scroll.top, 1)
	}
	view.scroll.vertical_offset = upheight
	if view.scroll.top == 0 && upheight > 0 {
		view.scroll.vertical_offset = 0
		mut row := i32(0)
		for mut child in children {
			child.origin.row = row
			row = vxfw_i17_add(row, i32(child.surface.size.height))
		}
	}
	view.scroll.vertical_offset = upheight
}

fn (mut view ScrollView) draw_builder(ctx DrawContext, builder ScrollBuilder) !Surface {
	defer { view.scroll.wants_cursor = false }
	size := ctx.max.size()
	mut surface := Surface{
		size:     size
		widget:   view.widget()
		buffer:   []
		children: []
	}
	view.scroll.has_more_vertical = true
	mut children := []SubSurface{}
	mut height := vxfw_i17_sub(0, vxfw_i17_add(view.scroll.vertical_offset,
		view.scroll.pending_lines))
	view.scroll.pending_lines = 0
	mut index := uint(view.scroll.top)
	if height > 0 && view.scroll.top == 0 {
		view.scroll.vertical_offset = 0
		height = 0
	}
	if height > 0 {
		view.insert_children(ctx, builder, mut children, height)!
		last := children[int(vxfw_usize_sub(uint(children.len), 1))]
		height = vxfw_i17_add(last.origin.row, i32(last.surface.size.height))
	}
	offset := if view.draw_cursor { u16(2) } else { u16(0) }
	for {
		child := builder.item_at_idx(index, view.cursor) or {
			view.scroll.has_more_vertical = false
			break
		}
		child_width := vxfw_u16_sub(size.width, offset)
		child_surface := child.draw(ctx.with_constraints(Size{ width: child_width }, MaxSize{})) or {
			// Source's loop defers its index increment even on a child error.
			index = vxfw_usize_add(index, 1)
			return err
		}
		children << SubSurface{
			origin:  RelativePoint{
				col: vxfw_i17_sub(i32(offset), vxfw_i17_cast(i64(view.scroll.left)))
				row: height
			}
			surface: child_surface
		}
		height = vxfw_i17_add(height, i32(child_surface.size.height))
		current := index
		index = vxfw_usize_add(index, 1)
		if view.scroll.wants_cursor && current < view.cursor { continue
		 }
		if height >= size.height { break
		 }
	}
	if view.scroll.has_more_vertical && height <= size.height {
		if builder.item_at_idx(index, view.cursor) == none { view.scroll.has_more_vertical = false }
	}
	mut content_height := scroll_total_height(children)
	if !view.scroll.has_more_vertical && content_height < size.height && view.scroll.top > 0 {
		view.insert_children(ctx, builder, mut children, vxfw_i17_cast(i64(vxfw_usize_sub(uint(size.height),
			content_height))))!
		content_height = scroll_total_height(children)
	}
	if view.draw_cursor && view.cursor >= view.scroll.top {
		cursor_index := vxfw_u32_sub(view.cursor, view.scroll.top)
		if uint(cursor_index) < uint(children.len) {
			child := children[int(cursor_index)]
			cursor_surface := Surface.init_with_children(view.widget(), Size{
				width:  offset
				height: child.surface.size.height
			}, [
				SubSurface{
					origin:  RelativePoint{
						col: vxfw_i17_sub(i32(offset), vxfw_i17_cast(i64(view.scroll.left)))
						row: 0
					}
					surface: child.surface
				},
			])
			for row in u16(0) .. cursor_surface.size.height {
				cursor_surface.write_cell(0, row, view.cursor_indicator)
			}
			children[int(cursor_index)] = SubSurface{
				origin:  RelativePoint{
					col: 0
					row: child.origin.row
				}
				surface: cursor_surface
			}
		}
	}
	if view.scroll.wants_cursor {
		cursor_index := vxfw_u32_sub(view.cursor, view.scroll.top)
		if uint(cursor_index) >= uint(children.len) { panic('index out of bounds') }
		sub := children[int(cursor_index)]
		bottom := vxfw_i17_add(sub.origin.row, i32(sub.surface.size.height))
		if bottom > size.height {
			mut origin := i32(size.height)
			mut idx := uint(vxfw_u32_add(cursor_index, 1))
			for idx > 0 {
				item := int(vxfw_usize_sub(idx, 1))
				origin = vxfw_i17_sub(origin, i32(children[item].surface.size.height))
				children[item].origin.row = origin
				idx = vxfw_usize_sub(idx, 1)
			}
		} else if sub.surface.size.height >= size.height {
			view.scroll.top = view.cursor
			view.scroll.vertical_offset = 0
			children = [
				SubSurface{
					origin:  RelativePoint{
						col: vxfw_i17_sub(0, vxfw_i17_cast(i64(view.scroll.left)))
						row: 0
					}
					surface: sub.surface
				},
			]
			content_height = sub.surface.size.height
		}
	}
	if !view.scroll.has_more_vertical && content_height < size.height {
		if view.scroll.top != 0 { panic('Assertion failed') }
		view.scroll.vertical_offset = 0
		mut origin := i32(0)
		for mut child in children {
			child.origin.row = origin
			origin = vxfw_i17_add(origin, i32(child.surface.size.height))
		}
	} else if !view.scroll.has_more_vertical {
		mut origin := i32(size.height)
		mut idx := uint(children.len)
		for idx > 0 {
			item := int(vxfw_usize_sub(idx, 1))
			origin = vxfw_i17_sub(origin, i32(children[item].surface.size.height))
			children[item].origin.row = origin
			idx = vxfw_usize_sub(idx, 1)
		}
	}
	view.scroll.has_more_horizontal = false
	for child in children {
		if u32(child.surface.size.width) > view.scroll.left
			&& u32(child.surface.size.width) - view.scroll.left > size.width {
			view.scroll.has_more_horizontal = true
			break
		}
	}
	mut start := 0
	mut end := children.len
	for idx, child in children {
		if child.origin.row <= 0
			&& vxfw_i17_add(child.origin.row, i32(child.surface.size.height)) > 0 {
			start = idx
			view.scroll.vertical_offset = vxfw_i17_sub(0, child.origin.row)
			view.scroll.top = vxfw_u32_add(view.scroll.top, vxfw_u32_cast(u64(idx)))
		}
		if child.origin.row > size.height {
			end = idx
			break
		}
	}
	_ = start
	_ = end
	surface.children = children
	view.last_height = u8(math.min(content_height, uint(255)))
	return surface
}

fn scroll_total_height(children []SubSurface) uint {
	mut result := uint(0)
	for child in children {
		result = vxfw_usize_add(result, uint(child.surface.size.height))
	}
	return result
}
