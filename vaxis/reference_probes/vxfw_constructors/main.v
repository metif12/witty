module main

import vaxis.vxfw

fn draw(_ voidptr, _ vxfw.DrawContext) !vxfw.Surface {
	return vxfw.Surface.empty(vxfw.Widget{ userdata: voidptr(1), draw_fn: draw })
}

fn click(_ voidptr, mut ctx vxfw.EventContext) ! {
	_ = ctx
}

fn build(_ voidptr, _ usize, _ usize) ?vxfw.Widget {
	return none
}

fn main() {
	user := vxfw.UserEvent{
		name: 'event'
	}
	widget := vxfw.Widget{
		userdata: voidptr(1)
		draw_fn:  draw
	}
	flex := vxfw.FlexItem{
		widget: widget
	}
	context := vxfw.EventContext{
		cmds: []vxfw.Command{}
	}
	constraints := vxfw.DrawContext{
		min:       vxfw.Size{}
		max:       vxfw.MaxSize{}
		cell_size: vxfw.Size{}
	}
	cursor := vxfw.CursorState{
		row: 7
		col: 9
	}
	surface := vxfw.Surface.empty(widget)
	sub := vxfw.SubSurface{
		origin:  vxfw.RelativePoint{
			row: 0
			col: 0
		}
		surface: surface
	}
	println('${int(user.data == unsafe { nil })},${int(widget.capture_handler == none)},${int(widget.event_handler == none)},${flex.flex},${int(context.phase)},${context.cmds.len},${int(context.consume_event)},${int(context.redraw)},${int(context.quit)},${
		constraints.min.width + constraints.min.height},${int(constraints.max.width == none
		&& constraints.max.height == none)},${constraints.cell_size.width +
		constraints.cell_size.height},${int(cursor.shape)},${int(surface.cursor == none)},${sub.z_index},${
		cursor.row + cursor.col}')
	center := vxfw.Center{
		child: widget
	}
	padding := vxfw.Padding{
		child: widget
	}
	sized := vxfw.SizedBox{
		child: widget
		size:  vxfw.Size{
			width:  7
			height: 9
		}
	}
	border := vxfw.Border{
		child: widget
	}
	label := vxfw.BorderLabel{
		text:      'label'
		alignment: .top_right
	}
	column := vxfw.FlexColumn{
		children: []
	}
	row := vxfw.FlexRow{
		children: []
	}
	button := vxfw.Button{
		label:    'button'
		on_click: click
	}
	text := vxfw.Text{
		text: 'text'
	}
	rich := vxfw.RichText{
		text: []
	}
	field := vxfw.TextField.init()
	list := vxfw.ListView{
		children: vxfw.ListSlice{
			widgets: []
		}
	}
	scrolling := vxfw.ScrollView{
		children: vxfw.ScrollSlice{
			widgets: []
		}
	}
	bars := vxfw.ScrollBars{
		scroll_view: scrolling
	}
	split := vxfw.SplitView{
		lhs:   widget
		rhs:   widget
		width: 7
	}
	mut spinner := vxfw.Spinner{}
	list_builder := vxfw.ListBuilder{
		userdata: voidptr(1)
		build_fn: build
	}
	scroll_builder := vxfw.ScrollBuilder{
		userdata: voidptr(1)
		build_fn: build
	}
	println('${int(center.child.userdata == widget.userdata)},${padding.padding.left +
		padding.padding.right + padding.padding.top + padding.padding.bottom},${sized.size.width +
		sized.size.height},${border.labels.len},${label.text.len},${int(label.alignment)},${column.children.len},${row.children.len},${button.label.len},${int(button.userdata == unsafe { nil })},${int(button.style.default_.reverse)},${int(button.mouse_down)},${int(button.has_mouse)},${int(button.focused)},${text.text.len},${int(text.text_align)},${int(text.softwrap)},${int(text.overflow)},${int(text.width_basis)},${rich.text.len},${int(rich.text_align)},${int(rich.softwrap)},${int(rich.overflow)},${int(rich.width_basis)},${field.buf.buffer.len},${field.buf.cursor},${field.buf.gap_size},${field.draw_offset},${field.prev_cursor_col},${field.prev_cursor_idx},${field.scroll_offset},${field.prev_width},${field.previous_val.len},${int(field.userdata == unsafe { nil })},${int(field.on_change == none)},${int(field.on_submit == none)},${list.cursor},${int(list.draw_cursor)},${list.wheel_scroll},${int(list.item_count == none)},${int(list.scroll.has_more)},${scrolling.cursor},${scrolling.last_height},${int(scrolling.draw_cursor)},${scrolling.wheel_scroll},${int(scrolling.item_count == none)},${int(scrolling.scroll.has_more_vertical)},${int(scrolling.scroll.has_more_horizontal)},${int(bars.draw_vertical_scrollbar)},${int(bars.draw_horizontal_scrollbar)},${int(bars.estimated_content_height == none)},${int(bars.estimated_content_width == none)},${split.width},${split.min_width},${int(split.max_width == none)},${int(split.constrain)},${int(split.last_max_width == none)},${int(split.pressed)},${int(split.mouse_set)},${spinner.frame},${spinner.count.load()},${int(spinner.was_spinning.load())},${int(list_builder.userdata == scroll_builder.userdata)}')
}
