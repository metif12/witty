module renderer

import terminal

fn overlay_for_grid(cols u32, rows u32, cell_width u32, cell_height u32) Overlay {
	return Overlay.init(Size{
		screen: ScreenSize{
			width: cols * cell_width
			height: rows * cell_height
		}
		cell: CellSize{
			width: cell_width
			height: cell_height
		}
	}) or { panic(err) }
}

fn overlay_pixel(overlay &Overlay, x int, y int) [4]u8 {
	idx := (y * int(overlay.width) + x) * 4
	return [overlay.pixels[idx], overlay.pixels[idx + 1], overlay.pixels[idx + 2],
		overlay.pixels[idx + 3]]!
}

fn test_overlay_rejects_dimensions_outside_source_raster_range() {
	Overlay.init(Size{
		screen: ScreenSize{
			width: u32(2147483648)
			height: 1
		}
	}) or {
		assert err.msg() == 'invalid dimensions for overlay'
		return
	}
	assert false, 'out-of-range overlay width should fail'
}

fn test_overlay_grid_rectangle_rejects_coordinate_overflow() {
	mut overlay := overlay_for_grid(1, 1, 1, 1)
	overlay.cell_size.width = 2
	overlay.highlight_grid_rect(usize(2147483647), 0, 1, 1, .hyperlink) or {
		assert err.msg() == 'overlay coordinate overflow'
		assert overlay.pixels == []u8{len: 4}
		return
	}
	assert false, 'out-of-range overlay coordinate should fail'
}

fn render_cell_with_hyperlink(active bool) terminal.RenderCell {
	return terminal.RenderCell{
		raw: terminal.CellData{
			has_hyperlink: active
		}
	}
}

fn test_overlay_highlights_contiguous_hyperlink_runs() {
	mut overlay := overlay_for_grid(4, 1, 10, 10)
	state := terminal.RenderState{
		row_data: [terminal.RenderRow{
			raw: terminal.RowData{ hyperlink: true }
			cells: [render_cell_with_hyperlink(false), render_cell_with_hyperlink(true),
				render_cell_with_hyperlink(true), render_cell_with_hyperlink(false)]
		}]
	}
	overlay.apply_features(&state, [.highlight_hyperlinks])

	assert overlay_pixel(&overlay, 5, 5)[3] == 0
	assert overlay_pixel(&overlay, 15, 5)[3] == 96
	assert overlay_pixel(&overlay, 25, 5)[3] == 96
	assert overlay_pixel(&overlay, 35, 5)[3] == 0
	assert overlay_pixel(&overlay, 10, 5)[3] == 200
	// z2d surfaces are premultiplied RGBA.
	assert overlay_pixel(&overlay, 15, 5)[0] == 68
}

fn test_overlay_joins_semantic_prompt_continuation_bars() {
	mut overlay := overlay_for_grid(2, 3, 10, 10)
	state := terminal.RenderState{
		row_data: [
			terminal.RenderRow{ raw: terminal.RowData{ semantic_prompt: .prompt } },
			terminal.RenderRow{ raw: terminal.RowData{ semantic_prompt: .prompt_continuation } },
			terminal.RenderRow{ raw: terminal.RowData{ semantic_prompt: .unknown } },
		]
	}
	overlay.apply_features(&state, [.semantic_prompts])

	assert overlay_pixel(&overlay, 2, 5)[3] == 96
	assert overlay_pixel(&overlay, 2, 15)[3] == 96
	assert overlay_pixel(&overlay, 2, 25)[3] == 0
}

fn semantic_render_cell(content terminal.SemanticContent) terminal.RenderCell {
	return terminal.RenderCell{
		raw: terminal.CellData{
			semantic_content: content
		}
	}
}

fn test_overlay_highlights_semantic_cells_but_skips_output() {
	mut overlay := overlay_for_grid(4, 1, 10, 10)
	state := terminal.RenderState{
		row_data: [terminal.RenderRow{
			cells: [semantic_render_cell(.output), semantic_render_cell(.prompt),
				semantic_render_cell(.prompt), semantic_render_cell(.input)]
		}]
	}
	overlay.apply_features(&state, [.semantic_prompts])

	assert overlay_pixel(&overlay, 5, 5)[3] == 0
	assert overlay_pixel(&overlay, 15, 5)[3] == 96
	assert overlay_pixel(&overlay, 25, 5)[3] == 96
	assert overlay_pixel(&overlay, 35, 5)[3] == 96
	// Prompt and input use distinct colors.
	assert overlay_pixel(&overlay, 15, 5) != overlay_pixel(&overlay, 35, 5)
}
