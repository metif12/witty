module font

// Runtime coverage for the production shaper, cache, and byte-row adapter.

fn test_public_shaper_cache_get_put() {
	mut cache := ShaperCache.init()
	defer {
		cache.deinit()
	}

	run := TextRun{
		hash: 42
		cells: 2
	}
	if _ := cache.get(run) {
		assert false, 'expected cache miss before put'
	}

	mut cells := [
		ShapeCell{
			x: 0
			glyph_index: 65
		},
		ShapeCell{
			x: 1
			glyph_index: 66
		},
	]
	cache.put(run, cells)!
	cells[0] = ShapeCell{
		x: 9
		glyph_index: 99
	}

	got := cache.get(run) or {
		assert false, 'expected cache hit after put'
		return
	}
	assert got.len == 2
	assert got[0].x == 0
	assert got[0].glyph_index == 65
	assert got[1].x == 1
	assert got[1].glyph_index == 66
	assert cache.count() == 1
}

fn test_public_shaper_cache_evicts_least_recently_used_collision() {
	mut cache := ShaperCache.init()
	defer {
		cache.deinit()
	}

	for i in 0 .. 8 {
		cache.put(TextRun{ hash: u64(i * 256) }, [ShapeCell{ glyph_index: u32(i) }])!
	}
	assert cache.get(TextRun{ hash: 0 })?[0].glyph_index == 0
	cache.put(TextRun{ hash: 8 * 256 }, [ShapeCell{ glyph_index: 8 }])!

	assert cache.get(TextRun{ hash: 256 }) == none
	assert cache.get(TextRun{ hash: 0 })?[0].glyph_index == 0
	assert cache.get(TextRun{ hash: 8 * 256 })?[0].glyph_index == 8
	assert cache.count() == 8
}

fn test_public_shaper_identity_shape() {
	mut shaper := Shaper.init(ShaperOptions{})!
	defer { shaper.deinit() }
	shaper.codepoints = [
		ShaperCodepoint{ cluster: 0, codepoint: 65 },
		ShaperCodepoint{ cluster: 1, codepoint: 66 },
		ShaperCodepoint{ cluster: 2, codepoint: 67 },
	]
	cells := shaper.shape(TextRun{ hash: 1, font_index: sprite_index, cells: 3 })!

	assert cells.len == 3
	assert cells[0].x == 0
	assert cells[0].glyph_index == 65
	assert cells[1].x == 1
	assert cells[1].glyph_index == 66
	assert cells[2].x == 2
	assert cells[2].glyph_index == 67
}

fn test_public_run_iterator_yields_single_text_run() {
	mut shaper := Shaper.init(ShaperOptions{})!
	defer { shaper.deinit() }
	mut it := shaper.run_iterator(RunOptions{ cells: [u8(`A`), `B`, `C`] })
	run := it.next() or {
		assert false, 'expected one text run for non-empty cells'
		return
	}

	assert run.cells == 3
	assert run.offset == 0
	assert run.font_index == 0
	assert run.hash != 0
	if _ := it.next() {
		assert false, 'expected iterator to stop after one fallback run'
	}
}

fn test_public_run_iterator_hash_is_position_independent() {
	mut shaper := Shaper.init(ShaperOptions{})!
	defer { shaper.deinit() }

	mut first := shaper.run_iterator(RunOptions{ cells: [u8(`A`), `B`, `C`] })
	run1 := first.next() or { panic('expected first text run') }

	mut second := shaper.run_iterator(RunOptions{ cells: [u8(`X`), `A`, `B`, `C`] })
	second.i = 1
	run2 := second.next() or { panic('expected offset text run') }

	assert run1.offset == 0
	assert run2.offset == 1
	assert run1.cells == run2.cells
	assert run1.hash == run2.hash
}

fn test_public_run_iterator_hash_includes_length() {
	mut shaper := Shaper.init(ShaperOptions{})!
	defer { shaper.deinit() }

	mut short := shaper.run_iterator(RunOptions{ cells: [u8(`A`)] })
	short_run := short.next() or { panic('expected short text run') }
	mut long := shaper.run_iterator(RunOptions{ cells: [u8(`A`), `B`] })
	long_run := long.next() or { panic('expected long text run') }

	assert short_run.hash != long_run.hash
}
