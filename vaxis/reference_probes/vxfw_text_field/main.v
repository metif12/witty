module main

import os
import encoding.hex
import strconv
import strings
import vaxis
import vaxis.vxfw

fn uint(parts []string, index int) uint {
	return uint(strconv.parse_uint(parts[index], 10, 64) or { panic(err) })
}

fn bytes(value string) string {
	return (hex.decode(value) or { panic(err) }).bytestr()
}

fn style(index uint) vaxis.Style {
	return match index {
		1 {
			vaxis.Style{
				fg:            vaxis.ColorIndex{
					index: 3
				}
				bg:            vaxis.ColorIndex{
					index: 4
				}
				ul:            vaxis.ColorIndex{
					index: 5
				}
				ul_style:      .curly
				bold:          true
				dim:           true
				italic:        true
				blink:         true
				reverse:       true
				invisible:     true
				strikethrough: true
			}
		}
		2 {
			vaxis.Style{
				fg:       vaxis.ColorRgb{
					rgb: [u8(1), 2, 3]!
				}
				bg:       vaxis.ColorRgb{
					rgb: [u8(5), 8, 13]!
				}
				ul:       vaxis.ColorRgb{
					rgb: [u8(21), 34, 55]!
				}
				ul_style: .dashed
				italic:   true
			}
		}
		3 {
			vaxis.Style{
				ul_style: .double_
				bold:     true
			}
		}
		else {
			vaxis.Style{}
		}
	}
}

fn color(value vaxis.Color) u32 {
	return match value {
		vaxis.ColorDefault { u32(0) }
		vaxis.ColorIndex { u32(0x1000000) | u32(value.index) }
		vaxis.ColorRgb { u32(0x2000000) | (u32(value.rgb[0]) << 16) | (u32(value.rgb[1]) << 8) | u32(value.rgb[2]) }
	}
}

fn cell(mut output strings.Builder, value vaxis.Cell) {
	flags := u8(value.style.bold) | (u8(value.style.dim) << 1) | (u8(value.style.italic) << 2) | (u8(value.style.blink) << 3) | (u8(value.style.reverse) << 4) | (u8(value.style.invisible) << 5) | (u8(value.style.strikethrough) << 6)
	output.write_string('${hex.encode(value.char_.grapheme.bytes())}/${value.char_.width}/${color(value.style.fg)}/${color(value.style.bg)}/${color(value.style.ul)}/${u8(value.style.ul_style)}/${flags}/${u8(value.default_)}/${u8(value.wrapped)}/${value.link.uri}/${value.link.params};')
	output.write_string('${value.scale.scale()},${value.scale.numerator()},${value.scale.denominator()},${u8(value.scale.vertical_alignment())},')
	if img := value.image {
		output.write_string('${img.img_id};')
	} else {
		output.write_string('none;')
	}
}

fn state(mut output strings.Builder, input vxfw.TextField) {
	b := input.buf
	output.write_string('${b.buffer.len},${u64(b.cursor).str()},${u64(b.gap_size).str()};')
	if b.cursor <= uint(b.buffer.len) && b.gap_size <= uint(b.buffer.len) - b.cursor {
		output.write_string('${hex.encode(b.first_half())}/${hex.encode(b.second_half())}')
	} else { output.write_string('invalid') }
	output.write_string(';${input.draw_offset},${input.prev_cursor_col},${input.prev_cursor_idx},${input.scroll_offset},${input.prev_width};${hex.encode(input.previous_val.bytes())};')
}

fn context(width ?u16, height u16) vxfw.DrawContext {
	return vxfw.DrawContext{min: vxfw.Size{height: height}, max: vxfw.MaxSize{width: width}, cell_size: vxfw.Size{width: 10, height: 20}}
}

struct Observation {
	kind u8
	value string
	current string
	previous string
	cursor uint
	gap uint
	offset u16
	col u16
	index u16
	consumed bool
	redraw bool
}

struct Spy {
mut:
	field &vxfw.TextField = unsafe { nil }
	mode uint
	observations []Observation
}

fn (mut spy Spy) observe(mut ctx vxfw.EventContext, value string, kind u8) ! {
	spy.observations << Observation{kind: kind, value: value.clone(), current: spy.field.buf.string(), previous: spy.field.previous_val.clone(), cursor: spy.field.buf.cursor, gap: spy.field.buf.gap_size, offset: spy.field.draw_offset, col: spy.field.prev_cursor_col, index: spy.field.prev_cursor_idx, consumed: ctx.consume_event, redraw: ctx.redraw}
	if spy.mode == 7 || spy.mode == 9 {
		spy.field.insert_slice_at_cursor('!')
		ctx.consume_event = false
		ctx.redraw = false
	} else if spy.mode == 8 {
		spy.field.clear_retaining_capacity()
		ctx.quit = true
	}
	if spy.mode == 6 || spy.mode == 9 || (kind == `C` && spy.mode == 4) || (kind == `S` && spy.mode == 5) {
		return error('CallbackFailure')
	}
}

fn change(ptr voidptr, mut ctx vxfw.EventContext, value string) ! {
	mut spy := unsafe { &Spy(ptr) }
	spy.observe(mut ctx, value, `C`)!
}

fn submit(ptr voidptr, mut ctx vxfw.EventContext, value string) ! {
	mut spy := unsafe { &Spy(ptr) }
	spy.observe(mut ctx, value, `S`)!
}

fn trap(mode string) {
	mut input := vxfw.TextField.init()
	vxfw.DrawContext.init(.unicode)
	if mode in ['trap_count', 'trap_second_count'] {
		input.buf.insert_slice_at_cursor(if mode == 'trap_second_count' { '\x00'.repeat(65536) } else { 'a'.repeat(65536) })
		if mode == 'trap_count' { input.graphemes_before_cursor() } else {
			input.buf.move_gap_left(65536)
			input.draw(context(u16(1), 1)) or { panic(err) }
		}
	} else if mode == 'trap_width' {
		input.buf.insert_slice_at_cursor('界'.repeat(32768))
		input.width_to_cursor(context(u16(1), 1))
	} else if mode == 'trap_grapheme_width' {
		input.buf.insert_slice_at_cursor('👍' + '🏽'.repeat(128))
		input.buf.move_gap_left(uint(input.buf.cursor))
		vxfw.DrawContext.init(.wcwidth)
		input.draw(context(u16(512), 1)) or { panic(err) }
	} else if mode == 'trap_surface_size' {
		input.draw(context(u16(32768), 2)) or { panic(err) }
	} else if mode == 'trap_unbounded' {
		input.draw(context(none, 1)) or { panic(err) }
	} else if mode.starts_with('trap_utf8_') {
		input.buf.insert_slice_at_cursor(bytes('ffcc81'))
		match mode {
			'trap_utf8_left' { input.cursor_left() }
			'trap_utf8_delete' { input.delete_before_cursor() }
			'trap_utf8_count' { input.graphemes_before_cursor() }
			'trap_utf8_width' { input.width_to_cursor(context(u16(1), 1)) }
			'trap_utf8_right' { input.buf.move_gap_left(3); input.cursor_right() }
			'trap_utf8_after' { input.buf.move_gap_left(3); input.delete_after_cursor() }
			'trap_utf8_draw' { input.draw(context(u16(1), 1)) or { panic(err) } }
			else {}
		}
	} else if mode == 'trap_unicode' {
		input.insert_slice_at_cursor(bytes('ffcc81'))
	} else if mode == 'trap_slice_short' {
		input.buf.insert_slice_at_cursor('abc')
		mut output := []u8{len: 2}
		input.slice_to_cursor(mut output)
	} else if mode == 'trap_slice_alias' {
		input.buf.insert_slice_at_cursor('abc')
		mut output := unsafe { input.buf.buffer }
		input.slice_to_cursor(mut output)
	}
	eprintln('UNEXPECTED: returned')
}

fn main() {
	if os.args[1].starts_with('trap_') { trap(os.args[1]); return }
	codes := [vaxis.backspace, vaxis.delete, vaxis.left, vaxis.right, vaxis.home, vaxis.end, u32(`a`), u32(`b`), u32(`d`), u32(`e`), u32(`f`), u32(`k`), u32(`u`), u32(`w`), u32(`x`), vaxis.enter, u32(`j`)]
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		if line.len == 0 { continue }
		parts := line.split('|')
		mut input := vxfw.TextField.init()
		text := bytes(parts[1])
		mut output := strings.new_builder(256)
		match parts[0] {
			'I' { for _ in 0 .. int(uint(parts, 2)) { input.insert_slice_at_cursor(text) } }
			'S' {
				input.buf.insert_slice_at_cursor(text)
				input.buf.move_gap_left(uint(parts, 2))
				mut destination := []u8{len: int(input.buf.cursor + uint(parts, 3)), init: 0xa5}
				prefix := input.slice_to_cursor(mut destination)
				if prefix.len > 0 { destination[0] ^= 0xff }
				output.write_string('${u8(prefix.data == destination.data)};${hex.encode(prefix)};${hex.encode(destination)};')
			}
			'M', 'D', 'P' {
				input.buf.insert_slice_at_cursor(text)
				input.buf.move_gap_left(uint(parts, 2))
				action := uint(parts, 3)
				vxfw.DrawContext.init(unsafe { vaxis.GWidthMethod(uint(parts, 4)) })
				input.draw_offset = u16(uint(parts, 5))
				input.prev_cursor_col = 19; input.prev_cursor_idx = 23
				input.prev_width = u16(uint(parts, 6)); input.scroll_offset = u8(uint(parts, 7))
				if parts[0] == 'M' {
					match action {
						0 { input.cursor_left() } 1 { input.cursor_right() }
						2 { input.delete_before_cursor() } 3 { input.delete_after_cursor() }
						4 { input.delete_to_start() } 5 { input.delete_to_end() }
						6 { input.move_backward_wordwise() } 7 { input.move_forward_wordwise() }
						8 { input.delete_word_before() } 9 { input.delete_word_after() }
						10 { input.clear_and_free() } 11 { input.clear_retaining_capacity() }
						12 { output.write_string('${hex.encode(input.to_owned_slice().bytes())};') }
						13 { output.write_string('${input.graphemes_before_cursor()};') }
						14 { output.write_string('${input.width_to_cursor(context(u16(16), 1))};') }
						else { input.reset() }
					}
				} else {
					input.style = style(uint(parts, 9))
					surface := input.widget().draw(context(u16(action), u16(uint(parts, 8)))) or { panic(err) }
					output.write_string('${surface.size.width},${surface.size.height};')
					if cursor := surface.cursor { output.write_string('${cursor.col},${cursor.row},${u8(cursor.shape)};') } else { output.write_string('none;') }
					if parts[0] == 'P' {
						base := uint(input.buf.buffer.data)
						limit := base + uint(input.buf.buffer.len)
						for value in surface.buffer {
							address := uint(value.char_.grapheme.str)
							if value.char_.grapheme.len == 0 { output.write_string('empty,') }
							else if address >= base && address <= limit && uint(value.char_.grapheme.len) <= limit - address { output.write_string('${address - base},') }
							else { output.write_string('external,') }
						}
						output.write_string(';')
						if input.buf.first_half().len > 0 { input.buf.buffer[0] ^= 0x20 }
						if input.buf.second_half().len > 0 { input.buf.buffer[int(input.buf.cursor + input.buf.gap_size)] ^= 0x20 }
					}
					for value in surface.buffer { cell(mut output, value) }
				}
			}
			'E' {
				input.buf.insert_slice_at_cursor(text)
				input.buf.move_gap_left(uint(parts, 2))
				input.draw_offset = 7; input.prev_cursor_col = 11; input.prev_cursor_idx = 13; input.prev_width = 17
				input.previous_val = bytes(parts[8])
				mut spy := Spy{field: &input, mode: uint(parts, 7)}
				input.userdata = &spy
				if spy.mode in [uint(1), 3, 4, 6, 7, 8, 9] { input.on_change = change }
				if spy.mode in [uint(2), 3, 5, 6, 7, 8, 9] { input.on_submit = submit }
				flags := uint(parts, 9)
				mut ctx := vxfw.EventContext{
cmds: []vxfw.Command{}
redraw: flags & 1 != 0, consume_event: flags & 2 != 0, quit: flags & 4 != 0}
				keytext := if parts[5] == 'none' { ?string(none) } else { ?string(bytes(parts[5])) }
				key := vaxis.Key{codepoint: codes[int(uint(parts, 3))], mods: vaxis.Modifiers.from_int(u8(uint(parts, 4))), text: keytext}
				event := match uint(parts, 6) {
					1 { vxfw.Event(vaxis.FocusIn{}) } 2 { vxfw.Event(vaxis.FocusOut{}) }
					3 { vxfw.Event(vaxis.KeyRelease{key: key}) } 4 { vxfw.Event(vxfw.InitEvent{}) }
					else { vxfw.Event(key) }
				}
				mut failure := 'none'
				input.widget().handle_event(mut ctx, event) or { failure = err.msg() }
				output.write_string('${failure},${u8(ctx.consume_event)},${u8(ctx.redraw)},${u8(ctx.quit)};')
				for record in spy.observations {
					output.write_string('${record.kind.ascii_str()}:${hex.encode(record.value.bytes())}/${hex.encode(record.current.bytes())}/${hex.encode(record.previous.bytes())}/${record.cursor},${record.gap},${record.offset},${record.col},${record.index},${u8(record.consumed)},${u8(record.redraw)};')
				}
			}
			else { panic('InvalidMode') }
		}
		state(mut output, input)
		println(output.str())
	}
}
