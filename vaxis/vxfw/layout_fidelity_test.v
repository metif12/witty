module vxfw

import vaxis

struct LayoutFidelityChild {
	spy   &LayoutFidelitySpy
	index int
	size  Size
}

fn (child &LayoutFidelityChild) widget() Widget {
	return Widget{
		userdata: unsafe { voidptr(child) }
		draw_fn:  layout_fidelity_draw
	}
}

@[heap]
struct LayoutFidelitySpy {
mut:
	column   &FlexColumn = unsafe { nil }
	row      &FlexRow    = unsafe { nil }
	border   &Border     = unsafe { nil }
	items    []FlexItem
	children []LayoutFidelityChild
	indexes  []int
	widths   []?u16
	mode     int
	changed  bool
	failed   bool
}

fn layout_fidelity_draw(ptr voidptr, ctx DrawContext) !Surface {
	child := unsafe { &LayoutFidelityChild(ptr) }
	mut spy := child.spy
	spy.indexes << child.index
	spy.widths << ctx.max.width
	first_pass := ctx.max.height == none
	if !spy.changed && ((spy.mode == 1 && first_pass) || (spy.mode == 2 && !first_pass)) {
		if !isnil(spy.column) { spy.column.children = spy.items[..1] }
		if !isnil(spy.row) { spy.row.children = spy.items[..1] }
		spy.changed = true
	}
	if spy.mode == 3 && !isnil(spy.border) {
		spy.border.style = vaxis.Style{
			fg:   vaxis.ColorIndex{
				index: 5
			}
			bold: true
		}
	}
	if spy.failed { return error('OutOfMemory') }
	mut size := child.size
	if !isnil(spy.column) { size.height = ctx.max.height or { size.height } }
	if !isnil(spy.row) { size.width = ctx.max.width or { size.width } }
	return Surface{
		size:     size
		widget:   child.widget()
		buffer:   []
		children: []
	}
}

fn (mut spy LayoutFidelitySpy) init() {
	for index in 0 .. 3 {
		spy.children << LayoutFidelityChild{
			spy:   &spy
			index: index
			size:  Size{
				width:  2
				height: 1
			}
		}
	}
	for index in 0 .. 3 {
		spy.items << FlexItem{
			widget: spy.children[index].widget()
		}
	}
}

fn layout_fidelity_context(width u16, height u16) DrawContext {
	return DrawContext{
		min:       Size{}
		max:       MaxSize{
			width:  width
			height: height
		}
		cell_size: Size{}
	}
}

fn test_layout_flex_passes_keep_original_slice_after_callback_replacement() {
	mut first := LayoutFidelitySpy{
		mode: 1
	}
	first.init()
	mut column := FlexColumn{
		children: first.items
	}
	first.column = &column
	surface := column.draw(layout_fidelity_context(10, 10))!
	assert first.indexes == [0, 1, 2, 0]
	assert column.children.len == 1
	assert surface.children.len == 1
	assert surface.size == Size{
		width:  2
		height: 10
	}
	mut second := LayoutFidelitySpy{
		mode: 2
	}
	second.init()
	mut second_column := FlexColumn{
		children: second.items
	}
	second.column = &second_column
	second_surface := second_column.draw(layout_fidelity_context(10, 10))!
	assert second.indexes == [0, 1, 2, 0, 1, 2]
	assert second_column.children.len == 1
	assert second_surface.children.len == 3
	assert second_surface.size.height == 9
	mut horizontal := LayoutFidelitySpy{
		mode: 2
	}
	horizontal.init()
	mut row := FlexRow{
		children: horizontal.items
	}
	horizontal.row = &row
	row_surface := row.draw(layout_fidelity_context(10, 10))!
	assert horizontal.indexes == [0, 1, 2]
	assert row.children.len == 1
	assert row_surface.children.len == 3
	assert row_surface.size.width == 9
}

fn test_layout_child_error_precedes_center_padding_border_size_arithmetic() {
	mut spy := LayoutFidelitySpy{
		failed: true
	}
	child := &LayoutFidelityChild{
		spy:   &spy
		index: 0
		size:  Size{
			width:  65535
			height: 65535
		}
	}
	center := &Center{
		child: child.widget()
	}
	border := &Border{
		child: child.widget()
	}
	padding := &Padding{
		child:   child.widget()
		padding: PadValues{
			left:  1
			right: 1
		}
	}
	for widget in [center.widget(), border.widget(), padding.widget()] {
		if _ := widget.draw(layout_fidelity_context(2, 2)) {
			assert false
		} else {
			assert err.msg() == 'OutOfMemory'
		}
	}
	assert spy.indexes == [0, 0, 0]
	assert spy.widths == [?u16(2), 0, 0]
}

fn test_layout_border_reads_style_after_child_and_borrows_label_graphemes() {
	DrawContext.init(.unicode)
	mut spy := LayoutFidelitySpy{
		mode: 3
	}
	child := &LayoutFidelityChild{
		spy:   &spy
		index: 0
		size:  Size{
			width:  3
			height: 1
		}
	}
	mut bytes := 'ab'.bytes()
	mut border := Border{
		child:  child.widget()
		labels: [
			BorderLabel{
				text:      unsafe { tos(bytes.data, bytes.len) }
				alignment: .top_left
			},
		]
	}
	spy.border = &border
	surface := border.draw(layout_fidelity_context(5, 3))!
	cell := surface.read_cell(1, 0)
	assert cell.char_.grapheme == 'a'
	assert cell.char_.grapheme.str == bytes.data
	assert cell.style.fg == vaxis.Color(vaxis.ColorIndex{
		index: 5
	})
	assert cell.style.bold
	bytes[0] = `Z`
	assert surface.read_cell(1, 0).char_.grapheme == 'Z'
}

fn test_layout_padding_and_empty_flex_keep_source_constraint_quirks() {
	mut spy := LayoutFidelitySpy{}
	child := &LayoutFidelityChild{
		spy:   &spy
		index: 0
		size:  Size{
			width:  2
			height: 1
		}
	}
	unbounded := Padding{
		child: child.widget()
	}.draw(DrawContext{ min: Size{}, max: MaxSize{}, cell_size: Size{} })!
	assert unbounded.size == child.size
	padded := Padding{
		child:   child.widget()
		padding: PadValues{
			left:  3
			right: 4
		}
	}.draw(layout_fidelity_context(2, 2))!
	assert spy.widths == [?u16(none), 0]
	assert padded.size.width == 9
	ctx := DrawContext{
		min:       Size{
			width:  1
			height: 1
		}
		max:       MaxSize{
			width:  0
			height: 0
		}
		cell_size: Size{}
	}
	assert FlexRow{
		children: []
	}.draw(ctx)!.size == ctx.min
	assert FlexColumn{
		children: []
	}.draw(ctx)!.size == ctx.min
}
