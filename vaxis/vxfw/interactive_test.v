module vxfw

import vaxis

struct ClickCount {
mut:
	clicks int
}

fn count_click(ptr voidptr, mut ctx EventContext) ! {
	mut count := unsafe { &ClickCount(ptr) }
	count.clicks++
	ctx.consume_and_redraw()
}

fn test_button_source_press_release_leave_key_and_centered_label() {
	DrawContext.init(.unicode)
	mut count := ClickCount{}
	mut button := Button{
		label:    'Test Button'
		userdata: &count
		on_click: count_click
	}
	mut ctx := EventContext{}
	button.handle_event(mut ctx, Event(vaxis.Mouse{
		type_:  .press
		button: .left
	}))!
	assert count.clicks == 0
	button.handle_event(mut ctx, Event(vaxis.Mouse{
		type_:  .release
		button: .left
	}))!
	assert count.clicks == 1
	button.handle_event(mut ctx, Event(vaxis.Mouse{
		type_:  .press
		button: .left
	}))!
	button.handle_event(mut ctx, Event(vaxis.MouseLeave{}))!
	button.handle_event(mut ctx, Event(vaxis.Mouse{
		type_:  .release
		button: .left
	}))!
	assert count.clicks == 1
	button.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: vaxis.enter
	}))!
	assert count.clicks == 2
	surface := button.draw(DrawContext{
		max: MaxSize{
			width:  13
			height: 3
		}
	})!
	assert surface.size == Size{
		width:  13
		height: 3
	}
	assert surface.children[0].origin == RelativePoint{
		row: 1
		col: 1
	}
	assert surface.buffer[0].style.reverse
}

fn test_spinner_counter_rearm_and_final_clear_tick() {
	mut spinner := Spinner{}
	assert spinner.start() != none
	assert spinner.start() == none
	assert spinner.count.load() == 2
	mut ctx := EventContext{
		redraw: false
	}
	spinner.handle_event(mut ctx, Event(TickEvent{}))!
	assert spinner.frame == 1
	assert ctx.cmds.len == 1
	assert !ctx.redraw // Pinned handler only explicitly redraws its stopping tick.
	surface := spinner.draw(DrawContext{})!
	assert surface.size == Size{
		width:  1
		height: 1
	}
	assert surface.buffer[0].char_.grapheme == '⣧'
	spinner.stop()
	spinner.stop()
	spinner.stop()
	assert spinner.count.load() == 0
	spinner.handle_event(mut ctx, Event(TickEvent{}))!
	assert ctx.redraw
	assert !spinner.was_spinning()
	assert spinner.draw(DrawContext{})!.buffer[0].char_.grapheme == ' '
}

fn test_split_view_source_separator_drag_and_rhs_constraint() {
	DrawContext.init(.unicode)
	lhs := &Text{
		text: 'Left hand side'
	}
	rhs := &Text{
		text: 'Right hand side'
	}
	mut split := SplitView{
		lhs:   lhs.widget()
		rhs:   rhs.widget()
		width: 8
	}
	ctx := DrawContext{
		max: MaxSize{
			width:  16
			height: 16
		}
	}
	surface := split.widget().draw(ctx)!
	assert surface.size == Size{
		width:  16
		height: 16
	}
	assert surface.children[0].surface.size.width == 8
	assert surface.read_cell(8, 0).char_.grapheme == '│'
	mut events := EventContext{}
	split.widget().handle_event(mut events, Event(vaxis.Mouse{
		col:    8
		type_:  .press
		button: .left
	}))!
	assert split.pressed
	split.widget().handle_event(mut events, Event(vaxis.Mouse{
		col:    2
		type_:  .drag
		button: .left
	}))!
	assert split.width == 2 && events.consume_event
	mut right := SplitView{
		lhs:       lhs.widget()
		rhs:       rhs.widget()
		constrain: .rhs
		width:     4
	}
	right_surface := right.widget().draw(ctx)!
	assert right_surface.children[1].origin.col == 12
	assert right_surface.read_cell(11, 0).char_.grapheme == '│'
}

struct FieldValues {
mut:
	changed   []string
	submitted []string
}

fn field_change(ptr voidptr, mut _ EventContext, value string) ! {
	mut values := unsafe { &FieldValues(ptr) }
	values.changed << value.clone()
}

fn field_submit(ptr voidptr, mut _ EventContext, value string) ! {
	mut values := unsafe { &FieldValues(ptr) }
	values.submitted << value.clone()
}

fn test_text_field_change_submit_grapheme_navigation_and_resize() {
	DrawContext.init(.unicode)
	mut values := FieldValues{}
	mut field := TextField{
		buf:       vaxis.TextInputBuffer.new()
		userdata:  &values
		on_change: field_change
		on_submit: field_submit
	}
	mut ctx := EventContext{}
	field.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: u32(`a`)
		text:      'a👩\u200d💻b'
	}))!
	assert values.changed == ['a👩\u200d💻b']
	assert field.graphemes_before_cursor() == 3
	field.cursor_left()
	field.delete_before_cursor()
	assert field.buf.string() == 'ab'
	field.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: vaxis.enter
	}))!
	assert values.submitted == ['ab']
	assert field.buf.string() == ''
	field.insert_slice_at_cursor('hello, world')
	field.cursor_left()
	field.cursor_left()
	field.cursor_left()
	mut bytes := []u8{len: 32}
	assert field.slice_to_cursor(mut bytes).bytestr() == 'hello, wo'
	narrow := field.draw(DrawContext{
		max: MaxSize{
			width: 5
		}
	})!
	assert narrow.buffer[0].char_.grapheme == '…'
	assert narrow.cursor or { panic('cursor') }.col < 5
	wide := field.draw(DrawContext{
		max: MaxSize{
			width: 20
		}
	})!
	assert field.draw_offset == 0
	assert wide.cursor or { panic('cursor') }.col == 9
	assert wide.buffer[0].char_.grapheme == 'h'
}
