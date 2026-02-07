module search

// PageListSearch searches the page list (scrollback history) using a
// sliding window in reverse order (newest to oldest). It feeds pages
// one at a time from the page list into the sliding window.
//
// Source: terminal/search/pagelist.zig

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

	// Whether we have exhausted the page list.
	exhausted bool
}

// Initialize a new page list search starting from the given node.
// The search proceeds in reverse order (towards older content).
pub fn PageListSearch.init(needle []u8, list &terminal.PageList, start &terminal.PageNode) PageListSearch {
	// Create a tracked pin at the start node pointing to the last row.
	mut mutable_list := unsafe { &terminal.PageList(list) }
	pin := mutable_list.track_pin(terminal.PagePin{
		node: unsafe { &terminal.PageNode(start) }
		y: u16(start.data.size.rows - 1)
		x: 0
	})
	return PageListSearch{
		list: list
		window: SlidingWindow.init(.reverse, needle)
		pin: pin
		exhausted: false
	}
}

// Free resources.
pub fn (mut self PageListSearch) deinit() {
	// Untrack the pin from the page list.
	if self.pin != unsafe { nil } {
		mut mutable_list := unsafe { &terminal.PageList(self.list) }
		mutable_list.untrack_pin(self.pin)
	}
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
	if self.exhausted {
		return false
	}

	// Get the current node from the pin.
	node := self.pin.node
	if node == unsafe { nil } {
		self.exhausted = true
		return false
	}

	// Append the current node to the sliding window.
	self.window.append(node)

	// Move the pin to the previous node in the list.
	if prev := node.prev {
		self.pin.node = prev
		self.pin.y = u16(prev.data.size.rows - 1)
		self.pin.x = 0
	} else {
		// No more previous nodes -- we have reached the beginning.
		self.exhausted = true
	}

	return true
}
