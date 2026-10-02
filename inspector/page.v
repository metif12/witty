module inspector

// Inspector widgets for the faithful terminal.Page representation.
// Translated from Ghostty's src/inspector/widgets/page.zig.

import cimgui
import terminal

pub struct PageTreeNodeState {
pub:
	page      &terminal.Page
	index     usize
	row_range [2]usize
	active    bool
	viewport  bool
}

pub fn inspector(context cimgui.Context, page &terminal.Page) {
	context.separator_text('Managed Memory')
	managed_memory(context, page)
	context.separator_text('Styles')
	styles_list(context, page)
	context.separator_text('Hyperlinks')
	hyperlinks_list(context, page)
	context.separator_text('Rows')
	rows_table(context, page)
}

// tree_node draws one PageList page header. Callers must call tree_pop when
// this returns true.
pub fn tree_node(context cimgui.Context, state PageTreeNodeState) bool {
	open := context.tree_node_flags('Page ${state.index}', cimgui.tree_node_flags_page_header)
	header_x, header_y := context.item_rect_min()
	header_height := context.item_rect_max_y() - header_y
	y_center := header_y + (header_height - context.text_line_height()) * 0.5
	context.set_cursor_screen_pos(header_x + 170, y_center)
	context.text_disabled('${state.page.size.cols}c x ${state.page.size.rows}r')
	context.same_line()
	context.text('rows ${state.row_range[0]}..${state.row_range[1]}')
	if state.active {
		context.same_line()
		context.text_colored(cimgui.Color{ r: 0.4, g: 0.9, b: 0.4 }, 'active')
	}
	if state.viewport {
		context.same_line()
		context.text_colored(cimgui.Color{ r: 0.4, g: 0.8, b: 1.0 }, 'viewport')
	}
	if state.page.is_dirty() {
		context.same_line()
		context.text_colored(cimgui.Color{ r: 1.0, g: 0.4, b: 0.4 }, 'dirty')
	}
	return open
}

pub fn managed_memory(context cimgui.Context, page &terminal.Page) {
	if context.begin_table('##overview', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		context.table_next_row()
		context.table_set_column(0)
		context.text('Memory Size')
		context.table_set_column(1)
		help_marker(context, 'Memory allocated for this page. Note the backing memory may be a larger allocation from which this page uses a portion.')
		context.table_set_column(2)
		context.text('${to_kibi_bytes(terminal.Page.layout(page.capacity).total_size)} KiB')
		context.end_table()
	}

	if !context.begin_table('##managed', 4, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_column('Resource', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Used', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Capacity', cimgui.table_column_width_fixed, 0)
	context.table_headers_row()
	managed_memory_row(context, 'Columns', 'Number of columns in the terminal grid.',
		usize(page.size.cols), usize(page.capacity.cols))
	managed_memory_row(context, 'Rows', 'Number of rows in this page.', usize(page.size.rows),
		usize(page.capacity.rows))
	managed_memory_row(context, 'Styles', 'Unique text styles (colors, attributes) currently in use.',
		page.styles.count(), page.styles.capacity())
	managed_memory_row(context, 'Graphemes', 'Extended grapheme clusters for multi-codepoint characters.',
		page.grapheme_count(), page.grapheme_capacity())
	managed_memory_row(context, 'Strings (bytes)', 'String storage for hyperlink URIs and other text data.',
		page.hyperlink_set.string_used(), page.hyperlink_set.string_capacity())
	managed_memory_row(context, 'Hyperlink Map', 'Maps cell positions to hyperlink IDs.',
		page.hyperlink_count(), page.hyperlink_capacity())
	managed_memory_row(context, 'Hyperlink IDs', 'Unique hyperlink definitions (URI + optional ID).',
		page.hyperlink_set.count(), page.hyperlink_set.layout.cap)
}

fn managed_memory_row(context cimgui.Context, label string, help string, used usize, capacity usize) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.table_set_column(1)
	help_marker(context, help)
	context.table_set_column(2)
	context.text(used.str())
	context.table_set_column(3)
	context.text(capacity.str())
}

fn rows_table(context cimgui.Context, page &terminal.Page) {
	visible_rows := u32(if page.size.rows < 12 { page.size.rows } else { 12 })
	visible := context.begin_rows_child('##page_rows', visible_rows)
	defer {
		context.end_child()
	}
	if !visible || !context.begin_table('##page_rows_table', 10, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_scroll_freeze(0, 1)
	for label in ['Row', 'Text', 'Dirty', 'Wrap', 'Cont', 'Styled', 'Grapheme', 'Link', 'Prompt',
		'Kitty'] {
		context.table_setup_column(label, cimgui.table_column_width_fixed, 0)
	}
	context.table_headers_row()
	for row_index in 0 .. int(page.size.rows) {
		row := &page.rows[row_index]
		mut text_cells := 0
		for cell in page.get_cells(row) {
			if cell.has_text() {
				text_cells++
			}
		}
		context.table_next_row()
		context.table_set_column(0)
		context.text(row_index.str())
		context.table_set_column(1)
		if text_cells == 0 {
			context.text_disabled('0')
		} else {
			context.text(text_cells.str())
		}
		context.table_set_column(2)
		flag_cell(context, row.header.dirty)
		context.table_set_column(3)
		flag_cell(context, row.header.wrap)
		context.table_set_column(4)
		flag_cell(context, row.header.wrap_continuation)
		context.table_set_column(5)
		flag_cell(context, row.header.styled)
		context.table_set_column(6)
		flag_cell(context, row.header.grapheme)
		context.table_set_column(7)
		flag_cell(context, row.header.hyperlink)
		context.table_set_column(8)
		context.text(row.header.semantic_prompt.str())
		context.table_set_column(9)
		flag_cell(context, row.header.kitty_virtual_placeholder)
	}
}

fn styles_list(context cimgui.Context, page &terminal.Page) {
	items := page.styles.items()
	mut count := 0
	for index, item in items {
		if index > 0 && item.meta.ref_count > 0 {
			count++
		}
	}
	if count == 0 {
		context.text_disabled('(no styles in use)')
		return
	}
	visible_rows := u32(if count < 8 { count } else { 8 })
	visible := context.begin_rows_child('##page_styles', visible_rows)
	defer {
		context.end_child()
	}
	if !visible || !context.begin_table('##page_styles_table', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_scroll_freeze(0, 1)
	context.table_setup_column('ID', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Refs', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Style', cimgui.table_column_width_stretch, 0)
	context.table_headers_row()
	for index, item in items {
		if index == 0 || item.meta.ref_count == 0 {
			continue
		}
		context.table_next_row()
		context.push_id_int(index)
		context.table_set_column(0)
		context.text(index.str())
		context.table_set_column(1)
		context.text(item.meta.ref_count.str())
		context.table_set_column(2)
		if context.tree_node('Details') {
			table(context, item.value, [256]terminal.RGB{}, false)
			context.tree_pop()
		}
		context.pop_id()
	}
}

fn hyperlinks_list(context cimgui.Context, page &terminal.Page) {
	count := page.hyperlink_set.count()
	if count == 0 {
		context.text_disabled('(no hyperlinks in use)')
		return
	}
	visible_rows := u32(if count < 8 { count } else { 8 })
	visible := context.begin_rows_child('##page_hyperlinks', visible_rows)
	defer {
		context.end_child()
	}
	if !visible || !context.begin_table('##page_hyperlinks_table', 4, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_scroll_freeze(0, 1)
	context.table_setup_column('ID', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Refs', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Explicit ID', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('URI', cimgui.table_column_width_stretch, 0)
	context.table_headers_row()
	capacity := page.hyperlink_set.capacity()
	for raw_id in 1 .. int(capacity) + 1 {
		id := terminal.HyperlinkId(raw_id)
		refs := page.hyperlink_set.ref_count(id)
		if refs == 0 {
			continue
		}
		link := page.hyperlink_set.get(id)
		context.table_next_row()
		context.table_set_column(0)
		context.text(raw_id.str())
		context.table_set_column(1)
		context.text(refs.str())
		context.table_set_column(2)
		match link.id {
			terminal.HyperlinkExplicitId { context.text(link.id.value) }
			terminal.HyperlinkImplicitId { context.text_disabled('-') }
		}
		context.table_set_column(3)
		context.text(link.uri)
	}
}

fn flag_cell(context cimgui.Context, value bool) {
	if value {
		context.text_colored(cimgui.Color{ r: 0.4, g: 0.9, b: 0.4 }, 'yes')
	} else {
		context.text_disabled('-')
	}
}
