module terminal

import oniguruma

// Tests for StringMap.
// Translated from Ghostty's StringMap.zig tests.

fn test_string_map_basic() {
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	s.test_write_string('1ABCD2EFGH\n3IJKL') or {
		assert false, err.msg()
		return
	}
	line := s.select_line(SelectLine{ pin: Pin{ x: 2, y: 1 } }) or {
		assert false, 'expected line selection'
		return
	}
	mut smap := &StringMap{}
	_ = s.selection_string(SelectionString{ sel: line, trim: false, map: smap }) or {
		assert false, err.msg()
		return
	}
	mut regex := oniguruma.Regex.init('[A-B]{2}', oniguruma.Options{}, .utf8, .default_, none) or {
		assert false, err.msg()
		return
	}
	defer { regex.deinit() }
	mut it := smap.search_iterator(regex)
	next := it.next() or {
		assert false, err.msg()
		return
	}
	mut matched := next.get() or {
		assert false, 'expected match'
		return
	}
	defer { matched.deinit() }
	sel := matched.selection()
	assert sel.start() == Pin{ x: 1, y: 0 }
	assert sel.end() == Pin{ x: 2, y: 0 }
	assert (it.next()!).get() == none
}

fn test_string_map_search_iterator_url_detection() {
	mut s := Screen.init(40, 5, 0)
	defer { s.deinit() }
	s.test_write_string('hello https://example.com/path world') or {
		assert false, err.msg()
		return
	}
	line := s.select_line(SelectLine{ pin: Pin{ x: 10, y: 0 } }) or {
		assert false, 'expected line selection'
		return
	}
	mut smap := &StringMap{}
	_ = s.selection_string(SelectionString{ sel: line, trim: false, map: smap }) or {
		assert false, err.msg()
		return
	}
	mut regex := oniguruma.Regex.init(r'https?://[^ ]+', oniguruma.Options{}, .utf8, .default_, none) or {
		assert false, err.msg()
		return
	}
	defer { regex.deinit() }
	mut it := smap.search_iterator(regex)
	next := it.next() or {
		assert false, err.msg()
		return
	}
	mut matched := next.get() or {
		assert false, 'expected URL match'
		return
	}
	defer { matched.deinit() }
	sel := matched.selection()
	assert sel.start() == Pin{ x: 6, y: 0 }
	assert sel.end() == Pin{ x: 29, y: 0 }
	assert (it.next()!).get() == none
}

fn test_string_map_search_iterator_url_with_click() {
	mut s := Screen.init(40, 5, 0)
	defer { s.deinit() }
	s.test_write_string('hello https://example.com world') or {
		assert false, err.msg()
		return
	}
	click := Pin{ x: 14, y: 0 }
	line := s.select_line(SelectLine{ pin: click }) or {
		assert false, 'expected line selection'
		return
	}
	mut smap := &StringMap{}
	_ = s.selection_string(SelectionString{ sel: line, trim: false, map: smap }) or {
		assert false, err.msg()
		return
	}
	mut regex := oniguruma.Regex.init(r'https?://[^ ]+', oniguruma.Options{}, .utf8, .default_, none) or {
		assert false, err.msg()
		return
	}
	defer { regex.deinit() }
	mut it := smap.search_iterator(regex)
	mut found := false
	for {
		next := it.next() or { break }
		mut matched := next.get() or { break }
		sel := matched.selection()
		matched.deinit()
		if sel.contains(&s, click) {
			found = true
			assert sel.start() == Pin{ x: 6, y: 0 }
			assert sel.end() == Pin{ x: 24, y: 0 }
			break
		}
	}
	assert found
}
