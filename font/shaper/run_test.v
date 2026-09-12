module shaper

import font

fn test_run_iterator2_empty_cells_returns_none() {
	mut shaper := font.Shaper.init(font.ShaperOptions{}) or { panic(err) }
	defer {
		shaper.deinit()
	}
	mut it := RunIterator2.new(voidptr(&shaper), font.RunOptions{})

	if _ := (it.next()!).get() {
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

	run := (it.next()!).get() or {
		assert false, 'expected a run'
		return
	}
	assert run.offset == 0
	assert run.cells == 3
	assert run.font_index == font.Index{}
	assert run.hash != 0

	if _ := (it.next()!).get() {
		assert false, 'expected only one fallback run'
	}
}

fn test_noop_run_iterator_uses_noop_hooks_and_options() {
	mut shaper := NoopShaper.init(font.ShaperOptions{})!
	defer { shaper.deinit() }
	mut it := shaper.run_iterator(font.RunOptions{
		cells: [u8(`A`), `B`]
	})

	run := (it.next()!).get() or { panic('expected a text run') }
	assert run.cells == 2
	assert shaper.run_state.codepoints == [
		NoopCodepoint{ codepoint: u32(`A`), cluster: 0 },
		NoopCodepoint{ codepoint: u32(`B`), cluster: 1 },
	]
}
