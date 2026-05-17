module shaper

import font

fn test_run_iterator2_empty_cells_returns_none() {
	mut it := RunIterator2{
		opts: font.RunOptions{}
	}

	if _ := it.next() {
		assert false, 'expected empty iterator'
	}
}

fn test_run_iterator2_builds_fallback_run() {
	mut it := RunIterator2{
		opts: font.RunOptions{
			cells: [u8(`A`), `B`, `C`]
		}
	}

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
