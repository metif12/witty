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
// XTODO: Full implementation requires PageList with linked list page
// nodes, viewport tracking, and active area boundary detection.

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
	// XTODO: Full implementation requires PageList with:
	// - getTopLeft(.viewport) / getBottomRight(.viewport) for viewport bounds
	// - getTopLeft(.active) / getBottomRight(.active) for active area bounds
	// - pageIterator for traversing page nodes in the viewport
	// - Page node pointers for fingerprint comparison
	//
	// The algorithm is:
	// 1. Build a new fingerprint from the current viewport page nodes
	// 2. Compare with the old fingerprint:
	//    - If unchanged AND viewport doesn't overlap active area (or active
	//      isn't dirty), return false (no re-search needed)
	//    - Otherwise, update fingerprint and rebuild the sliding window
	// 3. Clear the sliding window
	// 4. Add overlap pages before the viewport (for cross-page needle matches)
	// 5. Add all viewport pages to the sliding window
	// 6. Add overlap pages after the viewport
	// 7. Return true (re-search needed)

	// For now, always indicate a re-search is needed since we can't
	// properly track viewport changes without PageList integration.
	_ = list
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
	nodes []voidptr
}

fn ViewportFingerprint.init(list &terminal.PageList) ViewportFingerprint {
	// XTODO: Requires PageList with:
	// - getTopLeft(.viewport) to get the top-left pin
	// - getBottomRight(.viewport) to get the bottom-right pin
	// - pageIterator to traverse page nodes in the viewport range
	//
	// The fingerprint collects all unique page node pointers that
	// the viewport touches. This allows cheap comparison to detect
	// viewport scrolling.
	_ = list
	return ViewportFingerprint{
		nodes: []
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
		if n != other.nodes[i] {
			return false
		}
	}
	return true
}
