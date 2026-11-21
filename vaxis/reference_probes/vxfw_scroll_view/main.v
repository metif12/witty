module main

import os
import strconv
import strings
import encoding.hex
import vaxis
import vaxis.vxfw

fn specs(index u8) []vxfw.Size {
	return match index {
		0 {
			[]vxfw.Size{}
		}
		1 {
			[vxfw.Size{ width: 1, height: 1 }]
		}
		2 {
			[vxfw.Size{ width: 5, height: 3 }, vxfw.Size{ width: 3, height: 1 },
				vxfw.Size{ width: 7, height: 1 }, vxfw.Size{ width: 4, height: 2 }]
		}
		3 {
			[vxfw.Size{ width: 0, height: 0 }, vxfw.Size{ width: 2, height: 0 },
				vxfw.Size{ width: 5, height: 0 }]
		}
		4 {
			[vxfw.Size{ width: 1, height: 5 }, vxfw.Size{ width: 3, height: 2 },
				vxfw.Size{ width: 10, height: 7 }, vxfw.Size{ width: 20, height: 1 },
				vxfw.Size{ width: 4, height: 3 }]
		}
		5 {
			[vxfw.Size{ width: 0, height: 255 }, vxfw.Size{ width: 0, height: 256 },
				vxfw.Size{ width: 0, height: 1000 }]
		}
		6 {
			[vxfw.Size{ width: 65535, height: 65535 }]
		}
		7 {
			[vxfw.Size{ width: 0, height: 65535 }, vxfw.Size{ width: 0, height: 65535 }]
		}
		8 {
			[vxfw.Size{ width: 1, height: 1 }, vxfw.Size{ width: 1, height: 1 },
				vxfw.Size{ width: 1, height: 1 }]
		}
		else {
			panic('invalid fixture dataset')
		}
	}
}

struct Child {
	spy   &Spy
	index uint
mut:
	size vxfw.Size
}

fn (child &Child) widget() vxfw.Widget {
	return vxfw.Widget{
		userdata: unsafe { voidptr(child) }
		draw_fn:  child_draw
	}
}

fn child_draw(ptr voidptr, ctx vxfw.DrawContext) !vxfw.Surface {
	mut child := unsafe { &Child(ptr) }
	mut spy := child.spy
	spy.log('D', child.index, 0, ctx)
	first := spy.draw_calls == 0
	spy.draw_calls++
	if first {
		match spy.draw_mode {
			1 {
				return error('OutOfMemory')
			}
			2 {
				spy.view.scroll.pending_lines = -2
				spy.view.scroll.left = 1
				spy.view.scroll.vertical_offset = 2
			}
			3 {
				spy.view.scroll.top = 0
				spy.view.scroll.wants_cursor = false
			}
			4 {
				spy.view.scroll.left = 65536
				return error('OutOfMemory')
			}
			5 {
				if child.index + 1 < uint(spy.children.len) {
					spy.children[int(child.index + 1)].size.height = 4
				}
			}
			else {}
		}
	}
	return vxfw.Surface{
		size:     child.size
		widget:   child.widget()
		buffer:   []
		children: []
	}
}

struct Spy {
mut:
	view        &vxfw.ScrollView = unsafe { nil }
	children    []Child
	widgets     []vxfw.Widget
	build_mode  u8
	draw_mode   u8
	build_calls uint
	draw_calls  uint
	base        uint
	trace       []string
}

fn (mut spy Spy) init(dataset u8) {
	for index, size in specs(dataset) {
		spy.children << Child{
			spy:   unsafe { &spy }
			index: uint(index)
			size:  size
		}
	}
	for index in 0 .. spy.children.len {
		spy.widgets << spy.children[index].widget()
	}
}

fn optional(value ?u16) i32 {
	return if n := value { i32(n) } else { -1 }
}

fn (mut spy Spy) log(kind string, index uint, cursor uint, ctx ?vxfw.DrawContext) {
	if spy.build_calls + spy.draw_calls > 128 { return }
	v := spy.view
	min_w := if c := ctx { i32(c.min.width) } else { -1 }
	min_h := if c := ctx { i32(c.min.height) } else { -1 }
	max_w := if c := ctx { optional(c.max.width) } else { -1 }
	max_h := if c := ctx { optional(c.max.height) } else { -1 }
	spy.trace << '${kind}${index},${cursor},${v.cursor},${v.scroll.top},${v.scroll.vertical_offset},${v.scroll.pending_lines},${v.scroll.left},${u8(v.scroll.wants_cursor)},${u8(v.scroll.has_more_vertical)},${min_w},${min_h},${max_w},${max_h};'
}

fn build(ptr voidptr, index uint, cursor uint) ?vxfw.Widget {
	mut spy := unsafe { &Spy(ptr) }
	spy.log('B', index, cursor, none)
	first := spy.build_calls == 0
	spy.build_calls++
	if first {
		match spy.build_mode {
			2 {
				spy.view.scroll.pending_lines = 2
				spy.view.scroll.left = 1
			}
			3 {
				spy.view.cursor = 0
				spy.view.scroll.wants_cursor = false
			}
			5 {
				spy.view.children = vxfw.ScrollSlice{
					widgets: []
				}
			}
			else {}
		}
	}
	relative := if spy.build_mode == 6 { index - spy.base } else { index }
	if relative >= uint(spy.widgets.len) {
		if spy.build_mode == 4 {
			spy.view.scroll.pending_lines = 1
			spy.view.scroll.left = 65536
		}
		return none
	}
	if spy.build_mode == 1 && relative % 2 != 0 { return none }
	return spy.widgets[int(relative)]
}

fn state(mut out strings.Builder, view vxfw.ScrollView) {
	count := if n := view.item_count { i64(n) } else { -1 }
	kind := if view.children is vxfw.ScrollSlice { 0 } else { 1 }
	out.write_string('${view.cursor},${view.last_height},${view.scroll.top},${view.scroll.vertical_offset},${view.scroll.pending_lines},${view.scroll.left},${u8(view.scroll.has_more_vertical)},${u8(view.scroll.has_more_horizontal)},${u8(view.scroll.wants_cursor)},${count},${u8(view.draw_cursor)},${view.wheel_scroll},${kind};')
}

fn surface_value(mut out strings.Builder, surface vxfw.Surface, view &vxfw.ScrollView) {
	index := if surface.widget.userdata == unsafe { voidptr(view) } {
		uint(0)
	} else {
		child := unsafe { &Child(surface.widget.userdata) }
		child.index + 1
	}
	out.write_string('[${surface.size.width},${surface.size.height},${index},${surface.buffer.len},${surface.children.len};')
	for cell in surface.buffer {
		fg := match cell.style.fg {
			vaxis.ColorIndex { u16(cell.style.fg.index) + 1 }
			else { u16(0) }
		}

		out.write_string('${hex.encode(cell.char_.grapheme.bytes())}/${cell.char_.width},${u8(cell.default_)},${fg},${u8(cell.style.bold)};')
	}
	for sub in surface.children {
		out.write_string('(${sub.origin.col},${sub.origin.row},${sub.z_index})')
		surface_value(mut out, sub.surface, view)
	}
	out.write_string(']')
}

fn n(p []string, index int) i64 {
	return strconv.parse_int(p[index], 10, 64) or { panic(err) }
}

fn key_event(code u8) vxfw.Event {
	cp := match code {
		0, 20 { vaxis.down }
		1 { vaxis.up }
		2 { vaxis.right }
		3 { vaxis.left }
		4 { u32(`d`) }
		5 { u32(`u`) }
		6 { vaxis.escape }
		7 { u32(`j`) }
		8 { u32(`k`) }
		9 { u32(`n`) }
		10 { u32(`p`) }
		11 { u32(`l`) }
		12 { u32(`h`) }
		13 { u32(`f`) }
		14 { u32(`b`) }
		else { u32(`q`) }
	}

	key := vaxis.Key{
		codepoint: cp
		mods:      vaxis.Modifiers.from_int(if code in [u8(4), 5, 9, 10, 13, 14] {
			u8(4)
		} else {
			u8(0)
		})
	}
	if code == 20 { return vxfw.Event(vaxis.KeyRelease{
			key: key
		}) }
	if code >= 21 && code <= 24 {
		return vxfw.Event(vaxis.Mouse{
			col:    0
			row:    0
			type_:  .release
			button: match code {
				21 { vaxis.MouseButton.wheel_up }
				22 { vaxis.MouseButton.wheel_down }
				23 { vaxis.MouseButton.wheel_left }
				else { vaxis.MouseButton.wheel_right }
			}
		})
	}
	if code == 25 { return vxfw.Event(vaxis.FocusIn{}) }
	if code == 26 { return vxfw.Event(vxfw.TickEvent{}) }
	if code == 27 { return vxfw.Event(vaxis.Paste{
			text: 'j'
		}) }
	return vxfw.Event(key)
}

fn record(mut out strings.Builder, p []string) {
	mut spy := Spy{
		build_mode: u8(n(p, 16))
		draw_mode:  u8(n(p, 17))
	}
	spy.init(u8(n(p, 3)))
	source := if n(p, 2) == 0 { vxfw.ScrollSource(vxfw.ScrollSlice{
			widgets: spy.widgets
		}) } else { vxfw.ScrollSource(vxfw.ScrollBuilder{
			userdata: &spy
			build_fn: build
		}) }
	mut view := vxfw.ScrollView{
		children:         source
		cursor:           u32(n(p, 4))
		scroll:           vxfw.ViewScroll{
			top:                 u32(n(p, 5))
			vertical_offset:     i32(n(p, 6))
			pending_lines:       i32(n(p, 7))
			left:                u32(n(p, 8))
			has_more_vertical:   n(p, 9) != 0
			has_more_horizontal: n(p, 10) != 0
			wants_cursor:        n(p, 11) != 0
		}
		item_count:       if n(p, 12) < 0 { none } else { ?u32(u32(n(p, 12))) }
		draw_cursor:      n(p, 13) != 0
		wheel_scroll:     u8(n(p, 14))
		last_height:      u8(n(p, 15))
		cursor_indicator: vaxis.Cell{
			char_: vaxis.CellCharacter{
				grapheme: '*'
				width:    1
			}
			style: vaxis.Style{
				fg:   vaxis.ColorIndex{
					index: 3
				}
				bold: true
			}
		}
	}
	spy.view = &view
	spy.base = view.scroll.top
	flags := n(p, 18)
	mut events := vxfw.EventContext{
		cmds:          []
		consume_event: flags & 1 != 0
		redraw:        flags & 2 != 0
		quit:          flags & 4 != 0
	}
	mut surface := ?vxfw.Surface(none)
	mut status := 'ok'
	action := n(p, 1)
	if p[0] == 'S' {
		amount := u8(n(p, 19))
		result := match action {
			0 { view.scroll.lines_down(amount) }
			1 { view.scroll.lines_up(amount) }
			2 { view.scroll.cols_left(amount) }
			3 { view.scroll.cols_right(amount) }
			else { panic('invalid fixture action') }
		}

		status = if result { 'true' } else { 'false' }
	} else if p[0] == 'N' {
		match action {
			0 {
				view.next_item(mut events)
			}
			1 {
				view.prev_item(mut events)
			}
			2 {
				view.ensure_scroll()
			}
			3 {
				builder := vxfw.ScrollBuilder{
					userdata: &spy
					build_fn: build
				}
				status = if builder.item_at_idx(view.cursor, view.cursor) != none {
					'true'
				} else {
					'false'
				}
			}
			else {
				panic('invalid fixture action')
			}
		}
	} else if p[0] == 'E' {
		view.widget().handle_event(mut events, key_event(u8(action))) or { panic(err) }
	} else {
		ctx := vxfw.DrawContext{
			min:       vxfw.Size{}
			max:       vxfw.MaxSize{
				width:  if n(p, 19) < 0 { none } else { ?u16(u16(n(p, 19))) }
				height: if n(p, 20) < 0 { none } else { ?u16(u16(n(p, 20))) }
			}
			cell_size: vxfw.Size{
				width:  10
				height: 20
			}
		}
		if got := view.widget().draw(ctx) {
			surface = got
		} else {
			status = err.msg()
		}
		if p[0] == 'T' && status == 'ok' {
			match action {
				0 { view.next_item(mut events) }
				1 { view.prev_item(mut events) }
				2 { view.widget().handle_event(mut events, key_event(0)) or { panic(err) } }
				3 { view.ensure_scroll() }
				4 { view.widget().handle_event(mut events, key_event(22)) or { panic(err) } }
				5 { view.widget().handle_event(mut events, key_event(2)) or { panic(err) } }
				6 { view.widget().handle_event(mut events, key_event(4)) or { panic(err) } }
				7 { view.widget().handle_event(mut events, key_event(6)) or { panic(err) } }
				else { panic('invalid fixture sequence') }
			}

			if got := view.widget().draw(ctx) {
				surface = got
			} else {
				status = err.msg()
			}
		}
	}
	out.write_string('${status}|')
	state(mut out, view)
	out.write_string('${u8(events.consume_event)},${u8(events.redraw)},${u8(events.quit)},${events.cmds.len},${spy.build_calls},${spy.draw_calls}|${spy.trace.join('')}|')
	if s := surface { surface_value(mut out, s, &view) }
	out.write_string('\n')
}

fn main() {
	mut out := strings.new_builder(65536)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		if line.len > 0 { record(mut out, line.split('|')) }
	}
	print(out.str())
}
