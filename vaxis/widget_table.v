module vaxis

import strconv

pub struct TableWidthDynamicFill {}

pub struct TableWidthDynamicHeaderLen {
pub:
	padding u16
}

pub struct TableWidthStaticAll {
pub:
	width u16
}

pub struct TableWidthStaticIndividual {
pub:
	widths []u16
}

pub type TableWidthStyle = TableWidthDynamicFill
	| TableWidthDynamicHeaderLen
	| TableWidthStaticAll
	| TableWidthStaticIndividual

pub struct TableColumnsAll {}

pub struct TableColumnsByIndex {
pub:
	indexes []uint
}

pub type TableColumnIndexes = TableColumnsAll | TableColumnsByIndex

pub struct TableHeaderFieldNames {}

pub struct TableHeaderCustom {
pub:
	names []string
}

pub type TableHeaderNames = TableHeaderFieldNames | TableHeaderCustom

pub enum TableHorizontalAlignment {
	left
	center
}
pub struct TableColumnAlignmentAll {
pub:
	alignment TableHorizontalAlignment
}

pub struct TableColumnAlignmentByIndex {
pub:
	alignments []TableHorizontalAlignment
}

pub type TableColumnAlignment = TableColumnAlignmentAll | TableColumnAlignmentByIndex
pub type TableActiveContentFn = fn (mut Window, voidptr) !u16

struct TableEmptyContext {}

// Source widgets.Table declarations use flattened names and V sum types.
pub struct TableContext {
pub mut:
	row               u16
	col               u16
	start             u16
	sel_rows          ?[]u16
	active            bool
	active_content_fn ?TableActiveContentFn
	active_ctx        voidptr = &TableEmptyContext{}
	active_y_off      u16
	selected_bg       Color @[required]
	selected_fg       Color
	active_bg         Color @[required]
	active_fg         Color
	hdr_bg_1          Color = ColorRgb{
		rgb: [u8(64), 64, 64]!
	}
	hdr_bg_2          Color = ColorRgb{
		rgb: [u8(8), 8, 24]!
	}
	row_bg_1          Color = ColorRgb{
		rgb: [u8(32), 32, 32]!
	}
	row_bg_2          Color = ColorRgb{
		rgb: [u8(8), 8, 8]!
	}
	y_off             u16
	cell_x_off        u16                      = 1
	col_width         TableWidthStyle          = TableWidthDynamicFill{}
	header_names      TableHeaderNames         = TableHeaderFieldNames{}
	col_indexes       TableColumnIndexes       = TableColumnsAll{}
	header_align      TableHorizontalAlignment = .center
	col_align         TableColumnAlignment     = TableColumnAlignmentAll{}
	header_borders    bool
	col_borders       bool
}

pub fn table_calc_col_width(col u16, headers []string, style TableWidthStyle, table_win Window) !u16 {
	match style {
		TableWidthDynamicFill {
			count := widget_checked_u16(uint(headers.len))
			if count == 0 { panic('division by zero') }
			mut width := table_win.width / count
			if width % 2 != 0 { width = table_saturating_add_u16(width, 1) }
			if table_win.width == 0 { panic('integer overflow') }
			for uint(width) * uint(headers.len) < uint(table_win.width - 1) {
				width = table_saturating_add_u16(width, 1)
			}
			return width
		}
		TableWidthDynamicHeaderLen {
			if int(col) >= headers.len { return error('NotEnoughStaticWidthsProvided') }
			length := widget_checked_u16(uint(headers[int(col)].len))
			if style.padding > 32767 { panic('integer overflow') }
			padding := style.padding * u16(2)
			if length > 65535 - padding { panic('integer overflow') }
			return length + padding
		}
		TableWidthStaticAll {
			return style.width
		}
		TableWidthStaticIndividual {
			if int(col) >= headers.len { return error('NotEnoughStaticWidthsProvided') }
			if int(col) >= style.widths.len { panic('Table width index out of bounds') }
			return style.widths[int(col)]
		}
	}
}

fn table_saturating_add_u16(a u16, b u16) u16 {
	return if a > 65535 - b { u16(65535) } else { a + b }
}

// The source's MultiArrayList columns are exposed as rows by its allocated
// copy. GC owns the corresponding V rows; the flag retains allocator presence.
pub struct TableMultiArrayList[T] {
pub mut:
	items []T
}

pub struct TableArrayList[T] {
pub mut:
	items []T
}

fn (data TableMultiArrayList[T]) table_multi_items() []T { return data.items }

pub fn table_draw_table[D](allocation bool, win Window, data D, mut context TableContext) ! {
	$if D.unaliased_typ is $array_dynamic || D.unaliased_typ is string || D.unaliased_typ is $pointer {
		$compile_error('drawTable slice input retains the source obsolete Pointer.Size.Slice compile boundary')
	} $else $if D.unaliased_typ is $struct {
		$for method in D.methods {
			$if method.name == 'table_multi_items' {
				if !allocation { return error('UnsupportedTableDataType') }
				table_draw_rows(win, data.table_multi_items().clone(), mut context)!
				return
			}
		}
	}
	// Zig 0.15.2 ArrayList's type name no longer contains "ArrayList".
	return error('UnsupportedTableDataType')
}

fn table_add_u16(a u16, b u16) u16 {
	if a > 65535 - b { panic('integer overflow') }
	return a + b
}

fn table_sub_u16(a u16, b u16) u16 { return if a < b { u16(0) } else { a - b } }

fn usize_min(a uint, b uint) uint { return if a < b { a } else { b } }

fn table_text[T](value T) string {
	$if T.unaliased_typ is string { return value }
	$else $if T.unaliased_typ is $enum {
		$for member in T.values { if i64(value) == i64(member.value) { return member.name } }
		panic('invalid enum tag')
	}
	$else $if T.unaliased_typ is f32 { return table_float_text(strconv.f32_to_str_l(value)) }
	$else $if T.unaliased_typ is f64 { return table_float_text(f64(value).strlong()) }
	$else $if T.unaliased_typ is u8 || T.unaliased_typ is u16 || T.unaliased_typ is u32 || T.unaliased_typ is u64 || T.unaliased_typ is uint { return u64(value).str() }
	$else $if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int || T.unaliased_typ is i64 || T.unaliased_typ is int { return i64(value).str() }
	$else $if T.unaliased_typ is bool { return bool(value).str() }
	$else $if T.unaliased_typ is []u8 {
		mut parts := []string{cap: value.len}
		for item in value { parts << item.str() }
		return '{ ' + parts.join(', ') + ' }'
	}
	$else $if T.unaliased_typ is []string {
		$compile_error('drawTable string-slice field retains the source unsupported slice formatting compile boundary')
	} $else { return value.str() }
}

fn table_float_text(text string) string {
	if text == '+inf' { return 'inf' }
	return if text.ends_with('.0') { text[..text.len - 2] } else { text }
}

fn table_optional_text[T](value T) string {
	$if T.unaliased_typ is $enum { return '.' + table_text(value) }
	$else { return table_text(value) }
}

fn table_option_text[T](value ?T) string {
	item := value or { return '-' }
	return table_optional_text(item)
}

fn table_draw_rows[T](win Window, rows []T, mut context TableContext) ! {
	$if T.unaliased_typ is $struct {
		mut fields := []string{}
		$for field in T.fields { fields << field.name }
		indexes := match context.col_indexes {
			TableColumnsAll { []uint{len: fields.len, init: uint(index)} }
			TableColumnsByIndex { context.col_indexes.indexes }
		}
		mut headers := []string{len: fields.len}
		match context.header_names {
			TableHeaderFieldNames {
				mut initialized := []bool{len: fields.len}
				for index in indexes {
					if index < uint(fields.len) { headers[int(index)] = fields[int(index)]; initialized[int(index)] = true }
				}
				for value in initialized { if !value { panic('uninitialized source Table header') } }
			}
			TableHeaderCustom { headers = unsafe { context.header_names.names } }
		}
		table_win := win.child(WindowChildOptions{ y_off: int(context.y_off), width: win.width, height: win.height })
		if headers.len == 0 { panic('integer overflow') }
		if uint(context.col) > uint(headers.len - 1) { context.col = widget_checked_u16(uint(headers.len - 1)) }
		mut col_start := u16(0)
		for index, text in headers {
			width := table_calc_col_width(widget_checked_u16(uint(index)), headers, context.col_width, table_win)!
			mut fg := Color(ColorDefault{})
			mut bg := if index % 2 == 0 { context.hdr_bg_1 } else { context.hdr_bg_2 }
			if context.active && uint(index) == uint(context.col) { fg = context.active_fg; bg = context.active_bg }
			hdr_win := table_win.child(WindowChildOptions{ x_off: int(col_start), width: width, height: 1,
				border: WindowBorderOptions{ where_: if context.header_borders && index > 0 { BorderWhere(BorderLeft{}) } else { BorderWhere(BorderNone{}) } } })
			hdr := if context.header_align == .left { hdr_win } else { alignment_center(hdr_win, u16(usize_min(uint(table_sub_u16(width, 1)), widget_saturating_add(uint(text.len), 1))), 1) }
			hdr_win.fill(Cell{ style: Style{ bg: bg } })
			hdr.print([CellSegment{ text: table_truncate(text, width), style: Style{ fg: fg, bg: bg, bold: true, ul_style: if uint(index) == uint(context.col) { .single } else { .dotted } } }], PrintOptions{ wrap: .word })
			col_start = table_add_u16(col_start, width)
		}
		if context.active_content_fn == none { context.active_y_off = 0 }
		max_items := if uint(rows.len) > uint(table_sub_u16(table_win.height, 1)) { table_sub_u16(table_win.height, 1) } else { widget_checked_u16(uint(rows.len)) }
		mut table_end := table_add_u16(context.start, max_items)
		if table_add_u16(context.row, context.active_y_off) >= table_sub_u16(win.height, 2) { table_end = table_sub_u16(table_end, context.active_y_off) }
		if uint(table_end) > uint(rows.len) { table_end = widget_checked_u16(uint(rows.len)) }
		if context.row == 0 { context.start = 0 }
		else if context.row < context.start { context.start = context.row }
		else {
			if rows.len == 0 { panic('integer overflow') }
			if uint(context.row) >= uint(rows.len - 1) { context.row = widget_checked_u16(uint(rows.len - 1)) }
			if context.row >= table_end { context.start = table_add_u16(context.start, table_add_u16(context.row - table_end, 1)) }
		}
		table_end = table_add_u16(context.start, max_items)
		if table_add_u16(context.row, context.active_y_off) >= table_sub_u16(win.height, 2) { table_end = table_sub_u16(table_end, context.active_y_off) }
		if uint(table_end) > uint(rows.len) { table_end = widget_checked_u16(uint(rows.len)) }
		context.start = u16(usize_min(uint(context.start), uint(table_end)))
		context.active_y_off = 0
		for row, data in rows[int(context.start)..int(table_end)] {
			absolute_row := widget_checked_add(uint(context.start), uint(row))
			mut fg := Color(ColorDefault{})
			mut bg := if row % 2 == 0 { context.row_bg_1 } else { context.row_bg_2 }
			if context.active && absolute_row == uint(context.row) { fg = context.active_fg; bg = context.active_bg }
			else if selected := context.sel_rows { if widget_checked_u16(absolute_row) in selected { fg = context.selected_fg; bg = context.selected_bg } }
			mut row_win := table_win.child(WindowChildOptions{ y_off: int(widget_checked_u16(widget_checked_add(widget_checked_add(1, uint(row)), uint(context.active_y_off)))), width: table_win.width, height: 1 })
			if absolute_row == uint(context.row) { if callback := context.active_content_fn { context.active_y_off = callback(mut row_win, context.active_ctx)! } }
			col_start = 0
			mut col_index := uint(0)
			for field_index in indexes {
				mut item_index := uint(0)
				$for field in T.fields {
					if context.col_indexes is TableColumnsAll || item_index == field_index {
						width := table_calc_col_width(widget_checked_u16(item_index), headers, context.col_width, table_win)!
						item_win := row_win.child(WindowChildOptions{ x_off: int(col_start), width: width, height: 1,
							border: WindowBorderOptions{ where_: if context.col_borders && col_index > 0 { BorderWhere(BorderLeft{}) } else { BorderWhere(BorderNone{}) } } })
						mut text := ''
						$if field.is_option {
							text = table_option_text(data.$(field.name))
						}
						$else { text = table_text(data.$(field.name)) }
						item_win.fill(Cell{ style: Style{ bg: bg } })
						alignment := match context.col_align {
							TableColumnAlignmentAll { context.col_align.alignment }
							TableColumnAlignmentByIndex { if col_index >= uint(context.col_align.alignments.len) { panic('Table alignment index out of bounds') }; context.col_align.alignments[int(col_index)] }
						}
						align_win := if alignment == .left { item_win } else { alignment_center(item_win, u16(usize_min(uint(table_sub_u16(width, 1)), widget_saturating_add(uint(text.len), 1))), 1) }
						if alignment == .center { align_win.fill(Cell{ style: Style{ bg: bg } }) }
						align_win.print([CellSegment{ text: table_truncate(text, width), style: Style{ fg: fg, bg: bg } }], PrintOptions{ wrap: .word, col_offset: context.cell_x_off })
						col_index = widget_checked_add(col_index, 1)
						col_start = table_add_u16(col_start, width)
					}
					item_index++
				}
			}
		}
	} $else { $compile_error('drawTable items must have source struct fields') }
}

fn table_truncate(text string, width u16) string {
	return if text.len > int(width) { text[..int(table_sub_u16(width, 4))] + '...' } else { text }
}
