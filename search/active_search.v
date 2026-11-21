module search

// ActiveSearch searches the active area of the terminal screen.
// It wraps a SlidingWindow configured for forward searching and
// handles updates when the active area changes.
//
// Source: terminal/search/active.zig
//
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
	self.window.clear_and_retain_capacity()

	// Load the pages that cover the addressable active area, starting at the
	// newest page as in Ghostty's active searcher.
	mut remaining := uint(list.rows)
	mut node := list.pages.last
	mut first_active := ?&terminal.PageNode(none)
	for {
		current := node or { break }
		self.window.append(current)
		first_active = unsafe { &terminal.PageNode(current) }

		if remaining <= uint(current.data.size.rows) {
			node = current.prev
			break
		}
		remaining -= uint(current.data.size.rows)
		node = current.prev
	}

	// Include preceding soft-wrapped pages so a match that crosses the
	// history/active boundary remains discoverable.
	overlap_needed := self.window.needle.len - 1
	for {
		current := node or { break }
		if !current.data.get_row(uint(current.data.size.rows - 1)).header.wrap {
			break
		}
		added := self.window.append(current)
		if added >= overlap_needed {
			break
		}
		node = current.prev
	}

	return first_active
}

// Search for the next match in the active area.
pub fn (mut self ActiveSearch) next() ?highlight.Flattened {
	return self.window.next()
}
