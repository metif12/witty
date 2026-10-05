module main
import os
import strconv
import strings
import vaxis

enum Tag { alpha beta }
type TagAlias = Tag
type BytesAlias = []u8
struct Types { bytes BytesAlias optional_bytes ?BytesAlias text string optional_text ?string kind TagAlias optional_kind ?TagAlias }
type FloatAlias = f32
type DoubleAlias = f64
type IntegerAlias = i64
type UnsignedAlias = u64
type FlagAlias = bool
type TextAlias = string
struct Numeric { single FloatAlias double DoubleAlias optional_single ?FloatAlias optional_double ?DoubleAlias integer IntegerAlias natural UnsignedAlias flag FlagAlias text TextAlias }
fn float_value(bits u32) f32 { return unsafe { *(&f32(&bits)) } }
fn double_value(bits u64) f64 { return unsafe { *(&f64(&bits)) } }
struct Item { label string value ?i32 enabled bool kind Tag ratio f32 optional_tag ?Tag }
struct Single { text string }
struct CallbackState { mut: calls int mode int context &vaxis.TableContext = unsafe { nil } data &vaxis.TableMultiArrayList[Item] = unsafe { nil } }
fn callback(mut win vaxis.Window, pointer voidptr) !u16 {
	mut state := unsafe { &CallbackState(pointer) }; state.calls++
	if state.mode == 3 { state.context.start = 65535 }
	if state.mode == 4 { state.data.items[1] = Item{ ...state.data.items[1], label: 'changed' } }
	win = vaxis.Window{ ...win, height: 2 }
	win.write_cell(0, 1, vaxis.Cell{ char_: vaxis.CellCharacter{ grapheme: 'X' } })
	if state.mode == 2 { return error('TableCallbackFailure') }
	return 1
}
fn number(p []string, i int) u16 { return u16(strconv.parse_uint(p[i], 10, 16) or { panic(err) }) }
fn color(value vaxis.Color) u32 {
	return match value { vaxis.ColorDefault { 0 } vaxis.ColorIndex { 0x1000000 | u32(value.index) } vaxis.ColorRgb { 0x2000000 | u32(value.rgb[0]) << 16 | u32(value.rgb[1]) << 8 | u32(value.rgb[2]) } }
}
fn output(mut b strings.Builder, context vaxis.TableContext, screen vaxis.Screen, calls int, error_ string) {
	b.write_string('${error_}|${context.row},${context.col},${context.start},${context.active_y_off},${calls};')
	for c in screen.buf { b.write_string('${c.char_.grapheme}/${c.char_.width}/${color(c.style.fg)}/${color(c.style.bg)}/${color(c.style.ul)}/${int(c.style.ul_style)}/${int(c.style.bold)}/${int(c.default_)}/${int(c.wrapped)};') }
}
fn width_style(kind u16, arg u16, count int) vaxis.TableWidthStyle {
	return match kind { 0 { vaxis.TableWidthDynamicFill{} } 1 { vaxis.TableWidthDynamicHeaderLen{ padding: arg } } 2 { vaxis.TableWidthStaticAll{ width: arg } } else { vaxis.TableWidthStaticIndividual{ widths: []u16{len: count, init: u16(index * 3 + 1)} } } }
}
fn trap(mode string) {
	headers := ['x']; mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 4, rows: 3 }); win := vaxis.Window.new(&screen)
	mut ctx := vaxis.TableContext{ selected_bg: vaxis.ColorDefault{}, active_bg: vaxis.ColorDefault{} }
	match mode {
		'width_zero' { vaxis.table_calc_col_width(0, headers, vaxis.TableWidthDynamicFill{}, vaxis.Window{}) or { eprintln('UNEXPECTED: ${err}'); return } }
		'heads_zero' { vaxis.table_calc_col_width(0, []string{}, vaxis.TableWidthDynamicFill{}, win) or { eprintln('UNEXPECTED: ${err}'); return } }
		'heads_cast' { vaxis.table_calc_col_width(0, []string{len: 65536}, vaxis.TableWidthDynamicFill{}, win) or { eprintln('UNEXPECTED: ${err}'); return } }
		'header_cast' { vaxis.table_calc_col_width(0, ['x'.repeat(65536)], vaxis.TableWidthDynamicHeaderLen{}, win) or { eprintln('UNEXPECTED: ${err}'); return } }
		'padding' { vaxis.table_calc_col_width(0, headers, vaxis.TableWidthDynamicHeaderLen{ padding: 32768 }, win) or { eprintln('UNEXPECTED: ${err}'); return } }
		'header_add' { vaxis.table_calc_col_width(0, ['xx'], vaxis.TableWidthDynamicHeaderLen{ padding: 32767 }, win) or { eprintln('UNEXPECTED: ${err}'); return } }
		'width_list' { vaxis.table_calc_col_width(0, headers, vaxis.TableWidthStaticIndividual{}, win) or { eprintln('UNEXPECTED: ${err}'); return } }
		else {
			mut data := vaxis.TableMultiArrayList[Single]{ items: [Single{ text: 'a' }] }
			match mode {
				'empty_headers' { ctx.header_names = vaxis.TableHeaderCustom{} }
				'empty_rows' { data.items = []; ctx.row = 1 }
				'start_add' { ctx.start = 65535 }
				'active_add' { ctx.row = 1; ctx.active_y_off = 65535; ctx.active_content_fn = callback }
				'col_add' { data2 := vaxis.TableMultiArrayList[Item]{ items: [Item{ label: 'a' }] }; ctx.col_width = vaxis.TableWidthStaticAll{ width: 32768 }; vaxis.table_draw_table(true, win, data2, mut ctx) or { eprintln('UNEXPECTED: ${err}'); return }; eprintln('UNEXPECTED: returned'); return }
				'selected_cast' { data.items << Single{ text: 'b' }; data.items << Single{ text: 'c' }; mut state := &CallbackState{ mode: 3, context: &ctx }; ctx.sel_rows = [u16(0)]; ctx.active_ctx = voidptr(state); ctx.active_content_fn = callback }
				'align_list' { ctx.col_align = vaxis.TableColumnAlignmentByIndex{} }
				else { panic('unknown trap') }
			}
			vaxis.table_draw_table(true, win, data, mut ctx) or { eprintln('UNEXPECTED: ${err}'); return }
		}
	}
	eprintln('UNEXPECTED: returned')
}
fn main() {
	if !os.exists(os.args[1]) { trap(os.args[1]); return }
	text := os.read_file(os.args[1]) or { panic(err) }; mut b := strings.new_builder(4096)
	for line in text.split_into_lines() {
		p := line.split('|')
		mut ctx := vaxis.TableContext{ selected_bg: vaxis.ColorDefault{}, active_bg: vaxis.ColorDefault{} }
		if p[0] == 'C' { b.write_string('${ctx.row},${ctx.col},${ctx.start},${int(ctx.active)},${int(ctx.sel_rows != none)},${int(ctx.active_content_fn != none)},${int(ctx.active_ctx != unsafe { nil })},${ctx.active_y_off},${ctx.y_off},${ctx.cell_x_off},${int(ctx.header_align)},${int(ctx.header_borders)},${int(ctx.col_borders)},${color(ctx.selected_fg)},${color(ctx.active_fg)},${color(ctx.hdr_bg_1)},${color(ctx.hdr_bg_2)},${color(ctx.row_bg_1)},${color(ctx.row_bg_2)}\n'); continue }
		if p[0] == 'N' {
			i := int(number(p, 1))
			singles := [u32(0), 0x80000000, 0x7f800000, 0xff800000, 0x7fc00000, 1, 0x3eaaaaab, 0x7f7fffff, 0xff7fffff, 0xbdcccccd, 0x00800000]
			doubles := [u64(0), 0x8000000000000000, 0x7ff0000000000000, 0xfff0000000000000, 0x7ff8000000000000, 1, 0x3fd5555555555555, 0x7fefffffffffffff, 0xffefffffffffffff, 0xbfb999999999999a, 0x0010000000000000]
			single := FloatAlias(float_value(singles[i])); double := DoubleAlias(double_value(doubles[i]))
			item := Numeric{ single: single, double: double, optional_single: single, optional_double: double, integer: IntegerAlias(if i == 1 { i64(-9223372036854775807) - 1 } else { i64(100000 + i) }), natural: UnsignedAlias(~u64(0) - u64(i)), flag: FlagAlias(i % 2 != 0), text: TextAlias('alias') }
			mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: 3072, rows: 2 }); ctx.col_width = vaxis.TableWidthStaticAll{ width: 384 }; ctx.header_align = .left; ctx.cell_x_off = 0
			mut error_ := 'ok'; vaxis.table_draw_table(true, vaxis.Window.new(&screen), vaxis.TableMultiArrayList[Numeric]{ items: [item] }, mut ctx) or { error_ = err.msg() }
			output(mut b, ctx, screen, 0, error_); b.write_string('\n'); continue
		}
		if p[0] == 'W' {
			headers := []string{len: int(number(p, 3)), init: 'h'.repeat(int(number(p, 6)))}
			result := vaxis.table_calc_col_width(number(p, 4), headers, width_style(number(p, 1), number(p, 5), headers.len), vaxis.Window{ width: number(p, 2) }) or { b.write_string('E:${err.msg()}\n'); continue }
			b.write_string('${result}\n'); continue
		}
		mut screen := vaxis.Screen.new(vaxis.Winsize{ cols: if p[0] == 'D' { if number(p, 1) >= 4 { u16(144) } else { u16(8) } } else { number(p, 1) }, rows: if p[0] == 'D' { u16(4) } else { number(p, 2) } }); win := vaxis.Window.new(&screen)
		mut err_text := 'ok'
		if p[0] == 'D' {
			kind := number(p, 1)
			if kind == 0 { vaxis.table_draw_table(true, win, u32(1), mut ctx) or { err_text = err.msg() } }
			if kind == 1 { vaxis.table_draw_table(true, win, vaxis.TableArrayList[Single]{ items: [Single{ text: 'a' }] }, mut ctx) or { err_text = err.msg() } }
			if kind == 2 || kind == 3 { vaxis.table_draw_table(kind == 3, win, vaxis.TableMultiArrayList[Single]{}, mut ctx) or { err_text = err.msg() } }
			if kind >= 4 {
				ctx.col_width = vaxis.TableWidthStaticAll{ width: 24 }; ctx.header_align = .left; ctx.cell_x_off = 0
				item := if kind == 4 { Types{ bytes: BytesAlias([u8(97), 98]), optional_bytes: ?BytesAlias(BytesAlias([]u8{})), text: 'ab', optional_text: ?string('ab'), kind: TagAlias(Tag.alpha), optional_kind: ?TagAlias(TagAlias(Tag.beta)) } } else { Types{ kind: TagAlias(Tag.beta) } }
				vaxis.table_draw_table(true, win, vaxis.TableMultiArrayList[Types]{ items: [item] }, mut ctx) or { err_text = err.msg() }
			}
			output(mut b, ctx, screen, 0, err_text); b.write_string('\n'); continue
		}
		mut state := &CallbackState{ mode: int(number(p, 9)), context: &ctx }
		ctx.row = number(p, 4); ctx.start = number(p, 5); ctx.col = number(p, 6); ctx.active = number(p, 7) != 0; ctx.active_y_off = number(p, 8)
		ctx.active_ctx = voidptr(state); if state.mode > 0 { ctx.active_content_fn = callback }
		ctx.selected_bg = vaxis.ColorIndex{ index: 3 }; ctx.selected_fg = vaxis.ColorIndex{ index: 4 }; ctx.active_bg = vaxis.ColorIndex{ index: 5 }; ctx.active_fg = vaxis.ColorIndex{ index: 6 }
		ctx.col_width = width_style(number(p, 10), number(p, 11), 6); ctx.header_align = unsafe { vaxis.TableHorizontalAlignment(number(p, 12)) }; ctx.col_align = vaxis.TableColumnAlignmentAll{ alignment: unsafe { vaxis.TableHorizontalAlignment(number(p, 13)) } }
		if number(p, 14) != 0 { ctx.sel_rows = [u16(0), 2, 5] }
		if number(p, 15) != 0 { ctx.col_indexes = vaxis.TableColumnsByIndex{ indexes: [usize(3), 1] } }
		if number(p, 16) != 0 { ctx.header_names = vaxis.TableHeaderCustom{ names: ['Long heading', 'N', 'Enabled', 'Tag', 'Ratio', 'Optional tag'] } }
		ctx.cell_x_off = number(p, 17); ctx.header_borders = number(p, 18) & 1 != 0; ctx.col_borders = number(p, 18) & 2 != 0; ctx.y_off = number(p, 19)
		mut data := vaxis.TableMultiArrayList[Item]{}
		for i in 0 .. int(number(p, 3)) { data.items << Item{ label: ['one', 'two words', 'λx', 'four long words'][i % 4], value: if i % 2 == 0 { ?i32(i * 17) } else { none }, enabled: i % 2 != 0, kind: if i % 2 == 0 { .alpha } else { .beta }, ratio: f32(i) / 3, optional_tag: if i % 2 == 0 { ?Tag(Tag.alpha) } else { none } } }
		state.data = &data
		vaxis.table_draw_table(true, win, data, mut ctx) or { err_text = err.msg() }
		output(mut b, ctx, screen, state.calls, err_text); b.write_string('\n')
	}
	print(b.str())
}
