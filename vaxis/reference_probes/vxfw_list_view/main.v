module main

import os
import strconv
import strings
import vaxis
import vaxis.vxfw as fw

struct Item {
mut:
	owner  &Fixture = unsafe { nil }
	index  int
	height u16
}

@[heap]
struct Fixture {
mut:
	items    []Item
	list     &fw.ListView = unsafe { nil }
	holes    u64
	width    ?u16
	fail     i64 = -1
	mutation u8
	silent   bool
	trace    []string
}

fn build(ptr voidptr, index usize, cursor usize) ?fw.Widget {
	mut f := unsafe { &Fixture(ptr) }
	if !f.silent { f.trace << 'b${index},${cursor};' }
	if index >= usize(f.items.len) || (index < 64 && f.holes & (u64(1) << index) != 0) {
		return none
	}
	return item_widget(&f.items[int(index)])
}

fn item_widget(item &Item) fw.Widget {
	return fw.Widget{
		userdata: unsafe { voidptr(item) }
		draw_fn:  draw_item
	}
}

fn draw_item(ptr voidptr, ctx fw.DrawContext) !fw.Surface {
	item := unsafe { &Item(ptr) }
	mut f := item.owner
	f.trace << 'd${item.index},${ctx.min.width},${ctx.max.width or { u16(65535) }},${ctx.max.height or {
		u16(65535)
	}};'
	if item.index == 0 {
		match f.mutation {
			1 {
				f.list.scroll.pending_lines = 7
			}
			2 {
				f.list.cursor = 0
				f.list.scroll.wants_cursor = true
			}
			3 {
				f.list.scroll.top = 0xffffffff
			}
			else {}
		}
	}
	if f.fail == item.index { return error('OutOfMemory') }
	return fw.Surface{
		size:     fw.Size{
			width:  f.width or { ctx.min.width }
			height: item.height
		}
		widget:   item_widget(item)
		buffer:   []vaxis.Cell{}
		children: []fw.SubSurface{}
		cursor:   if item.index % 2 == 0 {
			fw.CursorState{
				col:   0
				row:   0
				shape: .beam
			}
		} else {
			none
		}
	}
}

fn uint(p []string, i int) u64 {
	return strconv.parse_uint(p[i], 10, 64) or { panic(err) }
}

fn sint(p []string, i int) i64 {
	return strconv.parse_int(p[i], 10, 64) or { panic(err) }
}

fn state(mut out strings.Builder, list fw.ListView, ctx fw.EventContext, f &Fixture) {
	out.write_string('${list.cursor},${list.item_count or { u32(0xffffffff) }},${list.scroll.top},${list.scroll.offset},${list.scroll.pending_lines},${int(list.scroll.has_more)},${int(list.scroll.wants_cursor)},${int(ctx.consume_event)},${int(ctx.redraw)},${ctx.cmds.len}|')
	for text in f.trace {
		out.write_string(text)
	}
}

fn surface(mut out strings.Builder, value fw.Surface, list &fw.ListView) {
	index := if value.widget.userdata == unsafe { voidptr(list) } {
		999
	} else {
		unsafe { (&Item(value.widget.userdata)).index }
	}
	mut defaults := 0
	mut indicators := 0
	for cell in value.buffer {
		if cell.default_ { defaults++ }
		if cell.char_.grapheme == '▐' { indicators++ }
	}
	out.write_string('[${value.size.width},${value.size.height},${index},${value.buffer.len},${defaults},${indicators},')
	if cursor := value.cursor {
		out.write_string('${cursor.col},${cursor.row},${u8(cursor.shape)}')
	} else {
		out.write_string('none')
	}
	out.write_string('|')
	for child in value.children {
		out.write_string('${child.origin.col},${child.origin.row},${child.z_index}')
		surface(mut out, child.surface, list)
	}
	out.write_string(']')
}

fn event(action u64) fw.Event {
	return match action {
		3, 4 {
			fw.Event(vaxis.Mouse{
				col:    0
				row:    0
				button: if action == 3 { .wheel_up } else { .wheel_down }
				mods:   vaxis.MouseModifiers{}
				type_:  .press
			})
		}
		5 {
			fw.Event(vaxis.Key{
				codepoint: u32(`j`)
			})
		}
		6 {
			fw.Event(vaxis.Key{
				codepoint: u32(`k`)
			})
		}
		7 {
			fw.Event(vaxis.Key{
				codepoint: vaxis.escape
			})
		}
		8 {
			fw.Event(vaxis.Key{
				codepoint: u32(`n`)
				mods:      vaxis.Modifiers.from_int(4)
			})
		}
		9 {
			fw.Event(vaxis.Key{
				codepoint: u32(`p`)
				mods:      vaxis.Modifiers.from_int(4)
			})
		}
		10 {
			fw.Event(vaxis.Key{
				codepoint: vaxis.down
			})
		}
		11 {
			fw.Event(vaxis.Key{
				codepoint: vaxis.up
			})
		}
		12 {
			fw.Event(vaxis.Key{
				codepoint: u32(`j`)
				mods:      vaxis.Modifiers.from_int(1)
			})
		}
		else {
			fw.Event(fw.InitEvent{})
		}
	}
}

fn record(line string, number int) {
	p := line.split('|')
	mut f := &Fixture{
		holes:    uint(p, 4)
		width:    if sint(p, 3) < 0 { none } else { u16(uint(p, 3)) }
		fail:     sint(p, 17)
		mutation: u8(uint(p, 18))
	}
	for text in p[2].split(',') {
		if text.len == 0 {
			continue
		}
		f.items << Item{
			owner:  f
			index:  f.items.len
			height: u16(strconv.atoi(text) or { panic(err) })
		}
	}
	builder := fw.ListBuilder{
		userdata: f
		build_fn: build
	}
	mut widgets := []fw.Widget{}
	for i in 0 .. f.items.len {
		widgets << item_widget(&f.items[i])
	}
	mut list := fw.ListView{
		children:     if uint(p, 1) == 0 { fw.ListSource(fw.ListSlice{
				widgets: widgets
			}) } else { fw.ListSource(builder) }
		cursor:       u32(uint(p, 5))
		item_count:   if sint(p, 6) < 0 { none } else { u32(uint(p, 6)) }
		scroll:       fw.ListScroll{
			top:           u32(uint(p, 7))
			offset:        i32(sint(p, 8))
			pending_lines: i32(sint(p, 9))
			has_more:      uint(p, 10) != 0
			wants_cursor:  uint(p, 11) != 0
		}
		draw_cursor:  uint(p, 12) != 0
		wheel_scroll: u8(uint(p, 13))
	}
	f.list = &list
	mut ctx := fw.EventContext{
		cmds:   []
		redraw: false
	}
	action := uint(p, 14)
	mut out := strings.new_builder(256)
	out.write_string('${number}|')
	if p[0] == 'E' {
		match action {
			0 {
				list.next_item(mut ctx)
			}
			1 {
				list.prev_item(mut ctx)
			}
			2 {
				list.ensure_scroll()
			}
			else {
				if action % 2 == 0 {
					list.widget().handle_event(mut ctx, event(action)) or { panic(err) }
				} else {
					list.handle_event(mut ctx, event(action)) or { panic(err) }
				}
			}
		}
	} else {
		draw_ctx := fw.DrawContext{
			min:       fw.Size{}
			max:       fw.MaxSize{
				width:  if sint(p, 15) < 0 { none } else { u16(uint(p, 15)) }
				height: if sint(p, 16) < 0 { none } else { u16(uint(p, 16)) }
			}
			cell_size: fw.Size{}
		}
		if action == 0 {
			if value := list.draw(draw_ctx) {
				surface(mut out, value, &list)
				out.write_string('|')
			} else {
				out.write_string('error:${err.msg()}|')
			}
		} else {
			if value := list.widget().draw(draw_ctx) {
				surface(mut out, value, &list)
				out.write_string('|')
			} else {
				out.write_string('error:${err.msg()}|')
			}
		}
	}
	state(mut out, list, ctx, f)
	println(out.str())
}

fn main() {
	if os.args[1].starts_with('hang_') {
		mut f := &Fixture{
			silent: true
		}
		mut list := fw.ListView{
			children: fw.ListBuilder{
				userdata: f
				build_fn: build
			}
			cursor:   if os.args[1] == 'hang_prev' { u32(1) } else { u32(0) }
		}
		f.list = &list
		mut ctx := fw.EventContext{
			cmds: []
		}
		if list.cursor == 1 {
			list.prev_item(mut ctx)
		} else {
			list.next_item(mut ctx)
		}
		println('UNEXPECTED')
		return
	}
	data := os.read_file(os.args[1]) or { panic(err) }
	mut number := 0
	for line in data.split_into_lines() {
		if line.len == 0 { continue
		 }
		record(line, number)
		number++
	}
}
