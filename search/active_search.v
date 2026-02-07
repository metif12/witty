module search

// ActiveSearch searches the active area of the terminal screen.
// It wraps a SlidingWindow configured for forward searching and
// handles updates when the active area changes.
//
// Source: terminal/search/active.zig
//
// XTODO: This is a stub. Full implementation requires PageList
// integration with the active area boundary tracking.

import terminal
import highlight

pub struct ActiveSearch {
pub mut:
	// The sliding window used for searching the active area.
	window SlidingWindow
}

// Initialize a new active area search.
pub fn ActiveSearch.init(needle []u8) ActiveSearch {
	return ActiveSearch{
		window: SlidingWindow.init(.forward, needle)
	}
}

// Free resources.
pub fn (mut self ActiveSearch) deinit() {
	self.window.deinit()
}

// Update the active area search with the current page list state.
// Returns the first page node of the overlap between the old and new
// active areas (the node that was previously the start of the active
// area), or none if there is no history to search.
//
// The caller must hold the necessary locks to access the page list.
pub fn (mut self ActiveSearch) update(list &terminal.PageList) ?&terminal.PageNode {
	// XTODO: Requires PageList active area boundary detection.
	// Should:
	// 1. Determine the current active area start node
	// 2. Clear the sliding window
	// 3. Append all active area page nodes to the window
	// 4. Return the first node if there's history before the active area
	_ = list
	return none
}

// Search for the next match in the active area.
pub fn (mut self ActiveSearch) next() ?highlight.FlattenedHighlight {
	return self.window.next()
}
