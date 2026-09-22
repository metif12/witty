module shaper

import font

fn test_web_canvas_iterator_routes_to_web_canvas_state() {
	mut shaper := WebCanvasShaper.init(font.ShaperOptions{}) or { panic(err) }
	defer { shaper.deinit() }
	mut iterator := shaper.run_iterator(font.RunOptions{
		cells: [u8(`A`), `B`]
	})
	run := (iterator.next()!).get() or { panic('expected a run') }
	assert run.cells == 2
	assert shaper.run_codepoints == [
		WebCanvasCodepoint{ codepoint: u32(`A`), cluster: 0 },
		WebCanvasCodepoint{ codepoint: u32(`B`), cluster: 1 },
	]
}

fn test_web_canvas_shape_single_codepoints() {
	mut shaper := WebCanvasShaper.init(font.ShaperOptions{}) or { panic(err) }
	defer { shaper.deinit() }
	shaper.run_codepoints = [
		WebCanvasCodepoint{ codepoint: u32(`A`), cluster: 0 },
		WebCanvasCodepoint{ codepoint: u32(`B`), cluster: 1 },
	]
	cells := shaper.shape(font.TextRun{}) or { panic(err) }
	assert cells == [
		font.ShapeCell{ x: 0, glyph_index: u32(`A`) },
		font.ShapeCell{ x: 1, glyph_index: u32(`B`) },
	]
}

fn test_web_canvas_shape_graphemes() {
	mut face := font.WebCanvasFace{
		presentation: .emoji
	}
	defer { face.deinit() }
	mut shaper := WebCanvasShaper.init(font.ShaperOptions{}) or { panic(err) }
	defer { shaper.deinit() }
	shaper.run_codepoints = [
		WebCanvasCodepoint{ codepoint: 0x1f469, cluster: 0 },
		WebCanvasCodepoint{ codepoint: 0x1f3fd, cluster: 0 },
		WebCanvasCodepoint{ codepoint: 0x200d, cluster: 0 },
		WebCanvasCodepoint{ codepoint: 0x1f4bb, cluster: 0 },
		WebCanvasCodepoint{ codepoint: u32(`X`), cluster: 2 },
	]
	cells := shaper.shape(font.TextRun{
		web_canvas_face: &face
	}) or { panic(err) }
	assert cells.len == 2
	assert cells[0].x == 0
	assert cells[0].glyph_index == font.web_canvas_grapheme_start
	assert cells[1] == font.ShapeCell{ x: 2, glyph_index: u32(`X`) }
	assert face.glyph_to_grapheme[cells[0].glyph_index].bytestr() == '👩🏽‍💻'
}

fn test_web_canvas_shape_requires_face_for_grapheme() {
	mut shaper := WebCanvasShaper.init(font.ShaperOptions{}) or { panic(err) }
	defer { shaper.deinit() }
	shaper.run_codepoints = [
		WebCanvasCodepoint{ codepoint: u32(`n`), cluster: 0 },
		WebCanvasCodepoint{ codepoint: 0x0303, cluster: 0 },
	]
	if _ := shaper.shape(font.TextRun{}) {
		assert false, 'a multi-codepoint grapheme without its rendering face must fail'
	} else {
		assert err.msg().contains('no face')
	}
}

fn test_web_canvas_shaper_wasm_capacity_and_free() {
	shaper := shaper_new(17) or {
		assert false, 'shaper_new must allocate the requested cell buffer'
		return
	}
	assert shaper.cell_buf.len == 0
	assert shaper.cell_buf.cap >= 17
	shaper_free(shaper)
	shaper_free(none)
}
