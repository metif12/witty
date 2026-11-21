module vxfw

import vaxis

struct TextFieldFidelitySpy {
mut:
	field    &TextField = unsafe { nil }
	fail     bool
	values   []string
	before   []string
	previous []string
	consumed []bool
	redraw   []bool
	offsets  []u16
}

fn fidelity_callback(ptr voidptr, mut ctx EventContext, value string) ! {
	mut spy := unsafe { &TextFieldFidelitySpy(ptr) }
	spy.values << value.clone()
	spy.before << spy.field.buf.string()
	spy.previous << spy.field.previous_val.clone()
	spy.consumed << ctx.consume_event
	spy.redraw << ctx.redraw
	spy.offsets << spy.field.draw_offset
	spy.field.insert_slice_at_cursor('!')
	ctx.consume_event = false
	ctx.redraw = false
	if spy.fail { return error('CallbackFailure') }
}

fn test_text_field_change_error_keeps_snapshot_and_context_order() {
	mut field := TextField.init()
	mut spy := TextFieldFidelitySpy{
		field: &field
		fail:  true
	}
	field.userdata = &spy
	field.on_change = fidelity_callback
	mut ctx := EventContext{
		cmds:   []Command{}
		redraw: false
	}
	mut failed := false
	field.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: u32(`a`)
		text:      'abc'
	})) or {
		assert err.msg() == 'CallbackFailure'
		failed = true
	}
	assert failed
	assert spy.values == ['abc'] && spy.before == ['abc']
	assert spy.previous == [''] && spy.consumed == [true] && spy.redraw == [true]
	assert field.previous_val == 'abc' && field.buf.string() == 'abc!'
	assert !ctx.consume_event && !ctx.redraw
	field.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: vaxis.backspace
	}))!
	assert field.buf.string() == 'abc' && field.previous_val == 'abc'
	assert spy.values.len == 1
	assert ctx.consume_event && ctx.redraw
}

fn test_text_field_submit_clears_and_resets_before_callback() {
	mut field := TextField.init()
	field.insert_slice_at_cursor('abc')
	field.draw_offset = 7
	field.prev_cursor_col = 11
	field.prev_cursor_idx = 13
	field.prev_width = 17
	field.previous_val = 'old'
	mut spy := TextFieldFidelitySpy{
		field: &field
		fail:  true
	}
	field.userdata = &spy
	field.on_submit = fidelity_callback
	mut ctx := EventContext{
		cmds:   []Command{}
		redraw: false
	}
	mut failed := false
	field.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: vaxis.enter
	})) or {
		assert err.msg() == 'CallbackFailure'
		failed = true
	}
	assert failed
	assert spy.values == ['abc'] && spy.before == [''] && spy.previous == ['old']
	assert spy.offsets == [u16(0)] && spy.consumed == [false] && spy.redraw == [false]
	assert field.buf.string() == '!' && field.previous_val == 'old'
	assert field.draw_offset == 0 && field.prev_cursor_col == 0 && field.prev_cursor_idx == 0
	assert field.prev_width == 17 && !ctx.consume_event && !ctx.redraw
	spy.fail = false
	field.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: vaxis.enter
	}))!
	assert spy.values == ['abc', '!']
	assert spy.before == ['', ''] && spy.previous == ['old', 'old']
	assert ctx.consume_event && ctx.redraw
}

fn test_text_field_slice_borrows_caller_prefix_and_keeps_tail() {
	mut field := TextField.init()
	field.buf.insert_slice_at_cursor('a\x00界b')
	field.buf.move_gap_left(1)
	mut output := []u8{len: 8, init: 0xa5}
	prefix := field.slice_to_cursor(mut output)
	assert prefix.bytestr() == 'a\x00界'
	assert prefix.data == output.data
	output[0] = `z`
	assert prefix[0] == `z`
	assert output[5..] == [u8(0xa5), 0xa5, 0xa5]
	assert field.buf.first_half().bytestr() == 'a\x00界'
}

fn test_text_field_raw_graphemes_and_context_width_methods() {
	mut field := TextField.init()
	field.insert_slice_at_cursor('\xffA')
	assert field.buf.string().bytes() == [u8(0xff), `A`]
	assert field.graphemes_before_cursor() == 2
	DrawContext.init(.unicode)
	assert field.width_to_cursor(DrawContext{
		min:       Size{}
		max:       MaxSize{}
		cell_size: Size{}
	}) == 2
	field.clear_and_free()
	field.insert_slice_at_cursor('T👍🏽')
	assert field.graphemes_before_cursor() == 2
	DrawContext.init(.wcwidth)
	assert field.width_to_cursor(DrawContext{
		min:       Size{}
		max:       MaxSize{}
		cell_size: Size{}
	}) == 5
	field.draw_offset = 1
	assert field.width_to_cursor(DrawContext{
		min:       Size{}
		max:       MaxSize{}
		cell_size: Size{}
	}) == 4
	field.cursor_left()
	assert field.buf.first_half().bytestr() == 'T'
	assert field.buf.second_half().bytestr() == '👍🏽'
	field.cursor_right()
	DrawContext.init(.unicode)
	assert field.width_to_cursor(DrawContext{
		min:       Size{}
		max:       MaxSize{}
		cell_size: Size{}
	}) == 2
}

fn test_text_field_width_iteration_retains_usize_count() {
	mut field := TextField.init()
	field.buf.insert_slice_at_cursor('a'.repeat(65537))
	field.draw_offset = 65535
	DrawContext.init(.unicode)
	assert field.width_to_cursor(DrawContext{
		min:       Size{}
		max:       MaxSize{}
		cell_size: Size{}
	}) == 2
}

fn test_text_field_draw_borrows_buffer_graphemes() {
	mut field := TextField.init()
	field.buf.insert_slice_at_cursor('abc')
	field.buf.move_gap_left(1)
	DrawContext.init(.unicode)
	surface := field.draw(DrawContext{
		min:       Size{}
		cell_size: Size{}
		max:       MaxSize{
			width: 8
		}
	})!
	assert surface.buffer[0].char_.grapheme.str == field.buf.buffer.data
	assert uint(surface.buffer[2].char_.grapheme.str) == uint(field.buf.buffer.data) +
		field.buf.cursor + field.buf.gap_size
	field.buf.buffer[0] = `A`
	field.buf.buffer[int(field.buf.cursor + field.buf.gap_size)] = `C`
	assert surface.buffer[0].char_.grapheme == 'A'
	assert surface.buffer[2].char_.grapheme == 'C'
}
