module shaper

import font

fn test_run_iterator2_empty_cells_returns_none() {
	mut shaper := font.Shaper.init(font.ShaperOptions{}) or { panic(err) }
	defer {
		shaper.deinit()
	}
	mut it := RunIterator2.new(voidptr(&shaper), font.RunOptions{})

	if _ := it.next() {
		assert false, 'expected empty iterator'
	}
}

fn test_run_iterator2_builds_fallback_run() {
	mut shaper := font.Shaper.init(font.ShaperOptions{}) or { panic(err) }
	defer {
		shaper.deinit()
	}
	mut it := RunIterator2.new(voidptr(&shaper), font.RunOptions{
		cells: [u8(`A`), `B`, `C`]
	})

	run := it.next() or {
		assert false, 'expected a run'
		return
	}
	assert run.offset == 0
	assert run.cells == 3
	assert run.font_index == 0
	assert run.hash != 0

	if _ := it.next() {
		assert false, 'expected only one fallback run'
	}
}
