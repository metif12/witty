module vxfw

import math
import vaxis

pub enum SplitConstraint {
	lhs
	rhs
}
pub struct SplitView {
pub mut:
	lhs            Widget @[required]
	rhs            Widget @[required]
	constrain      SplitConstraint = .lhs
	style          vaxis.Style
	min_width      u16
	max_width      ?u16
	width          u16 @[required]
	last_max_width ?u16
	pressed        bool
	mouse_set      bool
}

pub fn (split &SplitView) widget() Widget {
	return Widget{
		userdata:      unsafe { voidptr(split) }
		event_handler: split_event
		draw_fn:       split_draw
	}
}

fn split_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut split := unsafe { &SplitView(ptr) }
	if event is vaxis.MouseLeave {
		split.pressed = false
		return
	}
	if event !is vaxis.Mouse { return }
	separator := match split.constrain {
		.lhs {
			split.width
		}
		.rhs {
			if width := split.last_max_width {
				sat_sub(sat_sub(width, split.width), 1)
			} else {
				ctx.redraw = true
				return
			}
		}
	}

	if event.col == separator {
		ctx.set_mouse_shape(.ew_resize)
		split.mouse_set = true
		if event.type_ == .press && event.button == .left { split.pressed = true }
	} else if split.mouse_set {
		ctx.set_mouse_shape(.default)
		split.mouse_set = false
	}
	if event.type_ == .release {
		split.pressed = false
		split.mouse_set = false
		ctx.set_mouse_shape(.default)
	}
	if split.pressed {
		ctx.set_mouse_shape(.ew_resize)
		match split.constrain {
			.lhs {
				split.width = math.max(split.min_width, event.col)
				if max_width := split.max_width { split.width = math.min(split.width, max_width) }
			}
			.rhs {
				last := split.last_max_width or { return }
				split.width = math.min(sat_sub(last, split.min_width), sat_sub(sat_sub(last,
					event.col), 1))
				if max_width := split.max_width { split.width = math.max(split.width, max_width) }
			}
		}

		ctx.consume_event = true
	}
}

fn split_draw(ptr voidptr, ctx DrawContext) !Surface {
	mut split := unsafe { &SplitView(ptr) }
	size := ctx.max.size()
	split.width = math.min(split.width, size.width)
	split.last_max_width = size.width
	constrained := Size{
		width:  split.width
		height: size.height
	}
	unconstrained := Size{
		width:  sat_sub(sat_sub(size.width, split.width), 1)
		height: size.height
	}
	lhs_size := if split.constrain == .lhs { constrained } else { unconstrained }
	rhs_size := if split.constrain == .rhs { constrained } else { unconstrained }
	mut children := []SubSurface{cap: 2}
	if lhs_size.width > 0 && lhs_size.height > 0 {
		children << SubSurface{
			origin:  RelativePoint{
				row: 0
				col: 0
			}
			surface: split.lhs.draw(ctx.with_constraints(lhs_size, MaxSize.from_size(lhs_size)))!
		}
	}
	if rhs_size.width > 0 && rhs_size.height > 0 {
		children << SubSurface{
			surface: split.rhs.draw(ctx.with_constraints(rhs_size, MaxSize.from_size(rhs_size)))!
			origin:  RelativePoint{
				row: 0
				col: lhs_size.width + 1
			}
		}
	}
	surface := Surface.init_with_children(split.widget(), size, children)
	separator := if split.constrain == .lhs {
		split.width
	} else {
		sat_sub(sat_sub(size.width, split.width), 1)
	}
	for row in u16(0) .. size.height {
		surface.write_cell(separator, row, vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: '│'
				width:    1
			}
			style: split.style
		})
	}
	return surface
}
