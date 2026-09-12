module search

// ViewportSearch searches for a substring within the viewport of a PageList.
//
// Source: terminal/search/viewport.zig
//
// This contains logic to efficiently detect when the viewport changes
// and only re-search when necessary.
//
// The specialization for "viewport" is because the viewport is the
// only part of the search where the user can actively see the results,
// usually. In that case, it is more efficient to re-search only the
// viewport rather than store all the results for the entire screen.
//
// Note that this searches all the pages that viewport covers, so
// this can include extra matches outside the viewport if the data
// lives in the same page.
//
import terminal
import highlight

// ============================================================
// ViewportSearch
// ============================================================

pub struct ViewportSearch {
pub mut:
	// The sliding window used for forward searching.
	window SlidingWindow

	// The viewport fingerprint for change detection.
	// When this is none, the next update will always re-search.
	fingerprint ?ViewportFingerprint

	// If this is none, then active dirty tracking is disabled and if the
	// viewport overlaps the active area we always re-search. If this is
	// non-null, then we only re-search if the active area is dirty. Dirty
	// marking is up to the caller.
	active_dirty ?bool
}

// Initialize a new viewport search.
pub fn ViewportSearch.init(needle []u8) ViewportSearch {
	// We just do a forward search since the viewport is usually
	// pretty small so search results are instant anyways. This avoids
	// a small amount of work to reverse things.
	return ViewportSearch{
		window: SlidingWindow.init(.forward, needle)
		fingerprint: none
		active_dirty: none
	}
}

// Free resources.
pub fn (mut self ViewportSearch) deinit() {
	self.fingerprint = none
	self.window.deinit()
}

// Reset our fingerprint and results so that the next update will
// always re-search.
pub fn (mut self ViewportSearch) reset() {
	self.fingerprint = none
	self.window.clear_and_retain_capacity()
}

// The needle that this search is using.
pub fn (self &ViewportSearch) needle() []u8 {
	assert self.window.direction == .forward, 'viewport search must be forward'
	return self.window.needle
}

// Update the sliding window to reflect the current viewport. This
// will do nothing if the viewport hasn't changed since the last
// search.
//
// The PageList must be safe to read throughout the lifetime of this
// function.
//
// Returns true if the viewport changed and a re-search is needed.
// Returns false if the viewport is unchanged.
pub fn (mut self ViewportSearch) update(list &terminal.PageList) bool {
	fingerprint := ViewportFingerprint.init(list)
	if fingerprint.nodes.len == 0 {
		self.reset()
		return true
	}

	if old := self.fingerprint {
		if old.eql(fingerprint) {
			mut check_active := true
			if dirty := self.active_dirty {
				check_active = dirty
				if dirty {
					self.active_dirty = false
				}
			}

			mut overlaps_active := false
			if check_active {
				active_tl := list.get_top_left(.active)
				if active_br := list.get_bottom_right(.active) {
					for node in old.nodes {
						if voidptr(node) == voidptr(active_tl.node)
							|| voidptr(node) == voidptr(active_br.node) {
							overlaps_active = true
							break
						}
					}
				}
			}
			if !overlaps_active {
				return false
			}
		}
	}

	self.fingerprint = fingerprint
	if self.active_dirty != none {
		self.active_dirty = false
	}
	self.window.clear_and_retain_capacity()

	overlap_needed := if self.window.needle.len > 0 { self.window.needle.len - 1 } else { 0 }
	mut node := fingerprint.nodes[0].prev
	mut added := 0
	for {
		current := node or { break }
		if current.data.size.rows == 0
			|| !current.data.get_row(usize(current.data.size.rows - 1)).wrap {
			break
		}
		added += self.window.append(current)
		if added >= overlap_needed {
			break
		}
		node = current.prev
	}

	for viewport_node in fingerprint.nodes {
		self.window.append(viewport_node)
	}

	end := fingerprint.nodes[fingerprint.nodes.len - 1]
	if end.data.size.rows > 0 && end.data.get_row(usize(end.data.size.rows - 1)).wrap {
		node = end.next
		added = 0
		for {
			current := node or { break }
			added += self.window.append(current)
			if added >= overlap_needed {
				break
			}
			if current.data.size.rows == 0
				|| !current.data.get_row(usize(current.data.size.rows - 1)).wrap {
				break
			}
			node = current.next
		}
	}

	return true
}

// Find the next match for the needle in the active area. This returns
// none when there are no more matches.
pub fn (mut self ViewportSearch) next() ?highlight.FlattenedHighlight {
	return self.window.next()
}

// ============================================================
// ViewportFingerprint - detects when the viewport moves
// ============================================================

// Viewport fingerprint so we can detect when the viewport moves.
// The fingerprint is a list of page node pointers that make up the
// viewport. We need to flatten this to a single list because we can't
// safely traverse the cached values because the page nodes may be
// invalid. All that is safe is comparing the actual pointer values.
struct ViewportFingerprint {
mut:
	// The page node pointers that make up the viewport.
	nodes []&terminal.PageNode
}

fn ViewportFingerprint.init(list &terminal.PageList) ViewportFingerprint {
	tl := list.get_top_left(.viewport)
	br := list.get_bottom_right(.viewport) or { return ViewportFingerprint{} }
	mut iterator := tl.page_iterator(.right_down, br)
	mut nodes := []&terminal.PageNode{}
	for {
		chunk := iterator.next() or { break }
		nodes << chunk.node
	}
	return ViewportFingerprint{
		nodes: nodes
	}
}

fn (mut self ViewportFingerprint) deinit() {
	self.nodes = []
}

fn (self &ViewportFingerprint) eql(other ViewportFingerprint) bool {
	if self.nodes.len != other.nodes.len {
		return false
	}
	for i, n in self.nodes {
		if voidptr(n) != voidptr(other.nodes[i]) {
			return false
		}
	}
	return true
}
