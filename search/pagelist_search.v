module search

// PageListSearch searches the page list (scrollback history) using a
// sliding window in reverse order (newest to oldest). It feeds pages
// one at a time from the page list into the sliding window.
//
// Source: terminal/search/pagelist.zig
//
// XTODO: This is a stub. Full implementation requires PageList
// integration with tracked pins for the search position.

import terminal
import highlight

pub struct PageListSearch {
pub mut:
	// The page list being searched.
	list &terminal.PageList = unsafe { nil }

	// The sliding window used for reverse searching.
	window SlidingWindow

	// Tracked pin to the current search position in the page list.
	// This is tracked so it auto-updates if pages are modified.
	pin &terminal.PagePin = unsafe { nil }
}

// Initialize a new page list search starting from the given node.
// The search proceeds in reverse order (towards older content).
pub fn PageListSearch.init(needle []u8, list &terminal.PageList, start &terminal.PageNode) PageListSearch {
	// XTODO: Should create a tracked pin at the start node and
	// initialize a reverse sliding window.
	_ = start
	return PageListSearch{
		list: list
		window: SlidingWindow.init(.reverse, needle)
		pin: unsafe { &terminal.PagePin(nil) }
	}
}

// Free resources.
pub fn (mut self PageListSearch) deinit() {
	// XTODO: Should untrack the pin from the page list.
	self.window.deinit()
}

// Search for the next match in the loaded data.
// This does not require any locks since it operates on already-loaded data.
pub fn (mut self PageListSearch) next() ?highlight.FlattenedHighlight {
	return self.window.next()
}

// Feed the next page from the page list into the sliding window.
// Returns true if a page was fed, false if there are no more pages.
//
// The caller must hold the necessary locks to access the page list.
pub fn (mut self PageListSearch) feed() bool {
	// XTODO: Should:
	// 1. Get the previous node from the current pin position
	// 2. Append it to the sliding window
	// 3. Update the pin to point to the new position
	// 4. Return true if a node was appended, false if at the beginning
	return false
}
