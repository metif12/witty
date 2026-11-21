module main

import os
import strconv
import strings
import vaxis
import vaxis.vxfw

fn dataset(id u8) []vxfw.Size {
	return match id {
		0 {
			[]vxfw.Size{}
		}
		1 {
			[vxfw.Size{}]
		}
		2 {
			[vxfw.Size{ width: 1, height: 1 }]
		}
		3 {
			[vxfw.Size{ width: 3, height: 1 }, vxfw.Size{ width: 2, height: 2 },
				vxfw.Size{ width: 4, height: 3 }]
		}
		4 {
			[vxfw.Size{}, vxfw.Size{}, vxfw.Size{}]
		}
		5 {
			[vxfw.Size{ width: 65535, height: 0 }]
		}
		6 {
			[vxfw.Size{ width: 0, height: 65535 }]
		}
		7 {
			[vxfw.Size{ width: 65535, height: 65535 }, vxfw.Size{ width: 1, height: 1 }]
		}
		8 {
			[vxfw.Size{ width: 32767, height: 32767 }, vxfw.Size{ width: 32768, height: 32768 }]
		}
		9 {
			[vxfw.Size{ width: 65534, height: 65534 }, vxfw.Size{ width: 1, height: 1 },
				vxfw.Size{ width: 1, height: 1 }]
		}
		10 {
			[vxfw.Size{ width: 5, height: 2 }, vxfw.Size{ width: 8, height: 0 },
				vxfw.Size{ width: 2, height: 5 }]
		}
		11 {
			[]vxfw.Size{len: 258}
		}
		12 {
			[vxfw.Size{}, vxfw.Size{}]
		}
		13 {
			[vxfw.Size{ height: 40000 }, vxfw.Size{}]
		}
		else {
			panic('invalid dataset')
		}
	}
}

struct Child {
	spy   &Spy
	index uint
mut:
	size  vxfw.Size
	calls uint
}

fn (child &Child) widget() vxfw.Widget {
	return vxfw.Widget{
		userdata: unsafe { voidptr(child) }
		draw_fn:  draw
	}
}

fn draw(ptr voidptr, ctx vxfw.DrawContext) !vxfw.Surface {
	mut child := unsafe { &Child(ptr) }
	mut s := child.spy
	s.trace << '${child.index},${child.calls},${ctx.min.width},${ctx.min.height},${optional(ctx.max.width)},${optional(ctx.max.height)},${ctx.cell_size.width},${ctx.cell_size.height};'
	call := s.calls
	s.calls++
	child.calls++
	if call == 0 {
		match s.mutation {
			1 {
				if !isnil(s.padding) { s.padding.padding = vxfw.PadValues{
						left:   1
						right:  2
						top:    1
						bottom: 2
					} }
			}
			2 {
				if !isnil(s.border) {
					s.border.labels = s.alt_labels
					s.border.style = vaxis.Style{
						fg:   vaxis.ColorIndex{
							index: 5
						}
						bold: true
					}
				}
			}
			3 {
				if s.items.len > 1 {
					s.items[1].flex = 2
					s.children[1].size = vxfw.Size{
						width:  2
						height: 1
					}
				}
			}
			4 {
				if s.items.len > 0 { s.items[int(child.index)].flex = 2 }
			}
			5 {
				if s.items.len > 0 {
					if !isnil(s.column) { s.column.children = s.items[..1] }
					if !isnil(s.row) { s.row.children = s.items[..1] }
				}
			}
			else {}
		}
	}
	if s.mutation == 8 && call == 2 && s.items.len > 0 { s.items[0].flex = 2 }
	if s.mutation == 6 && !s.changed && ctx.max.width != none && ctx.max.height != none
		&& s.items.len > 0 {
		if !isnil(s.column) {
			s.column.children = s.items[..1]
			s.changed = true
		}
		if !isnil(s.row) {
			s.row.children = s.items[..1]
			s.changed = true
		}
	}
	if s.fail_at >= 0 && call == uint(s.fail_at) { return error('OutOfMemory') }
	mut size := child.size
	match s.reply {
		1 {
			size = ctx.min
		}
		2 {
			size = vxfw.Size{
				width:  ctx.max.width or { size.width }
				height: ctx.max.height or { size.height }
			}
		}
		3 {
			if ctx.max.width != none && ctx.max.height != none {
				size = ctx.min
				if !isnil(s.column) { size.width = child.size.width }
				if !isnil(s.row) { size.height = child.size.height }
			}
		}
		4 {
			if ctx.max.width != none && ctx.max.height != none { size = vxfw.Size{
					width:  65535
					height: 65535
				} }
		}
		else {}
	}

	return vxfw.Surface{
		size:     size
		widget:   child.widget()
		buffer:   []
		children: []
	}
}

struct Spy {
mut:
	children   []Child
	items      []vxfw.FlexItem
	reply      u8
	mutation   u8
	fail_at    i64
	calls      uint
	changed    bool
	trace      []string
	owner      voidptr
	padding    &vxfw.Padding    = unsafe { nil }
	border     &vxfw.Border     = unsafe { nil }
	column     &vxfw.FlexColumn = unsafe { nil }
	row        &vxfw.FlexRow    = unsafe { nil }
	alt_labels []vxfw.BorderLabel
	bytes      []u8
}

fn optional(value ?u16) i32 {
	return if n := value { i32(n) } else { -1 }
}

fn num(p []string, index int) i64 {
	return strconv.parse_int(p[index], 10, 64) or { panic(err) }
}

fn label_bytes(id u8) []u8 {
	return match id {
		0 { []u8{} }
		1 { 'abc'.bytes() }
		2 { 'a'.bytes() }
		3 { 'e\xcc\x81\xe4\xb8\xadx'.bytes() }
		4 { '\x00\x1b\xffa'.bytes() }
		5 { '\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x92\xbb'.bytes() }
		6 { []u8{len: 65535, init: `a`} }
		7 { []u8{len: 65536, init: `a`} }
		8 { 'ab'.bytes() }
		9 { ('👩' + '\xe2\x80\x8d👩'.repeat(129)).bytes() }
		else { panic('invalid label') }
	}
}

fn hash_byte(hash u64, byte u8) u64 {
	return (hash ^ byte) * u64(1099511628211)
}

fn cells_hash(surface vxfw.Surface) u64 {
	mut hash := u64(14695981039346656037)
	for c in surface.buffer {
		for b in c.char_.grapheme.bytes() {
			hash = hash_byte(hash, b)
		}
		hash = hash_byte(hash, 0)
		hash = hash_byte(hash, c.char_.width)
		hash = hash_byte(hash, u8(c.default_))
		hash = hash_byte(hash, u8(c.style.bold))
		hash = hash_byte(hash, u8(c.style.reverse))
		fg := match c.style.fg {
			vaxis.ColorIndex { c.style.fg.index }
			else { u8(0) }
		}

		hash = hash_byte(hash, fg)
	}
	return hash
}

fn surface(mut out strings.Builder, surf vxfw.Surface, s &Spy) {
	id := if surf.widget.userdata == s.owner {
		uint(0)
	} else {
		child := unsafe { &Child(surf.widget.userdata) }
		child.index + 1
	}
	out.write_string('[${surf.size.width},${surf.size.height},${id},${surf.buffer.len},${cells_hash(surf):x},${surf.children.len};')
	for sub in surf.children {
		out.write_string('(${sub.origin.col},${sub.origin.row},${sub.z_index})')
		surface(mut out, sub.surface, s)
	}
	out.write_string(']')
}

fn record(mut out strings.Builder, p []string) {
	mut s := Spy{
		reply:      u8(num(p, 7))
		mutation:   u8(num(p, 8))
		fail_at:    num(p, 9)
		alt_labels: [vxfw.BorderLabel{ text: 'm', alignment: .bottom_left }]
		bytes:      label_bytes(u8(num(p, 14)))
	}
	weight := uint(num(p, 6))
	for i, size in dataset(u8(num(p, 5))) {
		s.children << Child{
			spy:   &s
			index: uint(i)
			size:  size
		}
	}
	for i in 0 .. s.children.len {
		s.items << vxfw.FlexItem{
			widget: s.children[i].widget()
			flex:   if weight == 999 { u8(255) } else { u8((weight >> ((i % 3) * 8)) & 255) }
		}
	}
	fallback := &Child{
		spy:   &s
		index: 0
		size:  vxfw.Size{}
	}
	widget := if s.children.len == 0 { fallback.widget() } else { s.children[0].widget() }
	ctx := vxfw.DrawContext{
		min:       vxfw.Size{
			width:  u16(num(p, 3))
			height: u16(num(p, 4))
		}
		max:       vxfw.MaxSize{
			width:  if num(p, 1) < 0 { none } else { ?u16(u16(num(p, 1))) }
			height: if num(p, 2) < 0 { none } else { ?u16(u16(num(p, 2))) }
		}
		cell_size: vxfw.Size{
			width:  11
			height: 19
		}
	}
	vxfw.DrawContext.init(unsafe { vaxis.GWidthMethod(num(p, 16)) })
	mut result := ?vxfw.Surface(none)
	mut status := 'ok'
	kind := p[0]
	if kind == 'A' {
		all := vxfw.Padding.all(u16(num(p, 10)))
		h := vxfw.Padding.horizontal(u16(num(p, 10)))
		v := vxfw.Padding.vertical(u16(num(p, 10)))
		out.write_string('${all.left},${all.right},${all.top},${all.bottom};${h.left},${h.right},${h.top},${h.bottom};${v.left},${v.right},${v.top},${v.bottom}\n')
		return
	}
	if kind == 'C' {
		mut view := vxfw.Center{
			child: widget
		}
		s.owner = &view
		if got := view.widget().draw(ctx) {
			result = got
		} else {
			status = err.msg()
		}
	}
	if kind == 'P' {
		mut view := vxfw.Padding{
			child:   widget
			padding: vxfw.PadValues{
				left:   u16(num(p, 10))
				right:  u16(num(p, 11))
				top:    u16(num(p, 12))
				bottom: u16(num(p, 13))
			}
		}
		s.owner = &view
		s.padding = &view
		if got := view.widget().draw(ctx) {
			result = got
		} else {
			status = err.msg()
		}
		out.write_string('${view.padding.left},${view.padding.right},${view.padding.top},${view.padding.bottom}|')
	}
	if kind == 'S' {
		mut view := vxfw.SizedBox{
			child: widget
			size:  vxfw.Size{
				width:  u16(num(p, 10))
				height: u16(num(p, 11))
			}
		}
		s.owner = &view
		if got := view.widget().draw(ctx) {
			result = got
		} else {
			status = err.msg()
		}
	}
	if kind == 'B' {
		mut labels := []vxfw.BorderLabel{}
		label_count := if num(p, 15) == 6 { 6 } else { 1 }
		if s.bytes.len > 0 {
			for index in 0 .. label_count {
				labels << vxfw.BorderLabel{
					text:      unsafe { tos(s.bytes.data, s.bytes.len) }
					alignment: unsafe {
						vxfw.BorderAlignment(if num(p, 15) == 6 {
							index
						} else {
							int(num(p, 15))
						})
					}
				}
			}
		}
		mut view := vxfw.Border{
			child:  widget
			labels: labels
			style:  vaxis.Style{
				fg:      vaxis.ColorIndex{
					index: 3
				}
				reverse: true
			}
		}
		s.owner = &view
		s.border = &view
		if got := view.widget().draw(ctx) {
			result = got
		} else {
			status = err.msg()
		}
		if surf := result {
			mut found := uint(0)
			for cell in surf.buffer {
				ptr := uint(cell.char_.grapheme.str)
				if ptr >= uint(s.bytes.data) && ptr < uint(s.bytes.data) + uint(s.bytes.len) {
					found++
				}
			}
			out.write_string('${found},${view.labels.len},${u8(view.style.bold)}|')
			if num(p, 14) == 8 {
				out.write_string('${cells_hash(surf):x}|')
				s.bytes[0] = `Z`
			}
		} else {
			out.write_string('0,0,0|')
		}
	}
	if kind == 'V' {
		mut view := vxfw.FlexColumn{
			children: s.items
		}
		s.owner = &view
		s.column = &view
		if got := view.widget().draw(ctx) {
			result = got
		} else {
			status = err.msg()
		}
		out.write_string('${view.children.len}|')
	}
	if kind == 'H' {
		mut view := vxfw.FlexRow{
			children: s.items
		}
		s.owner = &view
		s.row = &view
		if got := view.widget().draw(ctx) {
			result = got
		} else {
			status = err.msg()
		}
		out.write_string('${view.children.len}|')
	}
	out.write_string('${status}|${s.calls}|${s.trace.join('')}|')
	for item in s.items {
		out.write_string('${item.flex},')
	}
	out.write_string('|')
	if surf := result { surface(mut out, surf, &s) }
	out.write_string('\n')
}

fn main() {
	mut out := strings.new_builder(65536)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		if line.len > 0 { record(mut out, line.split('|')) }
	}
	print(out.str())
}
