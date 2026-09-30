module vxfw

import math
import vaxis

pub struct ScrollBars {
pub mut:
	draw_horizontal_scrollbar        bool = true
	draw_vertical_scrollbar          bool = true
	estimated_content_height         ?u32
	estimated_content_width          ?u32
	vertical_scrollbar_thumb         vaxis.Cell = vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '▐'
			width:    1
		}
	}
	vertical_scrollbar_hover_thumb   vaxis.Cell = vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '█'
			width:    1
		}
	}
	vertical_scrollbar_drag_thumb    vaxis.Cell = vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '█'
			width:    1
		}
		style: vaxis.Style{
			fg: vaxis.ColorIndex{
				index: 4
			}
		}
	}
	horizontal_scrollbar_thumb       vaxis.Cell = vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '▃'
			width:    1
		}
	}
	horizontal_scrollbar_hover_thumb vaxis.Cell = vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '█'
			width:    1
		}
	}
	horizontal_scrollbar_drag_thumb  vaxis.Cell = vaxis.Cell{
		char_: vaxis.CellCharacter{
			grapheme: '█'
			width:    1
		}
		style: vaxis.Style{
			fg: vaxis.ColorIndex{
				index: 4
			}
		}
	}
	scroll_view                      ScrollView
	last_frame_size                  Size
	last_frame_max_content_width     u32
	mouse_offset_into_thumb          u8
	vertical_thumb_top_row           u32
	vertical_thumb_bottom_row        u32
	is_hovering_vertical_thumb       bool
	is_dragging_vertical_thumb       bool
	horizontal_thumb_start_col       u32
	horizontal_thumb_end_col         u32
	is_hovering_horizontal_thumb     bool
	is_dragging_horizontal_thumb     bool
}

pub fn (bars &ScrollBars) widget() Widget {
	return Widget{
		userdata:        unsafe { voidptr(bars) }
		event_handler:   scroll_bars_event
		capture_handler: scroll_bars_capture
		draw_fn:         scroll_bars_draw
	}
}

fn scroll_bars_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut bars := unsafe { &ScrollBars(ptr) }
	bars.handle_event(mut ctx, event)!
}

fn scroll_bars_capture(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut bars := unsafe { &ScrollBars(ptr) }
	bars.handle_capture(mut ctx, event)!
}

fn scroll_bars_draw(ptr voidptr, ctx DrawContext) !Surface {
	mut bars := unsafe { &ScrollBars(ptr) }
	return bars.draw(ctx)
}

fn (bars &ScrollBars) over_vertical(mouse vaxis.Mouse) bool {
	return mouse.col == sat_sub(bars.last_frame_size.width, 1)
		&& mouse.row >= bars.vertical_thumb_top_row && mouse.row < bars.vertical_thumb_bottom_row
}

fn (bars &ScrollBars) over_horizontal(mouse vaxis.Mouse) bool {
	return mouse.row == sat_sub(bars.last_frame_size.height, 1)
		&& mouse.col >= bars.horizontal_thumb_start_col && mouse.col < bars.horizontal_thumb_end_col
}

fn (view &ScrollView) count_children() u32 {
	if count := view.item_count { return count }
	match view.children {
		ScrollSlice {
			return u32(view.children.widgets.len)
		}
		ScrollBuilder {
			mut count := u32(0)
			for view.children.item_at_idx(count, view.cursor) != none {
				count++
			}
			return count
		}
	}
}

pub fn (mut bars ScrollBars) handle_capture(mut ctx EventContext, event Event) ! {
	if event !is vaxis.Mouse { return }
	if bars.is_dragging_vertical_thumb {
		if event.type_ == .release && event.button == .left {
			bars.is_dragging_vertical_thumb = false
			ctx.redraw = true
			if !bars.over_vertical(event as vaxis.Mouse) {
				bars.is_hovering_vertical_thumb = false
				ctx.redraw = true
			}
			ctx.consume_event()
			return
		}
		if event.type_ == .drag {
			ctx.consume_event()
			top := sat_sub(event.row, bars.mouse_offset_into_thumb)
			if top == 0 {
				bars.scroll_view.scroll.top = 0
				ctx.consume_and_redraw()
				return
			}
			bars.scroll_view.scroll.top = u32(f32(top) * f32(bars.scroll_view.count_children()) / f32(bars.last_frame_size.height))
			ctx.consume_and_redraw()
			return
		}
	}
	if bars.is_dragging_horizontal_thumb {
		if event.type_ == .release && event.button == .left {
			bars.is_dragging_horizontal_thumb = false
			ctx.redraw = true
			if !bars.over_horizontal(event as vaxis.Mouse) {
				bars.is_hovering_horizontal_thumb = false
				ctx.redraw = true
			}
			ctx.consume_event()
			return
		}
		if event.type_ == .drag {
			ctx.consume_event()
			start := sat_sub(event.col, bars.mouse_offset_into_thumb)
			if start == 0 {
				bars.scroll_view.scroll.left = 0
				ctx.consume_and_redraw()
				return
			}
			position := f32(start) * f32(bars.last_frame_max_content_width) / f32(bars.last_frame_size.width)
			bars.scroll_view.scroll.left = math.min(u32(math.ceil(position)),
				bars.last_frame_max_content_width)
			ctx.consume_and_redraw()
			return
		}
	}
}

pub fn (mut bars ScrollBars) handle_event(mut ctx EventContext, event Event) ! {
	match event {
		vaxis.Mouse {
			vertical := bars.over_vertical(event as vaxis.Mouse)
			if bars.is_hovering_vertical_thumb != vertical {
				bars.is_hovering_vertical_thumb = vertical
				ctx.redraw = true
			}
			if vertical && event.type_ == .press && event.button == .left {
				bars.is_dragging_vertical_thumb = true
				bars.mouse_offset_into_thumb = u8(if u32(event.row) > bars.vertical_thumb_top_row {
					u32(event.row) - bars.vertical_thumb_top_row
				} else {
					0
				})
				ctx.consume_event()
				return
			}
			horizontal := bars.over_horizontal(event as vaxis.Mouse)
			if bars.is_hovering_horizontal_thumb != horizontal {
				bars.is_hovering_horizontal_thumb = horizontal
				ctx.redraw = true
			}
			if horizontal && event.type_ == .press && event.button == .left {
				bars.is_dragging_horizontal_thumb = true
				bars.mouse_offset_into_thumb = u8(if u32(event.col) > bars.horizontal_thumb_start_col {
					u32(event.col) - bars.horizontal_thumb_start_col
				} else {
					0
				})
				ctx.consume_event()
				return
			}
		}
		vaxis.MouseLeave {
			bars.is_dragging_vertical_thumb = false
		}
		else {}
	}
}

pub fn (mut bars ScrollBars) draw(ctx DrawContext) !Surface {
	mut children := []SubSurface{}
	if !bars.draw_vertical_scrollbar && !bars.draw_horizontal_scrollbar {
		children << SubSurface{
			surface: bars.scroll_view.draw(ctx)!
		}
		return Surface{
			size:     ctx.max.size()
			widget:   bars.widget()
			children: children
		}
	}
	size := ctx.max.size()
	bars.last_frame_size = size
	view := bars.scroll_view.draw(ctx.with_constraints(ctx.min, MaxSize{
		width:  sat_sub(size.width, u16(bars.draw_vertical_scrollbar))
		height: sat_sub(size.height, u16(bars.draw_horizontal_scrollbar))
	}))!
	children << SubSurface{
		surface: view
	}
	if bars.draw_vertical_scrollbar && !(bars.scroll_view.scroll.top == 0
		&& !bars.scroll_view.scroll.has_more_vertical) {
		height := f32(view.size.height)
		count := f32(bars.scroll_view.count_children())
		thumb_height := if estimated := bars.estimated_content_height {
			u16(math.max(height * height / f32(estimated), f32(1)))
		} else {
			u16(math.max(height * f32(view.children.len) / count, f32(1)))
		}
		top := if bars.scroll_view.scroll.top == 0 {
			u32(0)
		} else if bars.scroll_view.scroll.has_more_vertical {
			u32(height * f32(bars.scroll_view.scroll.top) / count)
		} else {
			u32(sat_sub(size.height, thumb_height))
		}
		bar := Surface.init(bars.widget(), Size{
			width:  1
			height: sat_sub(size.height, u16(bars.draw_horizontal_scrollbar))
		})
		end := top + thumb_height
		cell := if bars.is_dragging_vertical_thumb {
			bars.vertical_scrollbar_drag_thumb
		} else if bars.is_hovering_vertical_thumb {
			bars.vertical_scrollbar_hover_thumb
		} else {
			bars.vertical_scrollbar_thumb
		}
		for row in top .. end {
			bar.write_cell(0, u16(row), cell)
		}
		bars.vertical_thumb_top_row = top
		bars.vertical_thumb_bottom_row = end
		children << SubSurface{
			origin:  RelativePoint{
				col: sat_sub(size.width, 1)
			}
			surface: bar
		}
	}
	if bars.draw_horizontal_scrollbar
		&& (bars.scroll_view.scroll.left > 0 || bars.scroll_view.scroll.has_more_horizontal) {
		bar := Surface.init(bars.widget(), Size{ width: size.width, height: 1 })
		content_width := bars.estimated_content_width or {
			mut widest := u32(0)
			for child in view.children {
				widest = math.max(widest, u32(child.surface.size.width))
			}
			widest
		}

		width := f32(size.width)
		resolved_width := f32(math.max(bars.scroll_view.scroll.left + size.width, content_width))
		bars.last_frame_max_content_width = content_width
		thumb_width := u32(math.max(width * width / resolved_width, f32(1)))
		start := u32(f32(bars.scroll_view.scroll.left) * width / resolved_width)
		end := start + thumb_width
		cell := if bars.is_dragging_horizontal_thumb {
			bars.horizontal_scrollbar_drag_thumb
		} else if bars.is_hovering_horizontal_thumb {
			bars.horizontal_scrollbar_hover_thumb
		} else {
			bars.horizontal_scrollbar_thumb
		}
		for col in start .. end {
			bar.write_cell(u16(col), 0, cell)
		}
		bars.horizontal_thumb_start_col = start
		bars.horizontal_thumb_end_col = end
		children << SubSurface{
			origin:  RelativePoint{
				row: sat_sub(size.height, 1)
			}
			surface: bar
		}
	}
	return Surface{
		size:     size
		widget:   bars.widget()
		children: children
	}
}
