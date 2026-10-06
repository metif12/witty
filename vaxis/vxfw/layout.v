module vxfw

import vaxis
import math

pub struct Center {
pub mut:
	child Widget @[required]
}

pub fn (center &Center) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(center) }
		draw_fn:  center_draw
	}
}

fn center_draw(ptr voidptr, ctx DrawContext) !Surface {
	return unsafe { &Center(ptr) }.draw(ctx)
}

pub fn (center &Center) draw(ctx DrawContext) !Surface {
	if ctx.max.width == none { panic('Assertion failed') }
	if ctx.max.height == none { panic('Assertion failed') }
	size := ctx.max.size()
	child := center.child.draw(ctx.with_constraints(Size{}, ctx.max))!
	x := vxfw_u16_sub(size.width, child.size.width) / 2
	y := vxfw_u16_sub(size.height, child.size.height) / 2
	return Surface{
		buffer:   []vaxis.Cell{}
		size:     size
		widget:   center.widget()
		children: [
			SubSurface{
				origin:  RelativePoint{
					row: y
					col: x
				}
				surface: child
			},
		]
	}
}

pub struct PadValues {
pub mut:
	left   u16
	right  u16
	top    u16
	bottom u16
}

pub struct Padding {
pub mut:
	child   Widget @[required]
	padding PadValues
}

pub fn Padding.all(pad u16) PadValues {
	return PadValues{
		left:   pad
		right:  pad
		top:    pad / 2
		bottom: pad / 2
	}
}

pub fn Padding.horizontal(pad u16) PadValues {
	return PadValues{
		left:  pad
		right: pad
	}
}

pub fn Padding.vertical(pad u16) PadValues {
	return PadValues{
		top:    pad
		bottom: pad
	}
}

pub fn (padding &Padding) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(padding) }
		draw_fn:  padding_draw
	}
}

fn padding_draw(ptr voidptr, ctx DrawContext) !Surface {
	return unsafe { &Padding(ptr) }.draw(ctx)
}

pub fn (padding &Padding) draw(ctx DrawContext) !Surface {
	pad := padding.padding
	if (pad.left > 0 || pad.right > 0) && ctx.max.width == none { panic('Assertion failed') }
	if (pad.top > 0 || pad.bottom > 0) && ctx.max.height == none { panic('Assertion failed') }
	horizontal := vxfw_u16_add(pad.right, pad.left)
	vertical := vxfw_u16_add(pad.top, pad.bottom)
	min_size := Size{
		width:  sat_sub(ctx.min.width, horizontal)
		height: sat_sub(ctx.min.height, vertical)
	}
	max_size := MaxSize{
		width:  if width := ctx.max.width { sat_sub(width, horizontal) } else { none }
		height: if height := ctx.max.height { sat_sub(height, vertical) } else { none }
	}
	child := padding.child.draw(ctx.with_constraints(min_size, max_size))!
	return Surface{
		buffer:   []vaxis.Cell{}
		size:     Size{
			width:  vxfw_u16_add(child.size.width, horizontal)
			height: vxfw_u16_add(child.size.height, vertical)
		}
		widget:   padding.widget()
		children: [
			SubSurface{
				surface: child
				origin:  RelativePoint{
					row: pad.top
					col: pad.left
				}
			},
		]
	}
}

fn sat_sub(value u16, amount u16) u16 {
	return if value > amount { value - amount } else { 0 }
}

pub struct SizedBox {
pub mut:
	child Widget @[required]
	size  Size   @[required]
}

pub fn (box &SizedBox) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(box) }
		draw_fn:  sized_box_draw
	}
}

fn sized_box_draw(ptr voidptr, ctx DrawContext) !Surface {
	box := unsafe { &SizedBox(ptr) }
	max_size := MaxSize{
		width:  ctx.max.width or { box.size.width }
		height: ctx.max.height or { box.size.height }
	}
	min_size := Size{
		width:  math.min(math.max(ctx.min.width, box.size.width), max_size.width or {
			panic('unreachable')
		})
		height: math.min(math.max(ctx.min.height, box.size.height), max_size.height or {
			panic('unreachable')
		})
	}
	return box.child.draw(ctx.with_constraints(min_size, max_size))
}

pub enum BorderAlignment {
	top_left
	top_center
	top_right
	bottom_left
	bottom_center
	bottom_right
}
pub struct BorderLabel {
pub mut:
	text      string          @[required]
	alignment BorderAlignment @[required]
}

pub struct Border {
pub mut:
	child  Widget @[required]
	style  vaxis.Style
	labels []BorderLabel
}

pub fn (border &Border) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(border) }
		draw_fn:  border_draw
	}
}

fn border_draw(ptr voidptr, ctx DrawContext) !Surface {
	return unsafe { &Border(ptr) }.draw(ctx)
}

pub fn (border &Border) draw(ctx DrawContext) !Surface {
	max_size := MaxSize{
		width:  if width := ctx.max.width { sat_sub(width, 2) } else { none }
		height: if height := ctx.max.height { sat_sub(height, 2) } else { none }
	}
	child := border.child.draw(ctx.with_constraints(ctx.min, max_size))!
	size := Size{
		width:  vxfw_u16_add(child.size.width, 2)
		height: vxfw_u16_add(child.size.height, 2)
	}
	surface := Surface.init_with_children(border.widget(), size, [
		SubSurface{
			origin:  RelativePoint{
				row: 1
				col: 1
			}
			surface: child
		},
	])
	right := sat_sub(size.width, 1)
	bottom := sat_sub(size.height, 1)
	for i, corner in ['╭', '╮', '╯', '╰'] {
		col := if i in [1, 2] { right } else { u16(0) }
		row := if i in [2, 3] { bottom } else { u16(0) }
		surface.write_cell(col, row, vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: corner
				width:    1
			}
			style: border.style
		})
	}
	for col in u16(1) .. right {
		cell := vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: '─'
				width:    1
			}
			style: border.style
		}
		surface.write_cell(col, 0, cell)
		surface.write_cell(col, bottom, cell)
	}
	for row in u16(1) .. bottom {
		cell := vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: '│'
				width:    1
			}
			style: border.style
		}
		surface.write_cell(0, row, cell)
		surface.write_cell(right, row, cell)
	}
	for label in border.labels {
		length := vxfw_u16_cast(u64(ctx.string_width(label.text)))
		if length == 0 { continue
		 }
		row := if label.alignment in [.top_left, .top_center, .top_right] { u16(0) } else { bottom }
		mut col := match label.alignment {
			.top_left, .bottom_left {
				u16(1)
			}
			.top_center, .bottom_center {
				math.max(vxfw_u16_sub(size.width, length) / 2, u16(1))
			}
			.top_right, .bottom_right {
				math.max(vxfw_u16_sub(vxfw_u16_sub(size.width, 1), length), u16(1))
			}
		}

		mut chars := ctx.grapheme_iterator(label.text)
		for {
			grapheme := chars.next() or { break }
			width := vxfw_u16_cast(u64(ctx.string_width(grapheme)))
			surface.write_cell(col, row, vaxis.Cell{
				char_: vaxis.CellCharacter{
					grapheme: grapheme
					width:    vxfw_u8_cast(u64(width))
				}
				style: border.style
			})
			col = vxfw_u16_add(col, width)
		}
	}
	return surface
}

pub struct FlexColumn {
pub mut:
	children []FlexItem @[required]
}

pub fn (flex &FlexColumn) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(flex) }
		draw_fn:  flex_column_draw
	}
}

fn flex_column_draw(ptr voidptr, ctx DrawContext) !Surface {
	return unsafe { &FlexColumn(ptr) }.draw(ctx)
}

pub fn (flex &FlexColumn) draw(ctx DrawContext) !Surface {
	if ctx.max.height == none { panic('Assertion failed') }
	if ctx.max.width == none { panic('Assertion failed') }
	max_size := ctx.max.size()
	if flex.children.len == 0 { return Surface.init(flex.widget(), ctx.min) }
	mut sizes := []u16{len: flex.children.len}
	mut first_height := u16(0)
	mut total_flex := u16(0)
	first_pass := flex.children
	for i, child in first_pass {
		surface :=
			child.widget.draw(ctx.with_constraints(Size{}, MaxSize{ width: max_size.width }))!
		first_height = vxfw_u16_add(first_height, surface.size.height)
		total_flex = vxfw_u16_add(total_flex, u16(child.flex))
		sizes[i] = surface.size.height
	}
	remaining := vxfw_u16_sub(max_size.height, first_height)
	mut height := u16(0)
	mut width := u16(0)
	mut children := []SubSurface{}
	second_pass := flex.children
	for i, child in second_pass {
		child_height := if child.flex == 0 {
			sizes[i]
		} else if i == flex.children.len - 1 {
			vxfw_u16_sub(max_size.height, height)
		} else {
			vxfw_u16_add(sizes[i], layout_u16_div(vxfw_u16_mul(remaining, u16(child.flex)),
				total_flex))
		}
		surface := child.widget.draw(ctx.with_constraints(Size{ height: child_height }, MaxSize{
			width:  max_size.width
			height: child_height
		}))!
		children << SubSurface{
			origin:  RelativePoint{
				col: 0
				row: height
			}
			surface: surface
		}
		width = math.max(width, surface.size.width)
		height = vxfw_u16_add(height, surface.size.height)
	}
	return Surface{
		buffer:   []vaxis.Cell{}
		size:     Size{
			width:  width
			height: height
		}
		widget:   flex.widget()
		children: children
	}
}

pub struct FlexRow {
pub mut:
	children []FlexItem @[required]
}

pub fn (flex &FlexRow) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(flex) }
		draw_fn:  flex_row_draw
	}
}

fn flex_row_draw(ptr voidptr, ctx DrawContext) !Surface {
	return unsafe { &FlexRow(ptr) }.draw(ctx)
}

pub fn (flex &FlexRow) draw(ctx DrawContext) !Surface {
	if ctx.max.height == none { panic('Assertion failed') }
	if ctx.max.width == none { panic('Assertion failed') }
	max_size := ctx.max.size()
	if flex.children.len == 0 { return Surface.init(flex.widget(), ctx.min) }
	mut sizes := []u16{len: flex.children.len}
	mut first_width := u16(0)
	mut total_flex := u16(0)
	first_pass := flex.children
	for i, child in first_pass {
		if child.flex == 0 {
			surface := child.widget.draw(ctx.with_constraints(Size{}, MaxSize{
				height: max_size.height
			}))!
			sizes[i] = surface.size.width
			first_width = vxfw_u16_add(first_width, surface.size.width)
		}
		total_flex = vxfw_u16_add(total_flex, u16(child.flex))
	}
	remaining := sat_sub(max_size.width, first_width)
	mut width := u16(0)
	mut height := u16(0)
	mut children := []SubSurface{}
	second_pass := flex.children
	for i, child in second_pass {
		child_width := if child.flex == 0 {
			sizes[i]
		} else if i == flex.children.len - 1 {
			sat_sub(max_size.width, width)
		} else {
			layout_u16_div(vxfw_u16_mul(remaining, u16(child.flex)), total_flex)
		}
		surface := child.widget.draw(ctx.with_constraints(Size{ width: child_width }, MaxSize{
			width:  child_width
			height: max_size.height
		}))!
		children << SubSurface{
			origin:  RelativePoint{
				row: 0
				col: width
			}
			surface: surface
		}
		height = math.max(height, surface.size.height)
		width = vxfw_u16_add(width, surface.size.width)
	}
	return Surface{
		buffer:   []vaxis.Cell{}
		size:     Size{
			width:  width
			height: height
		}
		widget:   flex.widget()
		children: children
	}
}

fn layout_u16_div(numerator u16, denominator u16) u16 {
	if denominator == 0 { panic('division by zero') }
	return numerator / denominator
}
