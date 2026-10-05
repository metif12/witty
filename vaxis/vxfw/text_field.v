module vxfw

import math
import vaxis

pub type TextFieldHandler = fn (voidptr, mut EventContext, string) !

pub struct TextField {
pub mut:
	style           vaxis.Style
	userdata        voidptr
	on_change       ?TextFieldHandler
	on_submit       ?TextFieldHandler
	buf             vaxis.TextInputBuffer @[required]
	draw_offset     u16
	prev_cursor_col u16
	prev_cursor_idx u16
	scroll_offset   u8 = 4
	prev_width      u16
	previous_val    string
}

pub fn TextField.init() TextField {
	return TextField{
		buf: vaxis.TextInputBuffer.new()
	}
}

pub fn (mut field TextField) deinit() {
	field.previous_val = ''
	field.buf.deinit()
}

pub fn (field &TextField) widget() Widget {
	return Widget{
		userdata:      unsafe { voidptr(field) }
		event_handler: text_field_event
		draw_fn:       text_field_draw
	}
}

fn text_field_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut field := unsafe { &TextField(ptr) }
	field.handle_event(mut ctx, event)!
}

pub fn (mut field TextField) handle_event(mut ctx EventContext, event Event) ! {
	match event {
		vaxis.FocusIn, vaxis.FocusOut {
			ctx.redraw = true
		}
		vaxis.Key {
			ctrl := vaxis.Modifiers.from_int(4)
			alt := vaxis.Modifiers.from_int(2)
			if event.matches(vaxis.backspace, vaxis.Modifiers{}) {
				field.delete_before_cursor()
				field.check_changed(mut ctx)!
			} else if event.matches(vaxis.delete, vaxis.Modifiers{})
				|| event.matches(u32(`d`), ctrl) {
				field.delete_after_cursor()
				field.check_changed(mut ctx)!
			} else if event.matches(vaxis.left, vaxis.Modifiers{}) || event.matches(u32(`b`), ctrl) {
				field.cursor_left()
				ctx.consume_and_redraw()
			} else if event.matches(vaxis.right, vaxis.Modifiers{}) || event.matches(u32(`f`), ctrl) {
				field.cursor_right()
				ctx.consume_and_redraw()
			} else if event.matches(u32(`a`), ctrl) || event.matches(vaxis.home, vaxis.Modifiers{}) {
				field.buf.move_gap_left(usize(field.buf.first_half().len))
				ctx.consume_and_redraw()
			} else if event.matches(u32(`e`), ctrl) || event.matches(vaxis.end, vaxis.Modifiers{}) {
				field.buf.move_gap_right(usize(field.buf.second_half().len))
				ctx.consume_and_redraw()
			} else if event.matches(u32(`k`), ctrl) {
				field.delete_to_end()
				field.check_changed(mut ctx)!
			} else if event.matches(u32(`u`), ctrl) {
				field.delete_to_start()
				field.check_changed(mut ctx)!
			} else if event.matches(u32(`b`), alt) || event.matches(vaxis.left, alt) {
				field.move_backward_wordwise()
				ctx.consume_and_redraw()
			} else if event.matches(u32(`f`), alt) || event.matches(vaxis.right, alt) {
				field.move_forward_wordwise()
				ctx.consume_and_redraw()
			} else if event.matches(u32(`w`), ctrl) || event.matches(vaxis.backspace, alt) {
				field.delete_word_before()
				field.check_changed(mut ctx)!
			} else if event.matches(u32(`d`), alt) {
				field.delete_word_after()
				field.check_changed(mut ctx)!
			} else if event.matches(vaxis.enter, vaxis.Modifiers{}) || event.matches(u32(`j`), ctrl) {
				if submit := field.on_submit {
					value := field.to_owned_slice()
					submit(field.userdata, mut ctx, value)!
					ctx.consume_and_redraw()
				}
			} else if text := event.text {
				field.insert_slice_at_cursor(text)
				field.check_changed(mut ctx)!
			}
		}
		else {}
	}
}

fn (mut field TextField) check_changed(mut ctx EventContext) ! {
	ctx.consume_and_redraw()
	change := field.on_change or { return }
	value := field.buf.string()
	defer { field.previous_val = value }
	if value == field.previous_val { return }
	change(field.userdata, mut ctx, value)!
}

pub fn (mut field TextField) insert_slice_at_cursor(text string) {
	mut iter := GraphemeIterator{
		text: text
	}
	for {
		grapheme := iter.next() or { break }
		field.buf.insert_slice_at_cursor(grapheme)
	}
}

pub fn (field &TextField) slice_to_cursor(mut bytes []u8) []u8 {
	if usize(bytes.len) < field.buf.cursor { panic('Assertion failed') }
	first := field.buf.first_half()
	span := usize(first.len)
	source_address := usize(first.data)
	destination_address := usize(bytes.data)
	if span > 0 && source_address < destination_address + span
		&& destination_address < source_address + span {
		panic('@memcpy arguments alias')
	}
	copy(mut bytes[..first.len], first)
	return unsafe { bytes[..first.len] }
}

fn text_field_checked_u16_add(value u16, extra int) u16 {
	if extra > 0xffff - int(value) { panic('integer overflow') }
	return value + u16(extra)
}

fn text_field_checked_u8(value usize) u8 {
	if value > 0xff { panic('integer does not fit in destination type') }
	return u8(value)
}

pub fn (field &TextField) width_to_cursor(ctx DrawContext) u16 {
	mut width := u16(0)
	mut iter := GraphemeIterator{
		text: field.buf.first_half().bytestr()
	}
	mut i := usize(0)
	for {
		grapheme := iter.next() or { break }
		if i >= field.draw_offset {
			width = text_field_checked_u16_add(width, int(ctx.string_width(grapheme)))
		}
		i++
	}
	return width
}

pub fn (mut field TextField) cursor_left() {
	field.buf.move_gap_left(usize(field.last_grapheme_length()))
}

pub fn (mut field TextField) cursor_right() {
	field.buf.move_gap_right(usize(vaxis.first_grapheme_byte_length(field.buf.second_half().bytestr())))
}

fn (field &TextField) last_grapheme_length() int {
	mut iter := GraphemeIterator{
		text: field.buf.first_half().bytestr()
	}
	mut length := 0
	for {
		grapheme := iter.next() or { break }
		length = grapheme.len
	}
	return length
}

pub fn (field &TextField) graphemes_before_cursor() u16 {
	mut iter := GraphemeIterator{
		text: field.buf.first_half().bytestr()
	}
	mut count := u16(0)
	for {
		_ := iter.next() or { break }
		count = text_field_checked_u16_add(count, 1)
	}
	return count
}

fn text_field_draw(ptr voidptr, ctx DrawContext) !Surface {
	mut field := unsafe { &TextField(ptr) }
	return field.draw(ctx)
}

pub fn (mut field TextField) draw(ctx DrawContext) !Surface {
	width := ctx.max.width or { panic('TextField requires bounded width') }
	if width != field.prev_width {
		field.prev_width = width
		field.draw_offset = 0
		field.prev_cursor_col = 0
	}
	height := math.max(ctx.min.height, u16(1))
	mut surface := Surface.init(field.widget(), Size{
		width:  width
		height: height
	})
	for i in 0 .. surface.buffer.len {
		surface.buffer[i] = vaxis.Cell{
			style: field.style
		}
	}
	cursor_idx := field.graphemes_before_cursor()
	if cursor_idx < field.draw_offset { field.draw_offset = cursor_idx }
	if width == 0 { return surface }
	for {
		cursor_width := field.width_to_cursor(ctx)
		if cursor_width < width { break
		 }
		field.draw_offset = u16(math.min(u32(field.draw_offset) + cursor_width - width + 1,
			u32(0xffff)))
	}
	field.prev_cursor_idx = cursor_idx
	field.prev_cursor_col = 0
	mut col := u16(0)
	mut index := u16(0)
	for half_index, half in [field.buf.first_half(), field.buf.second_half()] {
		mut iter := GraphemeIterator{
			text: if half.len == 0 { '' } else { unsafe { tos(half.data, half.len) } }
		}
		for {
			grapheme := iter.next() or { break }
			if index < field.draw_offset {
				index = text_field_checked_u16_add(index, 1)
				continue
			}
			w := text_field_checked_u8(ctx.string_width(grapheme))
			next_col := text_field_checked_u16_add(col, int(w))
			if (half_index == 0 && next_col >= width) || (half_index == 1 && next_col > width) {
				surface.write_cell(width - 1, 0, vaxis.Cell{
					char_: vaxis.CellCharacter{
						grapheme: '…'
						width:    1
					}
					style: field.style
				})
				break
			}
			surface.write_cell(col, 0, vaxis.Cell{
				char_: vaxis.CellCharacter{
					grapheme: grapheme
					width:    w
				}
				style: field.style
			})
			col = next_col
			index = text_field_checked_u16_add(index, 1)
			if index == cursor_idx { field.prev_cursor_col = col }
		}
	}
	if field.draw_offset > 0 { surface.write_cell(0, 0, vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: '…'
				width:    1
			}
			style: field.style
		}) }
	surface.cursor = CursorState{
		col: field.prev_cursor_col
	}
	return surface
}

pub fn (mut field TextField) clear_and_free() {
	field.buf.clear_and_free()
	field.reset()
}

pub fn (mut field TextField) clear_retaining_capacity() {
	field.buf.clear_retaining_capacity()
	field.reset()
}

pub fn (mut field TextField) to_owned_slice() string {
	defer { field.reset() }
	return field.buf.to_owned_slice()
}

pub fn (mut field TextField) reset() {
	field.draw_offset = 0
	field.prev_cursor_col = 0
	field.prev_cursor_idx = 0
}

pub fn (field &TextField) byte_offset_to_cursor() usize {
	return field.buf.cursor
}

pub fn (mut field TextField) delete_to_end() {
	field.buf.grow_gap_right(usize(field.buf.second_half().len))
}

pub fn (mut field TextField) delete_to_start() {
	field.buf.grow_gap_left(field.buf.cursor)
}

pub fn (mut field TextField) delete_before_cursor() {
	field.buf.grow_gap_left(usize(field.last_grapheme_length()))
}

pub fn (mut field TextField) delete_after_cursor() {
	field.buf.grow_gap_right(usize(vaxis.first_grapheme_byte_length(field.buf.second_half().bytestr())))
}

pub fn (mut field TextField) move_backward_wordwise() {
	trimmed := field.buf.first_half().bytestr().trim_right(' ')
	idx := trimmed.last_index(' ') or { -1 }
	field.buf.move_gap_left(field.buf.cursor - usize(idx + 1))
}

fn (field &TextField) next_word_index() usize {
	bytes := field.buf.second_half()
	mut idx := 0
	for idx < bytes.len && bytes[idx] == ` ` {
		idx++
	}
	for idx < bytes.len && bytes[idx] != ` ` {
		idx++
	}
	return usize(idx)
}

pub fn (mut field TextField) move_forward_wordwise() {
	field.buf.move_gap_right(field.next_word_index())
}

pub fn (mut field TextField) delete_word_before() {
	prev := field.buf.cursor
	field.move_backward_wordwise()
	field.buf.grow_gap_right(prev - field.buf.cursor)
}

pub fn (mut field TextField) delete_word_after() {
	field.buf.grow_gap_right(field.next_word_index())
}
