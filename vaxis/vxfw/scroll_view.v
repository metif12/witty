module vxfw

import math
import vaxis

pub type ScrollBuildFn = fn (voidptr, usize, usize) ?Widget

pub struct ScrollBuilder {
pub mut:
	userdata voidptr
	build_fn ScrollBuildFn @[required]
}

pub fn (builder ScrollBuilder) item_at_idx(index usize, cursor usize) ?Widget {
	return builder.build_fn(builder.userdata, index, cursor)
}

pub struct ScrollSlice {
pub mut:
	widgets []Widget
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
	scroll.pending_lines += n
	return true
}

pub fn (mut scroll ViewScroll) lines_up(n u8) bool {
	if scroll.top == 0 && scroll.vertical_offset == 0 { return false }
	scroll.pending_lines -= n
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
	children         ScrollSource
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
	assert ctx.max.width != none && ctx.max.height != none
	match view.children {
		ScrollSlice {
			view.item_count = u32(view.children.widgets.len)
			builder := &ScrollSlice{
				widgets: view.children.widgets
			}
			return view.draw_builder(ctx, ScrollBuilder{
				userdata: builder
				build_fn: scroll_slice_build
			})
		}
		ScrollBuilder {
			return view.draw_builder(ctx, view.children)
		}
	}
}

fn scroll_slice_build(ptr voidptr, index usize, _ usize) ?Widget {
	slice := unsafe { &ScrollSlice(ptr) }
	if index >= usize(slice.widgets.len) { return none }
	return slice.widgets[int(index)]
}

pub fn (mut view ScrollView) next_item(mut ctx EventContext) {
	if count := view.item_count {
		if view.cursor >= count - 1 {
			ctx.consume_event()
			return
		}
		view.cursor++
	} else {
		match view.children {
			ScrollSlice {
				view.item_count = u32(view.children.widgets.len)
				if view.cursor == u32(view.children.widgets.len - 1) {
					ctx.consume_event()
					return
				}
				view.cursor++
			}
			ScrollBuilder {
				previous := view.cursor
				view.cursor++
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

pub fn (mut view ScrollView) prev_item(mut ctx EventContext) {
	if view.cursor == 0 {
		ctx.consume_event()
		return
	}
	if count := view.item_count {
		view.cursor = math.min(view.cursor - 1, count - 1)
	} else {
		match view.children {
			ScrollSlice {
				view.item_count = u32(view.children.widgets.len)
				view.cursor = math.min(view.cursor - 1, u32(view.children.widgets.len - 1))
			}
			ScrollBuilder {
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

pub fn (mut view ScrollView) ensure_scroll() {
	if view.cursor <= view.scroll.top {
		view.scroll.top = view.cursor
		view.scroll.vertical_offset = 0
	} else {
		view.scroll.wants_cursor = true
	}
}

fn (mut view ScrollView) insert_children(ctx DrawContext, builder ScrollBuilder, mut children []SubSurface, add_height i32) ! {
	assert view.scroll.top > 0
	view.scroll.top--
	mut upheight := add_height
	for {
		child := builder.item_at_idx(view.scroll.top, view.cursor) or { break }
		offset := if view.draw_cursor { u16(2) } else { u16(0) }
		size := ctx.max.size()
		surface := child.draw(ctx.with_constraints(Size{ width: size.width - offset }, MaxSize{}))!
		upheight -= surface.size.height
		children.insert(0, SubSurface{
			origin:  RelativePoint{
				col: i32(offset) - i32(view.scroll.left)
				row: upheight
			}
			surface: surface
		})
		if upheight <= 0 || view.scroll.top == 0 { break
		 }
		view.scroll.top--
	}
	view.scroll.vertical_offset = upheight
	if view.scroll.top == 0 && upheight > 0 {
		view.scroll.vertical_offset = 0
		mut row := i32(0)
		for mut child in children {
			child.origin.row = row
			row += child.surface.size.height
		}
	}
	view.scroll.vertical_offset = upheight
}

fn (mut view ScrollView) draw_builder(ctx DrawContext, builder ScrollBuilder) !Surface {
	defer { view.scroll.wants_cursor = false }
	size := ctx.max.size()
	mut surface := Surface{
		size:   size
		widget: view.widget()
	}
	view.scroll.has_more_vertical = true
	mut children := []SubSurface{}
	mut height := -(view.scroll.vertical_offset + view.scroll.pending_lines)
	view.scroll.pending_lines = 0
	mut index := usize(view.scroll.top)
	if height > 0 && view.scroll.top == 0 {
		view.scroll.vertical_offset = 0
		height = 0
	}
	if height > 0 {
		view.insert_children(ctx, builder, mut children, height)!
		last := children.last()
		height = last.origin.row + last.surface.size.height
	}
	offset := if view.draw_cursor { u16(2) } else { u16(0) }
	for {
		child := builder.item_at_idx(index, view.cursor) or {
			view.scroll.has_more_vertical = false
			break
		}
		child_width := size.width - offset
		child_surface := child.draw(ctx.with_constraints(Size{ width: child_width }, MaxSize{}))!
		children << SubSurface{
			origin:  RelativePoint{
				col: i32(offset) - i32(view.scroll.left)
				row: height
			}
			surface: child_surface
		}
		height += child_surface.size.height
		current := index
		index++
		if view.scroll.wants_cursor && current < view.cursor { continue
		 }
		if height >= size.height { break
		 }
	}
	if view.scroll.has_more_vertical && height <= size.height {
		if builder.item_at_idx(index, view.cursor) == none { view.scroll.has_more_vertical = false }
	}
	mut content_height := total_height(children)
	if !view.scroll.has_more_vertical && content_height < size.height && view.scroll.top > 0 {
		view.insert_children(ctx, builder, mut children, i32(usize(size.height) - content_height))!
		content_height = total_height(children)
	}
	if view.draw_cursor && view.cursor >= view.scroll.top {
		cursor_index := int(view.cursor - view.scroll.top)
		if cursor_index < children.len {
			child := children[cursor_index]
			cursor_surface := Surface.init_with_children(view.widget(), Size{
				width:  offset
				height: child.surface.size.height
			}, [
				SubSurface{
					origin:  RelativePoint{
						col: i32(offset) - i32(view.scroll.left)
					}
					surface: child.surface
				},
			])
			for row in u16(0) .. cursor_surface.size.height {
				cursor_surface.write_cell(0, row, view.cursor_indicator)
			}
			children[cursor_index] = SubSurface{
				origin:  RelativePoint{
					row: child.origin.row
				}
				surface: cursor_surface
			}
		}
	}
	if view.scroll.wants_cursor {
		cursor_index := int(view.cursor - view.scroll.top)
		sub := children[cursor_index]
		bottom := sub.origin.row + sub.surface.size.height
		if bottom > size.height {
			mut origin := i32(size.height)
			for idx := cursor_index; idx >= 0; idx-- {
				origin -= children[idx].surface.size.height
				children[idx].origin.row = origin
			}
		} else if sub.surface.size.height >= size.height {
			view.scroll.top = view.cursor
			view.scroll.vertical_offset = 0
			children = [
				SubSurface{
					origin:  RelativePoint{
						col: -i32(view.scroll.left)
					}
					surface: sub.surface
				},
			]
			content_height = sub.surface.size.height
		}
	}
	if !view.scroll.has_more_vertical && content_height < size.height {
		assert view.scroll.top == 0
		view.scroll.vertical_offset = 0
		mut origin := i32(0)
		for mut child in children {
			child.origin.row = origin
			origin += child.surface.size.height
		}
	} else if !view.scroll.has_more_vertical {
		mut origin := i32(size.height)
		for idx := children.len - 1; idx >= 0; idx-- {
			origin -= children[idx].surface.size.height
			children[idx].origin.row = origin
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
		if child.origin.row <= 0 && child.origin.row + child.surface.size.height > 0 {
			start = idx
			view.scroll.vertical_offset = -child.origin.row
			view.scroll.top += u32(idx)
		}
		if child.origin.row > size.height {
			end = idx
			break
		}
	}
	_ = start
	_ = end
	surface.children = children
	view.last_height = u8(math.min(content_height, usize(255)))
	return surface
}
