module inspector

import cimgui
import terminal

pub struct CellChooser {
mut:
	lookup_region terminal.PointTag = .viewport
	lookup_coord  terminal.Coordinate
}

pub fn (mut self CellChooser) draw(context cimgui.Context, pages &terminal.Pages) {
	context.text_wrapped('Inspect a cell by choosing a coordinate space and entering the X/Y position. The inspector resolves the point into the page list and displays the cell contents.')
	context.separator_text('Cell Inspector')

	region_max := flat_max_coord(pages, self.lookup_region)
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
	pin := pages.pin(terminal.PinOpts{
		tag: self.lookup_region
		x: self.lookup_coord.x
		y: self.lookup_coord.y
	}) or {
		context.text_disabled('(cell out of range)')
		return
	}
	row := pages.screen_rows[int(pin.y)]
	cell := row.cells[int(pin.x)]
	draw_cell_info(context, cell, row, self.lookup_coord, pin)

	if cell.style_id != terminal.default_style_id {
		context.separator_text('Style')
		table(context, cell.style, [256]terminal.RGB{}, false)
	}
	if cell.has_hyperlink {
		context.separator_text('Hyperlink')
		draw_cell_hyperlink(context, cell, pages)
	}
	if cell.has_grapheme {
		context.separator_text('Grapheme')
		draw_cell_grapheme(context, cell.graphemes)
	}
}

fn flat_max_coord(pages &terminal.Pages, tag terminal.PointTag) ?terminal.Coordinate {
	bottom_right := pages.get_bottom_right(tag) or { return none }
	return flat_coord_from_pin(pages, tag, bottom_right)
}

fn flat_coord_from_pin(pages &terminal.Pages, tag terminal.PointTag, pin terminal.Pin) terminal.Coordinate {
	y := match tag {
		.active { pin.y - u32(pages.active_start) }
		.viewport { pin.y - u32(pages.viewport_start) }
		.screen, .history { pin.y }
	}
	return terminal.Coordinate{ x: u16(pin.x), y: y }
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
	codepoint := cell.codepoint_val()
	if codepoint == 0 {
		context.text_disabled('(empty)')
	} else {
		context.text('U+${codepoint:04X}')
	}

	if cell.has_grapheme {
		context.table_next_row()
		context.table_set_column(0)
		context.text('Grapheme')
		context.table_set_column(1)
		context.help_marker('Extra codepoints that combine with the primary codepoint to form the grapheme cluster.')
		context.table_set_column(2)
		draw_codepoint_list(context, '##cell_grapheme', cell.graphemes)
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
		draw_cell_info_row(context, 'Hyperlink', 'OSC8 hyperlink ID associated with this cell.', 'id=${flat_hyperlink_id(cell.hyperlink)}')
	}
}

fn flat_hyperlink_id(link terminal.Hyperlink) string {
	return match link.id {
		terminal.HyperlinkImplicitId { link.id.offset.str() }
		terminal.HyperlinkExplicitId { link.id.value }
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

fn draw_cell_hyperlink(context cimgui.Context, cell terminal.CellData, pages &terminal.Pages) {
	if !context.begin_table('cell_hyperlink', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	mut id := ''
	match cell.hyperlink.id {
		terminal.HyperlinkImplicitId {
			id = 'implicit ${cell.hyperlink.id.offset}'
		}
		terminal.HyperlinkExplicitId {
			id = if cell.hyperlink.id.value.len == 0 { '(empty)' } else { cell.hyperlink.id.value }
		}
	}
	draw_screen_row(context, 'ID', id)
	draw_screen_row(context, 'URI', if cell.hyperlink.uri.len == 0 {
		'(empty)'
	} else {
		cell.hyperlink.uri
	})
	mut refs := 0
	for row in pages.screen_rows {
		for candidate in row.cells {
			if candidate.has_hyperlink && candidate.hyperlink.eql(&cell.hyperlink) {
				refs++
			}
		}
	}
	draw_screen_row(context, 'Ref Count', refs.str())
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

fn draw_pagelist_inspector(context cimgui.Context, mut pages terminal.Pages) {
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
		context.text_disabled('(no tracked pins)')
	}
	if context.collapsing_header_default_open('Pages') {
		context.help_marker('Pages are shown most-recent first. Each page holds a grid of rows/cells plus metadata tables for styles, graphemes, strings, and hyperlinks.')
		context.push_id_int(0)
		if context.tree_node('Page 0') {
			draw_flat_page_inspector(context, pages)
			context.tree_pop()
		}
		context.pop_id()
	}
}

fn draw_pagelist_summary(context cimgui.Context, pages &terminal.Pages) {
	if !context.begin_table('pagelist_summary', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	draw_pagelist_info_row(context, 'Active Grid', 'Active viewport size in columns x rows.', '${pages.cols}c x ${pages.rows}r')
	draw_pagelist_info_row(context, 'Pages', 'Total number of pages in the linked list.', '1')
	draw_pagelist_info_row(context, 'Total Rows', 'Total rows represented by scrollback + active area.', pages.screen_rows.len.str())
	page_bytes := flat_page_bytes(pages)
	draw_pagelist_info_row(context, 'Page Bytes', 'Total bytes allocated for active pages.', '${to_kibi_bytes(page_bytes)} KiB')
	max_bytes := flat_page_max_bytes(pages)
	draw_pagelist_info_row(context, 'Max Size', 'Maximum bytes before pages must be evicted. The next allocation that would exceed this limit evicts rows from the front to free space.', '${to_kibi_bytes(max_bytes)} KiB')
	draw_pagelist_info_row(context, 'Viewport', 'Current viewport anchoring mode.', pages.viewport.str())
	draw_pagelist_info_row(context, 'Tracked Pins', 'Number of pins tracked for automatic updates.', '0')
}

fn draw_pagelist_scrollbar(context cimgui.Context, mut pages terminal.Pages) {
	scrollbar := pages.scrollbar()
	if scrollbar.total > 0 {
		delta := context.pagelist_scrollbar(scrollbar.total, scrollbar.offset, scrollbar.len)
		if delta != 0 {
			pages.scroll_delta(int(delta))
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

fn draw_pagelist_regions(context cimgui.Context, pages &terminal.Pages) {
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

fn draw_pagelist_region(context cimgui.Context, pages &terminal.Pages, tag terminal.PointTag) {
	top_left := pages.get_top_left(tag)
	bottom_right := pages.get_bottom_right(tag)
	context.table_next_row()
	context.table_set_column(0)
	context.text(tag.str())
	context.table_set_column(1)
	context.help_marker(region_help_text(tag))
	context.table_set_column(2)
	top_left_coord := flat_coord_from_pin(pages, tag, top_left)
	context.text('(${top_left_coord.x}, ${top_left_coord.y})')
	context.table_set_column(3)
	if bottom := bottom_right {
		bottom_coord := flat_coord_from_pin(pages, tag, bottom)
		context.text('(${bottom_coord.x}, ${bottom_coord.y})')
	} else {
		context.text_disabled('(empty)')
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

fn draw_flat_page_inspector(context cimgui.Context, pages &terminal.Pages) {
	context.separator_text('Managed Memory')
	draw_flat_page_memory(context, pages)
	context.separator_text('Styles')
	draw_flat_styles(context, pages)
	context.separator_text('Hyperlinks')
	draw_flat_hyperlinks(context, pages)
	context.separator_text('Rows')
	draw_flat_rows(context, pages)
}

fn draw_flat_page_memory(context cimgui.Context, pages &terminal.Pages) {
	if context.begin_table('##overview', 3, cimgui.table_flags_inner_v_row_bg_sizing_fixed_fit) {
		draw_pagelist_info_row(context, 'Memory Size', 'Memory allocated for this page. Note the backing memory may be a larger allocation from which this page uses a portion.', '${to_kibi_bytes(flat_page_bytes(pages))} KiB')
		context.end_table()
	}
	styles := flat_style_usages(pages)
	links := flat_hyperlink_usages(pages)
	mut graphemes := 0
	mut grapheme_capacity := 0
	mut string_bytes := 0
	mut hyperlink_cells := 0
	for row in pages.screen_rows {
		for cell in row.cells {
			graphemes += cell.graphemes.len
			grapheme_capacity += cell.graphemes.cap
			if cell.has_hyperlink {
				hyperlink_cells++
				string_bytes += cell.hyperlink.uri.len
				if cell.hyperlink.id is terminal.HyperlinkExplicitId {
					string_bytes += cell.hyperlink.id.value.len
				}
			}
		}
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
	draw_managed_row(context, 'Columns', 'Number of columns in the terminal grid.', pages.cols, pages.cols)
	draw_managed_row(context, 'Rows', 'Number of rows in this page.', u32(pages.screen_rows.len), u32(pages.screen_rows.cap))
	draw_managed_row(context, 'Styles', 'Unique text styles (colors, attributes) currently in use.', u32(styles.len), u32(styles.cap))
	draw_managed_row(context, 'Graphemes', 'Extended grapheme clusters for multi-codepoint characters.', u32(graphemes), u32(grapheme_capacity))
	draw_managed_row(context, 'Strings (bytes)', 'String storage for hyperlink URIs and other text data.', u32(string_bytes), u32(string_bytes))
	draw_managed_row(context, 'Hyperlink Map', 'Maps cell positions to hyperlink IDs.', u32(hyperlink_cells), u32(hyperlink_cells))
	draw_managed_row(context, 'Hyperlink IDs', 'Unique hyperlink definitions (URI + optional ID).', u32(links.len), u32(links.cap))
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

struct FlatStyleUsage {
	style terminal.CellStyle
mut:
	refs int
}

fn flat_style_usages(pages &terminal.Pages) []FlatStyleUsage {
	mut result := []FlatStyleUsage{}
	for row in pages.screen_rows {
		for cell in row.cells {
			if cell.style_id == terminal.default_style_id {
				continue
			}
			mut found := false
			for mut item in result {
				if item.style.eql(&cell.style) {
					item.refs++
					found = true
					break
				}
			}
			if !found {
				result << FlatStyleUsage{ style: cell.style, refs: 1 }
			}
		}
	}
	return result
}

fn draw_flat_styles(context cimgui.Context, pages &terminal.Pages) {
	styles := flat_style_usages(pages)
	if styles.len == 0 {
		context.text_disabled('(no styles in use)')
		return
	}
	visible_rows := u32(if styles.len < 8 { styles.len } else { 8 })
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
	for index, item in styles {
		context.table_next_row()
		context.push_id_int(index)
		context.table_set_column(0)
		context.text('${index + 1}')
		context.table_set_column(1)
		context.text(item.refs.str())
		context.table_set_column(2)
		if context.tree_node('Details') {
			table(context, item.style, [256]terminal.RGB{}, false)
			context.tree_pop()
		}
		context.pop_id()
	}
}

struct FlatHyperlinkUsage {
	link terminal.Hyperlink
mut:
	refs int
}

fn flat_hyperlink_usages(pages &terminal.Pages) []FlatHyperlinkUsage {
	mut result := []FlatHyperlinkUsage{}
	for row in pages.screen_rows {
		for cell in row.cells {
			if !cell.has_hyperlink {
				continue
			}
			mut found := false
			for mut item in result {
				if item.link.eql(&cell.hyperlink) {
					item.refs++
					found = true
					break
				}
			}
			if !found {
				result << FlatHyperlinkUsage{ link: cell.hyperlink, refs: 1 }
			}
		}
	}
	return result
}

fn draw_flat_hyperlinks(context cimgui.Context, pages &terminal.Pages) {
	links := flat_hyperlink_usages(pages)
	if links.len == 0 {
		context.text_disabled('(no hyperlinks in use)')
		return
	}
	visible_rows := u32(if links.len < 8 { links.len } else { 8 })
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
	for index, item in links {
		context.table_next_row()
		context.table_set_column(0)
		context.text('${index + 1}')
		context.table_set_column(1)
		context.text(item.refs.str())
		context.table_set_column(2)
		match item.link.id {
			terminal.HyperlinkExplicitId { context.text(item.link.id.value) }
			terminal.HyperlinkImplicitId { context.text_disabled('-') }
		}
		context.table_set_column(3)
		context.text(item.link.uri)
	}
}

fn draw_flat_rows(context cimgui.Context, pages &terminal.Pages) {
	visible_rows := u32(if pages.screen_rows.len < 12 { pages.screen_rows.len } else { 12 })
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
	for index, row in pages.screen_rows {
		mut text_cells := 0
		for cell in row.cells {
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

fn flat_page_bytes(pages &terminal.Pages) usize {
	return usize(pages.screen_rows.len) * usize(pages.cols) * sizeof(terminal.CellData)
}

fn flat_page_max_bytes(pages &terminal.Pages) usize {
	return usize(pages.rows + pages.max_scrollback) * usize(pages.cols) * sizeof(terminal.CellData)
}
