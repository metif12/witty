module vaxis

struct TableConsumerRow {
	left string
	right string
}

struct TableSingleRow { text string }

enum TableConsumerTag { alpha beta }
type TableConsumerAlias = TableConsumerTag
struct TableOptionalRow { kind ?TableConsumerAlias }

struct TableSnapshotState {
mut:
	data &TableMultiArrayList[TableSingleRow] = unsafe { nil }
	context &TableContext = unsafe { nil }
}

fn table_snapshot_callback(mut win Window, userdata voidptr) !u16 {
	mut state := unsafe { &TableSnapshotState(userdata) }
	state.data.items[1] = TableSingleRow{ text: 'changed' }
	state.context.start = 65535
	return 0
}

fn test_table_callback_keeps_allocated_row_snapshot_and_live_context_arithmetic() {
	mut screen := Screen.new(Winsize{ cols: 8, rows: 4 })
	mut data := &TableMultiArrayList[TableSingleRow]{ items: [TableSingleRow{ text: 'one' }, TableSingleRow{ text: 'two' }, TableSingleRow{ text: 'three' }] }
	mut context := TableContext{ selected_bg: ColorDefault{}, active_bg: ColorDefault{}, cell_x_off: 0 }
	state := &TableSnapshotState{ data: data, context: &context }
	context.active_ctx = voidptr(state)
	context.active_content_fn = table_snapshot_callback
	table_draw_table(true, Window.new(&screen), *data, mut context)!
	assert context.start == 65535 && data.items[1].text == 'changed'
	assert (screen.read_cell(0, 2) or { panic('missing cell') }).char_.grapheme == 't'
	assert (screen.read_cell(1, 2) or { panic('missing cell') }).char_.grapheme == 'w'
}

fn test_table_optional_enum_alias_prints_source_any_tag_and_missing_marker() {
	mut screen := Screen.new(Winsize{ cols: 8, rows: 3 })
	mut context := TableContext{ selected_bg: ColorDefault{}, active_bg: ColorDefault{}, cell_x_off: 0, header_align: .left }
	data := TableMultiArrayList[TableOptionalRow]{ items: [TableOptionalRow{ kind: TableConsumerAlias(TableConsumerTag.alpha) }, TableOptionalRow{}] }
	table_draw_table(true, Window.new(&screen), data, mut context)!
	assert (screen.read_cell(0, 1) or { panic('missing cell') }).char_.grapheme == '.'
	assert (screen.read_cell(1, 1) or { panic('missing cell') }).char_.grapheme == 'a'
	assert (screen.read_cell(0, 2) or { panic('missing cell') }).char_.grapheme == '-'
}

struct TableCallbackState {
mut:
	calls int
	fail bool
}

fn table_consumer_callback(mut win Window, userdata voidptr) !u16 {
	mut state := unsafe { &TableCallbackState(userdata) }
	state.calls++
	if state.fail { return error('TableCallbackFailure') }
	win.write_cell(0, 0, Cell{ char_: CellCharacter{ grapheme: 'X' } })
	return 1
}

fn test_table_multilist_renderer_preserves_repeated_columns_and_collection_boundaries() {
	mut screen := Screen.new(Winsize{ cols: 12, rows: 3 })
	mut context := TableContext{ selected_bg: ColorDefault{}, active_bg: ColorDefault{}, header_align: .left, cell_x_off: 0, col_width: TableWidthStaticAll{ width: 2 }, header_names: TableHeaderCustom{ names: ['A', 'B'] } }
	data := TableMultiArrayList[TableConsumerRow]{ items: [TableConsumerRow{ left: 'L', right: 'R' }] }
	table_draw_table(true, Window.new(&screen), data, mut context)!
	for col, expected in {0: 'L', 2: 'R', 4: 'L', 6: 'R'} { assert (screen.read_cell(u16(col), 1) or { panic('missing cell') }).char_.grapheme == expected }
	mut unsupported := false
	table_draw_table(false, Window.new(&screen), data, mut context) or { unsupported = true; assert err.msg() == 'UnsupportedTableDataType' }
	assert unsupported
	unsupported = false
	table_draw_table(true, Window.new(&screen), TableArrayList[TableConsumerRow]{ items: data.items }, mut context) or { unsupported = true; assert err.msg() == 'UnsupportedTableDataType' }
	assert unsupported
	unsupported = false
	table_draw_table(true, Window.new(&screen), u32(1), mut context) or { unsupported = true; assert err.msg() == 'UnsupportedTableDataType' }
	assert unsupported
	context.col_indexes = TableColumnsByIndex{ indexes: [uint(1), 0] }
	screen.clear()
	table_draw_table(true, Window.new(&screen), data, mut context)!
	assert (screen.read_cell(0, 1) or { panic('missing cell') }).char_.grapheme == 'R'
	assert (screen.read_cell(2, 1) or { panic('missing cell') }).char_.grapheme == 'L'
	assert (screen.read_cell(4, 1) or { panic('missing cell') }).char_.grapheme == ' '
}

fn test_table_active_callback_runs_without_active_color_and_retains_partial_error_state() {
	mut screen := Screen.new(Winsize{ cols: 8, rows: 4 })
	mut state := &TableCallbackState{}
	mut context := TableContext{ selected_bg: ColorDefault{}, active_bg: ColorDefault{}, active_content_fn: table_consumer_callback, active_ctx: voidptr(state), header_align: .left, cell_x_off: 0 }
	data := TableMultiArrayList[TableSingleRow]{ items: [TableSingleRow{ text: 'one' }, TableSingleRow{ text: 'two' }] }
	table_draw_table(true, Window.new(&screen), data, mut context)!
	assert !context.active && state.calls == 1 && context.active_y_off == 1
	assert (screen.read_cell(0, 1) or { panic('missing cell') }).char_.grapheme == 'o'
	assert (screen.read_cell(0, 3) or { panic('missing cell') }).char_.grapheme == 't'
	state.fail = true
	state.calls = 0
	context.active_y_off = 0
	screen.clear()
	mut failed := false
	table_draw_table(true, Window.new(&screen), data, mut context) or { failed = true; assert err.msg() == 'TableCallbackFailure' }
	assert failed && state.calls == 1 && context.active_y_off == 0
	assert (screen.read_cell(0, 0) or { panic('missing cell') }).char_.grapheme == 't'
	assert (screen.read_cell(0, 1) or { panic('missing cell') }).char_.grapheme == ' '
}

fn test_table_column_width_modes_preserve_source_rounding_and_errors() {
	headers := ['a', 'three', 'long heading']
	win := Window{
		x_off:        0
		y_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        14
		height:       0
		screen:       unsafe { nil }
	}
	assert table_calc_col_width(0, headers, TableWidthDynamicFill{}, win)! == 5
	assert table_calc_col_width(65535, headers, TableWidthDynamicFill{}, Window{
		x_off:        0
		y_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        15
		height:       0
		screen:       unsafe { nil }
	})! == 6
	assert table_calc_col_width(1, headers, TableWidthDynamicHeaderLen{ padding: 2 }, win)! == 9
	assert table_calc_col_width(65535, []string{}, TableWidthStaticAll{ width: 17 }, Window{
		x_off:        0
		y_off:        0
		parent_x_off: 0
		parent_y_off: 0
		width:        0
		height:       0
		screen:       unsafe { nil }
	})! == 17
	assert table_calc_col_width(2, headers, TableWidthStaticIndividual{ widths: [
		u16(1),
		2,
		9,
	] }, win)! == 9
	mut failed := false
	table_calc_col_width(3, headers, TableWidthDynamicHeaderLen{ padding: 65535 }, win) or {
		failed = true
		assert err.msg() == 'NotEnoughStaticWidthsProvided'
	}
	assert failed
	failed = false
	table_calc_col_width(3, headers, TableWidthStaticIndividual{}, win) or {
		failed = true
		assert err.msg() == 'NotEnoughStaticWidthsProvided'
	}
	assert failed
}
