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
}

// Initialize a new page list search starting from the given node.
// The search proceeds in reverse order (towards older content).
pub fn PageListSearch.init(needle []u8, list &terminal.PageList, start &terminal.PageNode) PageListSearch {
	// Create a tracked pin at the start node pointing to the last row.
	mut mutable_list := unsafe { &terminal.PageList(list) }
	pin := mutable_list.track_pin(terminal.PagePin{
		node: unsafe { &terminal.PageNode(start) }
		y: u16(start.data.size.rows - 1)
		x: u16(start.data.size.cols - 1)
	})
	mut window := SlidingWindow.init(.reverse, needle)
	// Load the initial node while the caller already has safe access to the
	// page list. The tracked pin remains on this node and feed starts at prev.
	window.append(start)
	return PageListSearch{
		list: list
		window: window
		pin: pin
	}
}

// Free resources.
pub fn (mut self PageListSearch) deinit() {
	self.window.deinit()
	// Untrack the pin from the page list.
	mut mutable_list := unsafe { &terminal.PageList(self.list) }
	mutable_list.untrack_pin(self.pin)
}

// Search for the next match in the loaded data.
// This does not require any locks since it operates on already-loaded data.
pub fn (mut self PageListSearch) next() ?highlight.Flattened {
	return self.window.next()
}

// Feed the next page from the page list into the sliding window.
// Returns true if a page was fed, false if there are no more pages.
//
// The caller must hold the necessary locks to access the page list.
pub fn (mut self PageListSearch) feed() bool {
	if self.pin.garbage {
		return false
	}

	mut remaining := self.window.needle.len
	mut node := self.pin.node.prev
	for {
		current := node or { break }
		added := self.window.append(current)
		if added >= remaining {
			remaining = 0
		} else {
			remaining -= added
		}
		self.pin.node = current
		if remaining == 0 {
			break
		}
		node = current.prev
	}

	return remaining < self.window.needle.len
}
