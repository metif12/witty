module inspector

import cimgui
import terminal

pub struct CellChooser {
mut:
	lookup_region terminal.PointTag = .viewport
	lookup_coord  terminal.Coordinate
}

pub fn (mut self CellChooser) draw(context cimgui.Context, pages &terminal.PageList) {
	context.text_wrapped('Inspect a cell by choosing a coordinate space and entering the X/Y position. The inspector resolves the point into the page list and displays the cell contents.')
	context.separator_text('Cell Inspector')

	region_max := max_coord(pages, self.lookup_region)
	if maximum := region_max {
		if self.lookup_coord.x > maximum.x {
			self.lookup_coord.x = maximum.x
		}
		if self.lookup_coord.y > maximum.y {
			self.lookup_coord.y = maximum.y
		}
	} else {
		self.lookup_coord = terminal.Coordinate{}
	}

	context.begin_disabled(region_max == none)
	context.set_next_item_width_for_text('XXXXXXXXXXXX')
	if context.begin_combo('##grid_region', self.lookup_region.str()) {
		for tag in [terminal.PointTag.active, .viewport, .screen, .history] {
			selected := tag == self.lookup_region
			if context.selectable(tag.str(), selected) {
				self.lookup_region = tag
			}
			if selected {
				context.set_item_default_focus()
			}
		}
		context.end_combo()
	}
	context.same_line()
	context.align_text_to_frame_padding()
	context.text('x:')
	context.same_line()
	context.set_next_item_width_for_text('00000')
	mut changed, mut x_value := context.input_u16('##grid_x', self.lookup_coord.x)
	context.same_line()
	context.align_text_to_frame_padding()
	context.text('y:')
	context.same_line()
	context.set_next_item_width_for_text('00000')
	mut y_changed, mut y_value := context.input_u32('##grid_y', self.lookup_coord.y)
	changed = changed || y_changed
	context.same_line()
	context.help_marker('Choose the coordinate space and X/Y position (0-indexed).')
	if changed {
		if maximum := region_max {
			self.lookup_coord.x = if x_value > maximum.x { maximum.x } else { x_value }
			self.lookup_coord.y = if y_value > maximum.y { maximum.y } else { y_value }
		}
	}
	context.end_disabled()

	maximum := region_max or {
		context.text_disabled('(region has no rows)')
		return
	}
	context.text_disabled('Range: x 0..${maximum.x}, y 0..${maximum.y}')
	pin := pages.pin(terminal.Point{
		tag:        self.lookup_region
		coordinate: self.lookup_coord
	}) or {
		context.text_disabled('(cell out of range)')
		return
	}
	rac := pin.row_and_cell()
	cell := *rac.cell
	draw_cell_info(context, cell, *rac.row, self.lookup_coord, pin)

	if cell.style_id != terminal.default_style_id {
		context.separator_text('Style')
		table(context, pin.style(rac.cell), [256]terminal.RGB{}, false)
	}
	if cell.has_hyperlink {
		context.separator_text('Hyperlink')
		draw_cell_hyperlink(context, pin, rac.cell)
	}
	if cell.has_grapheme() {
		context.separator_text('Grapheme')
		draw_cell_grapheme(context, pin.grapheme(rac.cell) or { []u32{} })
	}
}

fn max_coord(pages &terminal.PageList, tag terminal.PointTag) ?terminal.Coordinate {
	bottom_right := pages.get_bottom_right(tag) or { return none }
	return (pages.point_from_pin(tag, bottom_right) or { return none }).coordinate
}

fn draw_cell_info(context cimgui.Context, cell terminal.CellData, row terminal.RowData, coord terminal.Coordinate, pin terminal.Pin) {
	if !context.begin_table('cell_info', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	draw_cell_info_row(context, 'Grid Position', "The cell's X/Y coordinates in the selected region.", '(${coord.x}, ${coord.y})')
	draw_cell_info_row(context, 'Page Location', 'Row and column indices within the backing page.', 'row=${pin.y} col=${pin.x}')
	draw_cell_info_row(context, 'Content', 'Content tag describing how the cell data is stored.', cell.content_tag.str())
	context.table_next_row()
	context.table_set_column(0)
	context.text('Codepoint')
	context.table_set_column(1)
	context.help_marker('Primary Unicode codepoint for the cell.')
	context.table_set_column(2)
	codepoint := cell.codepoint()
	if codepoint == 0 {
		context.text_disabled('(empty)')
	} else {
		context.text('U+${codepoint:04X}')
	}

	if cell.has_grapheme() {
		context.table_next_row()
		context.table_set_column(0)
		context.text('Grapheme')
		context.table_set_column(1)
		context.help_marker('Extra codepoints that combine with the primary codepoint to form the grapheme cluster.')
		context.table_set_column(2)
		draw_codepoint_list(context, '##cell_grapheme', pin.grapheme(&cell) or { []u32{} })
	}
	draw_cell_info_row(context, 'Width Property', 'Character width property (narrow, wide, spacer, etc.).', cell.wide.str())

	context.table_next_row()
	context.table_set_column(0)
	context.text('Row Flags')
	context.table_set_column(1)
	context.help_marker('Flags set on the row containing this cell.')
	context.table_set_column(2)
	draw_row_flags(context, row)
	draw_cell_info_row(context, 'Style ID', 'Internal style reference ID for this cell.', cell.style_id.str())
	draw_cell_info_row(context, 'Style', 'Resolved style for the cell (colors, attributes, etc.).', if cell.style_id == terminal.default_style_id {
		'(default)'
	} else {
		'(see below)'
	})
	if cell.has_hyperlink {
		mut page := &pin.node.data
		link_id := page.lookup_hyperlink(pin.row_and_cell().cell) or { terminal.HyperlinkId(0) }
		draw_cell_info_row(context, 'Hyperlink', 'OSC8 hyperlink ID associated with this cell.', 'id=${link_id}')
	}
}

fn draw_cell_info_row(context cimgui.Context, label string, help string, value string) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.table_set_column(1)
	context.help_marker(help)
	context.table_set_column(2)
	if value in ['(default)', '(see below)'] {
		context.text_disabled(value)
	} else {
		context.text(value)
	}
}

fn draw_row_flags(context cimgui.Context, row terminal.RowData) {
	if !row.wrap && !row.wrap_continuation && !row.grapheme && !row.styled && !row.hyperlink {
		context.text_disabled('(none)')
		return
	}
	draw_inline_flag(context, row.wrap, 'wrap', cimgui.Color{ r: 0.4, g: 0.8, b: 1.0 })
	draw_inline_flag(context, row.wrap_continuation, 'cont', cimgui.Color{ r: 0.4, g: 0.8, b: 1.0 })
	draw_inline_flag(context, row.grapheme, 'grapheme', cimgui.Color{ r: 0.9, g: 0.7, b: 0.3 })
	draw_inline_flag(context, row.styled, 'styled', cimgui.Color{ r: 0.7, g: 0.9, b: 0.5 })
	draw_inline_flag(context, row.hyperlink, 'link', cimgui.Color{ r: 0.8, g: 0.6, b: 1.0 })
}

fn draw_inline_flag(context cimgui.Context, enabled bool, label string, color cimgui.Color) {
	if !enabled {
		return
	}
	context.text_colored(color, label)
	context.same_line()
}

fn draw_cell_hyperlink(context cimgui.Context, pin terminal.Pin, cell &terminal.CellData) {
	mut page := &pin.node.data
	link_id := page.lookup_hyperlink(cell) or {
		context.text_disabled('(missing link data)')
		return
	}
	entry := page.hyperlink_set.get(link_id)
	if !context.begin_table('cell_hyperlink', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	mut id := ''
	match entry.id {
		terminal.HyperlinkImplicitId {
			id = 'implicit ${entry.id.offset}'
		}
		terminal.HyperlinkExplicitId {
			id = if entry.id.value.len == 0 { '(empty)' } else { entry.id.value }
		}
	}
	draw_screen_row(context, 'ID', id)
	draw_screen_row(context, 'URI', if entry.uri.len == 0 {
		'(empty)'
	} else {
		entry.uri
	})
	draw_screen_row(context, 'Ref Count', page.hyperlink_set.ref_count(link_id).str())
}

fn draw_cell_grapheme(context cimgui.Context, codepoints []u32) {
	if !context.begin_table('cell_grapheme', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_next_row()
	context.table_set_column(0)
	context.text('Extra Codepoints')
	context.table_set_column(1)
	if codepoints.len == 0 {
		context.text_disabled('(none)')
		return
	}
	draw_codepoint_list(context, '##grapheme_list', codepoints)
}

fn draw_codepoint_list(context cimgui.Context, label string, codepoints []u32) {
	if !context.begin_list_box(label) {
		return
	}
	defer {
		context.end_list_box()
	}
	for codepoint in codepoints {
		context.selectable('U+${codepoint:X}', false)
	}
}

fn draw_pagelist_inspector(context cimgui.Context, mut pages terminal.PageList) {
	context.text_wrapped('PageList manages the backing pages that hold scrollback and the active terminal grid. Each page is a contiguous memory buffer with its own rows, cells, style set, grapheme map, and hyperlink storage.')
	if context.collapsing_header_default_open('Overview') {
		draw_pagelist_summary(context, pages)
	}
	if context.collapsing_header_default_open('Scrollbar & Regions') {
		context.separator_text('Scrollbar')
		draw_pagelist_scrollbar(context, mut pages)
		context.separator_text('Regions')
		draw_pagelist_regions(context, pages)
	}
	if context.collapsing_header_default_open('Tracked Pins') {
		draw_tracked_pins(context, pages)
	}
	if context.collapsing_header_default_open('Pages') {
		context.help_marker('Pages are shown most-recent first. Each page holds a grid of rows/cells plus metadata tables for styles, graphemes, strings, and hyperlinks.')

		active_pin := pages.get_top_left(.active)
		viewport_pin := pages.get_top_left(.viewport)

		mut row_offset := pages.total_rows
		mut index := pages.total_pages()
		mut node := pages.pages.last
		for {
			page_node := node or { break }
			node = page_node.prev
			page := &page_node.data
			row_offset -= usize(page.size.rows)
			index -= 1

			// We use our location as the ID so that even if reallocations
			// happen we remain open if we're open already.
			context.push_id_int(int(index))
			mut label := 'Page ${index} (rows ${row_offset}..${row_offset + usize(page.size.rows) - 1})'
			if voidptr(page_node) == voidptr(active_pin.node) {
				label += ' active'
			}
			if voidptr(page_node) == voidptr(viewport_pin.node) {
				label += ' viewport'
			}
			if context.tree_node(label) {
				draw_page_inspector(context, page)
				context.tree_pop()
			}
			context.pop_id()
		}
	}
}

fn draw_pagelist_summary(context cimgui.Context, pages &terminal.PageList) {
	if !context.begin_table('pagelist_summary', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	draw_pagelist_info_row(context, 'Active Grid', 'Active viewport size in columns x rows.', '${pages.cols}c x ${pages.rows}r')
	draw_pagelist_info_row(context, 'Pages', 'Total number of pages in the linked list.', pages.total_pages().str())
	draw_pagelist_info_row(context, 'Total Rows', 'Total rows represented by scrollback + active area.', pages.total_rows.str())
	draw_pagelist_info_row(context, 'Page Bytes', 'Total bytes allocated for active pages.', '${to_kibi_bytes(pages.page_size)} KiB')
	draw_pagelist_info_row(context, 'Max Size', 'Maximum bytes before pages must be evicted. The next allocation that would exceed this limit evicts rows from the front to free space.', '${to_kibi_bytes(pages.max_size())} KiB')
	draw_pagelist_info_row(context, 'Viewport', 'Current viewport anchoring mode.', pages.viewport.str())
	draw_pagelist_info_row(context, 'Tracked Pins', 'Number of pins tracked for automatic updates.', pages.count_tracked_pins().str())
}

fn draw_pagelist_scrollbar(context cimgui.Context, mut pages terminal.PageList) {
	scrollbar := pages.scrollbar()
	if scrollbar.total > 0 {
		delta := context.pagelist_scrollbar(scrollbar.total, scrollbar.offset, scrollbar.len)
		if delta != 0 {
			pages.scroll(terminal.PageScrollDeltaRow{
				delta: isize(delta)
			})
		}
	}
	if !context.begin_table('scrollbar_info', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	draw_pagelist_info_row(context, 'Total', 'Total number of scrollable rows including scrollback and active area.', scrollbar.total.str())
	draw_pagelist_info_row(context, 'Offset', 'Current scroll position as row offset from the top of scrollback.', scrollbar.offset.str())
	draw_pagelist_info_row(context, 'Length', 'Number of rows visible in the viewport.', scrollbar.len.str())
}

fn draw_pagelist_regions(context cimgui.Context, pages &terminal.PageList) {
	if !context.begin_table('pagelist_regions', 4, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_column('Region', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Top-Left', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Bottom-Right', cimgui.table_column_width_stretch, 0)
	context.table_headers_row()
	for tag in [terminal.PointTag.active, .viewport, .screen, .history] {
		draw_pagelist_region(context, pages, tag)
	}
}

fn draw_pagelist_region(context cimgui.Context, pages &terminal.PageList, tag terminal.PointTag) {
	top_left := pages.get_top_left(tag)
	bottom_right := pages.get_bottom_right(tag)
	context.table_next_row()
	context.table_set_column(0)
	context.text(tag.str())
	context.table_set_column(1)
	context.help_marker(region_help_text(tag))
	context.table_set_column(2)
	if top_left_point := pages.point_from_pin(tag, top_left) {
		context.text('(${top_left_point.coordinate.x}, ${top_left_point.coordinate.y})')
	} else {
		context.text_disabled('(empty)')
	}
	context.table_set_column(3)
	if bottom := bottom_right {
		if bottom_point := pages.point_from_pin(tag, bottom) {
			context.text('(${bottom_point.coordinate.x}, ${bottom_point.coordinate.y})')
			return
		}
	}
	context.text_disabled('(empty)')
}

fn draw_tracked_pins(context cimgui.Context, pages &terminal.PageList) {
	pins := pages.tracked_pins()
	if pins.len == 0 {
		context.text_disabled('(no tracked pins)')
		return
	}
	if !context.begin_table('tracked_pins', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_column('Pin', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Screen', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('State', cimgui.table_column_width_stretch, 0)
	context.table_headers_row()
	for index, pin in pins {
		context.table_next_row()
		context.table_set_column(0)
		context.text(index.str())
		context.table_set_column(1)
		if point := pages.point_from_pin(.screen, *pin) {
			context.text('(${point.coordinate.x}, ${point.coordinate.y})')
		} else {
			context.text_disabled('(none)')
		}
		context.table_set_column(2)
		if pin.garbage {
			context.text_disabled('garbage')
		} else {
			context.text('live')
		}
	}
}

fn region_help_text(tag terminal.PointTag) string {
	return match tag {
		.active {
			"The active area where a running program can jump the cursor and make changes. This is the 'editable' part of the screen. Bottom-right includes the full height of the screen, including rows that may not be written yet."
		}
		.viewport {
			'The visible viewport. If the user has scrolled, top-left changes. Bottom-right is the last written row from the top-left.'
		}
		.screen {
			"Top-left is the furthest back in scrollback history. Bottom-right is the last written row. Unlike 'active', this only contains written rows."
		}
		.history {
			"Same top-left as 'screen' but bottom-right is the line just before the top of 'active'. Contains only the scrollback history."
		}
	}
}

fn draw_pagelist_info_row(context cimgui.Context, label string, help string, value string) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.table_set_column(1)
	context.help_marker(help)
	context.table_set_column(2)
	context.text(value)
}

fn draw_page_inspector(context cimgui.Context, page &terminal.Page) {
	context.separator_text('Managed Memory')
	draw_page_memory(context, page)
	context.separator_text('Styles')
	draw_page_styles(context, page)
	context.separator_text('Hyperlinks')
	draw_page_hyperlinks(context, page)
	context.separator_text('Rows')
	draw_page_rows(context, page)
}

fn draw_page_memory(context cimgui.Context, page &terminal.Page) {
	layout := terminal.Page.layout(page.capacity)
	if context.begin_table('##overview', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		draw_pagelist_info_row(context, 'Memory Size', 'Memory allocated for this page. Note the backing memory may be a larger allocation from which this page uses a portion.', '${to_kibi_bytes(layout.total_size)} KiB')
		context.end_table()
	}
	if !context.begin_table('##managed', 4, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	for label in ['Resource', '', 'Used', 'Capacity'] {
		context.table_setup_column(label, cimgui.table_column_width_fixed, 0)
	}
	context.table_headers_row()
	draw_managed_row(context, 'Columns', 'Number of columns in the terminal grid.', u32(page.size.cols), u32(page.capacity.cols))
	draw_managed_row(context, 'Rows', 'Number of rows in this page.', u32(page.size.rows), u32(page.capacity.rows))
	draw_managed_row(context, 'Styles', 'Unique text styles (colors, attributes) currently in use.', u32(page.styles.count()), u32(page.capacity.styles))
	draw_managed_row(context, 'Graphemes', 'Extended grapheme clusters for multi-codepoint characters.', u32(page.grapheme_count()), u32(page.grapheme_capacity()))
	draw_managed_row(context, 'Strings (bytes)', 'String storage for hyperlink URIs and other text data.', u32(page.hyperlink_set.string_used()), u32(page.hyperlink_set.string_capacity()))
	draw_managed_row(context, 'Hyperlink Map', 'Maps cell positions to hyperlink IDs.', u32(page.hyperlink_count()), u32(page.hyperlink_capacity()))
	draw_managed_row(context, 'Hyperlink IDs', 'Unique hyperlink definitions (URI + optional ID).', u32(page.hyperlink_set.count()), u32(page.hyperlink_set.capacity()))
}

fn draw_managed_row(context cimgui.Context, label string, help string, used u32, capacity u32) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.table_set_column(1)
	context.help_marker(help)
	context.table_set_column(2)
	context.text(used.str())
	context.table_set_column(3)
	context.text(capacity.str())
}

fn draw_page_styles(context cimgui.Context, page &terminal.Page) {
	ids := page.styles.live_ids()
	if ids.len == 0 {
		context.text_disabled('(no styles in use)')
		return
	}
	visible_rows := u32(if ids.len < 8 { ids.len } else { 8 })
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
	for id in ids {
		context.table_next_row()
		context.push_id_int(int(id))
		context.table_set_column(0)
		context.text(id.str())
		context.table_set_column(1)
		context.text(page.styles.ref_count(id).str())
		context.table_set_column(2)
		if context.tree_node('Details') {
			table(context, page.styles.get(id), [256]terminal.RGB{}, false)
			context.tree_pop()
		}
		context.pop_id()
	}
}

fn draw_page_hyperlinks(context cimgui.Context, page &terminal.Page) {
	ids := page.hyperlink_set.live_ids()
	if ids.len == 0 {
		context.text_disabled('(no hyperlinks in use)')
		return
	}
	visible_rows := u32(if ids.len < 8 { ids.len } else { 8 })
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
	for id in ids {
		link := page.hyperlink_set.get(id)
		context.table_next_row()
		context.table_set_column(0)
		context.text(id.str())
		context.table_set_column(1)
		context.text(page.hyperlink_set.ref_count(id).str())
		context.table_set_column(2)
		match link.id {
			terminal.HyperlinkExplicitId { context.text(link.id.value) }
			terminal.HyperlinkImplicitId { context.text_disabled('-') }
		}
		context.table_set_column(3)
		context.text(link.uri)
	}
}

fn draw_page_rows(context cimgui.Context, page &terminal.Page) {
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
	for index in 0 .. int(page.size.rows) {
		row := page.rows[index]
		mut text_cells := 0
		for cell in row.cells[..int(page.size.cols)] {
			if cell.has_text() {
				text_cells++
			}
		}
		context.table_next_row()
		context.table_set_column(0)
		context.text(index.str())
		context.table_set_column(1)
		if text_cells == 0 {
			context.text_disabled('0')
		} else {
			context.text(text_cells.str())
		}
		context.table_set_column(2)
		draw_flag_cell(context, row.dirty)
		context.table_set_column(3)
		draw_flag_cell(context, row.wrap)
		context.table_set_column(4)
		draw_flag_cell(context, row.wrap_continuation)
		context.table_set_column(5)
		draw_flag_cell(context, row.styled)
		context.table_set_column(6)
		draw_flag_cell(context, row.grapheme)
		context.table_set_column(7)
		draw_flag_cell(context, row.hyperlink)
		context.table_set_column(8)
		context.text(row.semantic_prompt.str())
		context.table_set_column(9)
		draw_flag_cell(context, row.kitty_virtual_placeholder)
	}
}

fn draw_flag_cell(context cimgui.Context, value bool) {
	if value {
		context.text_colored(cimgui.Color{ r: 0.4, g: 0.9, b: 0.4 }, 'yes')
	} else {
		context.text_disabled('-')
	}
}
