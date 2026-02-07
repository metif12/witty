module shaper

import font

fn test_cache_init() {
	mut c := ShaperCache.init()
	defer { c.deinit() }

	assert c.count() == 0
}

fn test_cache_get_miss() {
	mut c := ShaperCache.init()
	defer { c.deinit() }

	run := font.TextRun{
		hash: 1
	}
	result := c.get(run)
	assert result == none
}

fn test_cache_put_and_get() {
	mut c := ShaperCache.init()
	defer { c.deinit() }

	run := font.TextRun{
		hash: 1
	}
	cells := [
		font.ShapeCell{ x: 0, glyph_index: 0 },
		font.ShapeCell{ x: 1, glyph_index: 1 },
	]
	c.put(run, cells)

	actual := c.get(run) or {
		assert false, 'expected cache hit'
		return
	}
	assert actual.len == 2
	assert actual[0].x == 0
	assert actual[0].glyph_index == 0
	assert actual[1].x == 1
	assert actual[1].glyph_index == 1
}

fn test_cache_put_overwrites() {
	mut c := ShaperCache.init()
	defer { c.deinit() }

	run := font.TextRun{
		hash: 42
	}

	// Put initial cells
	cells1 := [
		font.ShapeCell{ x: 0, glyph_index: 10 },
	]
	c.put(run, cells1)
	assert c.count() == 1

	// Put new cells for same hash
	cells2 := [
		font.ShapeCell{ x: 0, glyph_index: 20 },
		font.ShapeCell{ x: 1, glyph_index: 21 },
	]
	c.put(run, cells2)
	assert c.count() == 1

	actual := c.get(run) or {
		assert false, 'expected cache hit'
		return
	}
	assert actual.len == 2
	assert actual[0].glyph_index == 20
	assert actual[1].glyph_index == 21
}

fn test_cache_multiple_entries() {
	mut c := ShaperCache.init()
	defer { c.deinit() }

	run1 := font.TextRun{ hash: 1 }
	run2 := font.TextRun{ hash: 2 }
	run3 := font.TextRun{ hash: 3 }

	c.put(run1, [font.ShapeCell{ x: 0, glyph_index: 10 }])
	c.put(run2, [font.ShapeCell{ x: 0, glyph_index: 20 }])
	c.put(run3, [font.ShapeCell{ x: 0, glyph_index: 30 }])

	assert c.count() == 3

	a1 := c.get(run1) or {
		assert false, 'expected cache hit for run1'
		return
	}
	assert a1[0].glyph_index == 10

	a2 := c.get(run2) or {
		assert false, 'expected cache hit for run2'
		return
	}
	assert a2[0].glyph_index == 20

	a3 := c.get(run3) or {
		assert false, 'expected cache hit for run3'
		return
	}
	assert a3[0].glyph_index == 30
}

fn test_cache_clear_on_deinit() {
	mut c := ShaperCache.init()

	run := font.TextRun{ hash: 1 }
	c.put(run, [font.ShapeCell{ x: 0, glyph_index: 5 }])
	assert c.count() == 1

	c.deinit()
	assert c.count() == 0
}

fn test_cache_put_duplicates_cells() {
	mut c := ShaperCache.init()
	defer { c.deinit() }

	run := font.TextRun{ hash: 99 }
	mut cells := [
		font.ShapeCell{ x: 0, glyph_index: 42 },
	]
	c.put(run, cells)

	// Modify the original -- cache should not be affected
	cells[0] = font.ShapeCell{ x: 5, glyph_index: 99 }

	actual := c.get(run) or {
		assert false, 'expected cache hit'
		return
	}
	assert actual[0].x == 0
	assert actual[0].glyph_index == 42
}
