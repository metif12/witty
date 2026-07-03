module search

// --- Original Ghostty Comments Start: src/terminal/search/screen.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/search/screen.zig
//
// Searches for a needle within a Screen, handling active area updates,
// pages being pruned from the screen (e.g. scrollback limits), and more.
//
// Unlike our lower-level searchers (like ActiveSearch and PageListSearch),
// this will cache and store all search results so the caller can re-access
// them as needed. This structure does this because it is intended to help
// the caller handle the case where the Screen is changing while the user
// is searching.
//
// An inactive screen can continue to be searched in the background, and when
// screen state changes, the renderer/caller can access the existing search
// results without needing to re-search everything. This prevents a particularly
// nasty UX where going to alt screen (e.g. neovim) and then back would
// restart the full scrollback search.
// The screen being searched.
// The active area search state
// The history (scrollback) search state. May be null if there is
// no history yet.
// Current state of the search, a state machine.
// The currently selected match, if any. As the screen contents
// change or get pruned, the screen search will do its best to keep
// this accurate.
// The results found so far. These are stored separately because history
// is mostly immutable once found, while active area results may
// change. This lets us easily reset the active area results for a
// re-search scenario.
// The dimensions of the screen. When this changes we need to
// restart the whole search, currently.
// Index from the end of the match list (0 = most recent match)
// Tracked highlight so we can detect movement.
// History search state.
// The actual searcher state.
// The pin for the first node that this searcher is searching from.
// We use this when the active area changes to find the diff between
// the top of the new active area and the previous start point
// to determine if we need to search more history.
// Search state machine
// Currently searching the active area
// Currently searching the history area
// History search is waiting for more data to be fed before
// it can progress.
// Search is complete given the current terminal state.
// Not obvious but complete search states will prune
// stale history results on feed.
// Initialize a screen search for the given screen and needle.
// Update our initial active area state
// The needle that this search is using.
// Returns the total number of matches found so far.
// Returns all matches as an owned slice (caller must free).
// The matches are ordered from most recent to oldest (e.g. bottom
// of the screen to top of the screen).
// Active does a forward search, so we add the active results then
// reverse them. There are usually not many active results so this
// is fast enough compared to adding them in reverse order.
// History does a backward search, so we can just append them
// after.
// Search the full screen state. This will block until the search
// is complete. For performance, it is recommended to use `tick` and
// `feed` to incrementally make progress on the search instead.
// Make incremental progress on the search without accessing any
// screen state (so no lock is required).
//
// This will return error.FeedRequired if the search cannot make progress
// without being fed more data. In this case, the caller should call
// the `feed` function to provide more data to the searcher.
//
// This will return error.SearchComplete if the search is fully complete.
// This is to signal to the caller that it can move to a more efficient
// sleep/wait state until there is more work to do (e.g. new data to feed).
// Feed more data to the searcher so it can continue searching. This
// accesses the screen state, so the caller must hold the necessary locks.
//
// Feed on a complete screen search will perform some cleanup of
// potentially stale history results (pruned) and reclaim some memory.
// If the screen resizes, we have to reset our entire search. That
// isn't ideal but we don't have a better way right now to handle
// reflowing the search results beyond putting a tracked pin for
// every single result.
// Reinit
// Deinit/reinit
// New result should have matching dimensions
// No history to feed, search is complete.
// Future: we may want to feed multiple pages at once here to
// lower the frequency of lock acquisitions.
// No more data to feed, search is complete.
// We use this opportunity to also clean up older history
// results that may be gone due to scrollback pruning, though.
// Depending on our state handle where feed goes
// If we're searching active or history, then feeding doesn't
// change the state.
// Feed goes back to searching history.
// If we're complete then the feed call above should always
// return false and we can't reach this.
// Go through our history results in order (newest to oldest) to find
// any result that contains an invalid serial. Prune up to that
// point.
// Everything from here forward we assume is invalid because
// our history results only get older.
// For the active area, we consume the entire search in one go
// because the active area is generally small.
// If this fails, then we miss a result since `active.next()`
// moves forward and prunes data. In the future, we may want
// to have some more robust error handling but the only
// scenario this would fail is OOM and we're probably in
// deeper trouble at that point anyways.
// We've consumed the entire active area, move to history.
// No history to search, we're done.
// Try to consume all the loaded matches in one go, because
// the search is generally fast for loaded data.
// Ignore selections that are found within the starting
// node since those are covered by the active area search.
// Same note as tickActive for error handling.
// Since history only appends to our results in reverse order,
// we don't need to update any selected match state. The index
// and prior results are unaffected.
// We need to be fed more data.
// Reload the active area because it has changed.
//
// Since it is very fast, this will also do the full active area
// search again, too. This avoids any complexity around the search
// state machine.
//
// The caller must hold the necessary locks to access the screen state.
// If our selection pin became garbage it means we scrolled off
// the end. Clear our selection and on exit of this function,
// try to select the last match.
// We need to account for any active area growth that would
// cause new pages to move into our history. If there are new
// pages then we need to re-search the pages and add it to
// our history results.
// If our screen has no scrollback then we have no history.
// If our start pin became garbage, it means we pruned all
// the way up through it, so we have no history anymore.
// Reset our history state.
// No history search yet, but we now have history. So let's
// initialize.
// We don't need to update any history since we had no history
// before, so we can break out of the whole conditional.
// No change in the starting node, we're done.
// Do a forward search from our prior node to this one. We
// collect all the results into a new list. We ASSUME that
// reloadActive is being called frequently enough that there isn't
// a massive amount of history to search here.
// If we have no matches then there is nothing to change
// in our history (fast path)
// The number added to our history. Needed for updating
// our selection if we have one.
// Matches! Reverse our list then append all the remaining
// history items that didn't start on our original node.
// If our prior selection was in the history area, update
// the offset.
// Moving the idx should not change our targeted result
// since the history is immutable.
// No history node means we have no history
// If we have a selection in the history area, we need to
// move it to the end of the active area.
// Figure out if we need to fixup our selection later because
// it was in the active area.
// This is the error scenario. If something fails below,
// our active area is probably gone, so we just go back
// to the first result because our selection can't be trusted.
// Reset our active search results and search again.
// If we're in the active state we run a normal tick so
// we can move into a better state.
// Otherwise, just tick it and move back to whatever state
// we were in.
// If we have no scrollback, we need to prune any active results
// that aren't in the actual active area. We only do this for the
// no scrollback scenario because with scrollback we actually
// rely on our active search searching by page to find history
// items as well. This is all related to the fact that PageList
// scrollback limits are discrete by page size except we special
// case zero.
// Deinit because its going to be pruned no matter
// what at some point for not being in the active area.
// In the active area! Since our results are sorted
// that means everything after this is also in the active
// area, so we prune up to this i.
// None are in the active area...
// Now we have to fixup our selection if we had one.
// If our old selection wasn't in the active area, then we
// need to fix up our offsets.
// We search for the matching highlight in the new active results.
// Found it! Update our index.
// No match, just go back to the first match.
// Return the selected match.
//
// This does not require read/write access to the underlying screen.
// Next selection, in reverse order (newest to oldest),
// non-wrapping.
// Prev selection, in forward order (oldest to newest),
// non-wrapping.
// Select the next or previous search result. This requires read/write
// access to the underlying screen, since we utilize tracked pins to
// ensure our selection sticks with contents changing.
// All selection requires valid pins so we prune history and
// reload our active area immediately. This ensures all search
// results point to valid nodes.
// Get our previous match so we can change it. If we have no
// prior match, we have the easy task of getting the first.
// Get our highlight
// Active is in forward order
// History is in reverse order
// No matches at all. Can't select anything.
// Pin it so we can track any movement
// Our selection is index zero since we just started and
// we store our selection.
// No more matches. We don't wrap or reset the match currently.
// Pin it so we can track any movement
// Free our previous match and setup our new selection
// Get our previous match so we can change it. If we have no
// prior match, we have the easy task of getting the last.
// Get our highlight (oldest match)
// History is in reverse order, so last item is oldest
// Active is in forward order, so first item is oldest
// No matches at all. Can't select anything.
// Pin it so we can track any movement
// Our selection is the last index since we just started
// and we store our selection.
// Can't go below zero
// No more matches. We don't wrap or reset the match currently.
// Pin it so we can track any movement
// Free our previous match and setup our new selection
// We don't test history results since there is overlap
// Get all matches
// Get all matches
// Start up our search which will populate our initial active area.
// Grow into two pages so our history pin will move.
// Active area changed so reload
// Get all matches
// Reset the screen which will make our pin garbage.
// Erase the screen, move our cursor to the top, and change contents.
// Get all matches
// Initially no selection
// Select our next match (first)
// Next match
// Next match (no wrap)
// Initial selection is the first fizz
// Erase the screen, move our cursor to the top, and change contents.
// Our selection should move to the first
// Erase the screen, redraw with same contents.
// Our selection should not move to the first
// Get all matches
// Erase the screen, redraw with same contents.
// Our selection should not move since the history is still active.
// Create some new history by adding more lines.
// Our selection should not move since the history is still not
// pruned.
// Initially no selection
// Select prev (oldest first)
// Prev match (towards newest)
// Prev match (no wrap, stays at newest)
// Select next (newest first)
// Select next (older)
// Select prev (back to newer)
// Select prev (oldest first, should be in history)
// Select prev (towards newer, should move to active area)
// Alt screen has no scrollback
// This will probably stop working at some point and we'll have
// no way to test it using public APIs, but at the time of writing
// this test, CSI 22 J (scroll complete) pushes into scrollback
// with alt screen.
// Get all matches
// This test verifies that when reloadActive fails at appendSlice (after
// the loop), all FlattenedHighlight items are properly cleaned up.
// Write multiple "Fizz" matches that will end up in history.
// We need enough content to push "Fizz" entries into scrollback.
// Complete initial search
// Now trigger reloadActive by adding more content that changes the
// active/history boundary. First add more "Fizz" entries to history.
// Arm the tripwire to fail at appendSlice (after the loop completes).
// At this point, there are FlattenedHighlight items in the results list
// that need cleanup.
// reloadActive is called by select(), which should trigger the error path.
// If the bug exists, testing.allocator will report a memory leak
// because FlattenedHighlight items weren't cleaned up.
// This test verifies that when reloadActive fails inside the loop
// (after some items have been appended), all FlattenedHighlight items
// are properly cleaned up.
// Write multiple "Fizz" matches that will end up in history.
// We need enough content to push "Fizz" entries into scrollback.
// Complete initial search
// Now trigger reloadActive by adding more content that changes the
// active/history boundary. First add more "Fizz" entries to history.
// Arm the tripwire to fail after the first loop append succeeds.
// This leaves at least one FlattenedHighlight in the results list
// that needs cleanup.
// reloadActive is called by select(), which should trigger the error path.
// If the bug exists, testing.allocator will report a memory leak
// because FlattenedHighlight items weren't cleaned up.
//
// --- Original Ghostty Comments End: src/terminal/search/screen.zig


// Searches for a needle within a Screen, handling active area updates,
// pages being pruned from the screen (e.g. scrollback limits), and more.
//
// Unlike our lower-level searchers (like ActiveSearch and PageListSearch),
// this will cache and store all search results so the caller can re-access
// them as needed. This structure does this because it is intended to help
// the caller handle the case where the Screen is changing while the user
// is searching.
//
// An inactive screen can continue to be searched in the background, and when
// screen state changes, the renderer/caller can access the existing search
// results without needing to re-search everything. This prevents a particularly
// nasty UX where going to alt screen (e.g. neovim) and then back would
// restart the full scrollback search.
//
// Source: terminal/search/screen.zig (1517 lines)

import terminal
import highlight

// ============================================================
// SelectedMatch
// ============================================================

// SelectedMatch tracks the currently selected search result.
pub struct SelectedMatch {
pub mut:
	// Index from the end of the match list (0 = most recent match).
	idx int

	// Tracked highlight so we can detect movement.
	hl highlight.TrackedHighlight
}

pub fn (mut self SelectedMatch) deinit(mut screen terminal.Screen) {
	self.hl.deinit(mut screen)
}

// ============================================================
// HistorySearch
// ============================================================

// History search state.
struct HistorySearch {
mut:
	// The actual searcher state.
	searcher PageListSearch

	// The pin for the first node that this searcher is searching from.
	// We use this when the active area changes to find the diff between
	// the top of the new active area and the previous start point
	// to determine if we need to search more history.
	start_pin &terminal.PagePin = unsafe { nil }
}

fn (mut self HistorySearch) deinit(mut screen terminal.Screen) {
	// XTODO: Should untrack start_pin from screen.pages (PageList).
	self.searcher.deinit()
	_ = screen
}

// ============================================================
// State
// ============================================================

// Search state machine.
pub enum State {
	// Currently searching the active area.
	active
	// Currently searching the history area.
	history
	// History search is waiting for more data to be fed before
	// it can progress.
	history_feed
	// Search is complete given the current terminal state.
	complete
}

pub fn (self State) is_complete() bool {
	return self == .complete
}

pub fn (self State) needs_feed() bool {
	return match self {
		.history_feed { true }
		// Not obvious but complete search states will prune
		// stale history results on feed.
		.complete { true }
		else { false }
	}
}

// ============================================================
// Select direction
// ============================================================

pub enum Select {
	// Next selection, in reverse order (newest to oldest), non-wrapping.
	next
	// Prev selection, in forward order (oldest to newest), non-wrapping.
	prev
}

// ============================================================
// ScreenSearch
// ============================================================

pub struct ScreenSearch {
pub mut:
	// The screen being searched.
	screen &terminal.Screen = unsafe { nil }

	// The active area search state.
	active_search ActiveSearch

	// The history (scrollback) search state. May be none if there is
	// no history yet.
	history_search ?HistorySearch

	// Current state of the search, a state machine.
	state State

	// The currently selected match, if any. As the screen contents
	// change or get pruned, the screen search will do its best to keep
	// this accurate.
	selected ?SelectedMatch

	// The results found so far. These are stored separately because history
	// is mostly immutable once found, while active area results may
	// change. This lets us easily reset the active area results for a
	// re-search scenario.
	history_results []highlight.FlattenedHighlight
	active_results  []highlight.FlattenedHighlight

	// The dimensions of the screen. When this changes we need to
	// restart the whole search, currently.
	rows u16
	cols u16
}

// Initialize a screen search for the given screen and needle.
pub fn ScreenSearch.init(screen &terminal.Screen, needle []u8) ScreenSearch {
	// XTODO: Full initialization requires:
	// 1. Create ActiveSearch and immediately search the active area
	// 2. Set up history search if scrollback exists
	// 3. Call reload_active() for initial state
	// Currently returns a minimal valid state.
	return ScreenSearch{
		screen: screen
		rows: u16(screen.pages.rows)
		cols: u16(screen.pages.cols)
		active_search: ActiveSearch.init(needle)
		history_search: none
		state: .active
	}
}

// Free resources.
pub fn (mut self ScreenSearch) deinit() {
	self.active_search.deinit()
	if mut h := self.history_search {
		h.deinit(mut self.screen)
	}
	if mut m := self.selected {
		m.deinit(mut self.screen)
	}
	for mut hl in self.active_results {
		hl.deinit()
	}
	self.active_results = []
	for mut hl in self.history_results {
		hl.deinit()
	}
	self.history_results = []
}

// The needle that this search is using.
pub fn (self &ScreenSearch) needle() []u8 {
	assert self.active_search.window.direction == .forward, 'active search must be forward'
	return self.active_search.window.needle
}

// Returns the total number of matches found so far.
pub fn (self &ScreenSearch) matches_len() int {
	return self.active_results.len + self.history_results.len
}

// Returns all matches as a slice. The matches are ordered from
// most recent to oldest (bottom of screen to top of screen).
pub fn (self &ScreenSearch) matches() []highlight.FlattenedHighlight {
	active := self.active_results
	hist := self.history_results

	mut results := []highlight.FlattenedHighlight{cap: active.len + hist.len}

	// Active does a forward search, so we add the active results then
	// reverse them. There are usually not many active results so this
	// is fast enough compared to adding them in reverse order.
	for i := active.len - 1; i >= 0; i-- {
		results << active[i].clone()
	}

	// History does a backward search, so we can just append them after.
	for h in hist {
		results << h.clone()
	}

	return results
}

// Search the full screen state. This will block until the search
// is complete. For performance, it is recommended to use tick and
// feed to incrementally make progress on the search instead.
pub fn (mut self ScreenSearch) search_all() {
	// XTODO: Requires full tick/feed state machine with PageList integration.
	// Should loop calling tick() and feed() until complete.
	// Currently performs only the active area search.
	self.tick_active()
	self.state = .complete
}

// Make incremental progress on the search without accessing any
// screen state (so no lock is required).
//
// Returns true if more work is needed, false if search is complete
// or needs feeding.
pub fn (mut self ScreenSearch) tick() bool {
	// XTODO: Full state machine implementation.
	match self.state {
		.active {
			self.tick_active()
			return true
		}
		.history {
			self.tick_history()
			return true
		}
		.history_feed {
			return false // needs feed
		}
		.complete {
			return false // done
		}
	}
}

// Feed more data to the searcher so it can continue searching. This
// accesses the screen state, so the caller must hold the necessary locks.
//
// Feed on a complete screen search will perform some cleanup of
// potentially stale history results (pruned) and reclaim some memory.
pub fn (mut self ScreenSearch) feed() {
	// XTODO: Full feed implementation requires:
	// 1. Check if screen dimensions changed (reinit if so)
	// 2. Feed the next page to the history searcher
	// 3. Update state machine based on whether more data is available
	// 4. Prune stale history results

	// If no history search, we're complete.
	if self.history_search == none {
		self.state = .complete
		return
	}

	// Transition state.
	match self.state {
		.active, .history {}
		.history_feed { self.state = .history }
		.complete {}
	}
}

// Go through history results to prune any that reference invalid
// (pruned) page nodes.
fn (mut self ScreenSearch) prune_history() {
	// XTODO: Requires screen.pages.page_serial_min (PageList feature).
	// Should iterate history_results and remove entries whose chunks
	// reference nodes with serials below the minimum valid serial.
}

// Search the active area to completion.
fn (mut self ScreenSearch) tick_active() {
	// For the active area, we consume the entire search in one go
	// because the active area is generally small.
	for {
		hl := self.active_search.next() or { break }
		// Clone the highlight since active.next() returns temporary data.
		self.active_results << hl.clone()
	}

	// We've consumed the entire active area, move to history.
	self.state = .history
}

// Search history for loaded matches.
fn (mut self ScreenSearch) tick_history() {
	// XTODO: Requires HistorySearch with PageListSearch integration.
	// Should consume all loaded matches from the history searcher.
	self.state = .history_feed
}

// Reload the active area because it has changed.
//
// Since it is very fast, this will also do the full active area
// search again, too. This avoids any complexity around the search
// state machine.
//
// The caller must hold the necessary locks to access the screen state.
pub fn (mut self ScreenSearch) reload_active() {
	// XTODO: Full implementation requires:
	// 1. Check if selection pin became garbage (clear selection if so)
	// 2. Call active.update(list) to get history boundary changes
	// 3. Search any new history pages that moved out of active area
	// 4. Reset and re-search the active area
	// 5. Fix up selection indices if active results changed
	// 6. Handle no_scrollback pruning of out-of-active results

	// Simplified: just reset and re-search active.
	for mut hl in self.active_results {
		hl.deinit()
	}
	self.active_results = []

	old_state := self.state
	self.tick_active()
	// Restore state unless we were in the initial active state.
	if old_state != .active {
		self.state = old_state
	}
}

// Return the selected match.
//
// This does not require read/write access to the underlying screen.
pub fn (self &ScreenSearch) selected_match() ?highlight.FlattenedHighlight {
	sel := self.selected or { return none }
	active_len := self.active_results.len
	if sel.idx < active_len {
		return self.active_results[active_len - 1 - sel.idx]
	}

	history_len := self.history_results.len
	if sel.idx < active_len + history_len {
		return self.history_results[sel.idx - active_len]
	}

	return none
}

// Select the next or previous search result. This requires read/write
// access to the underlying screen, since we utilize tracked pins to
// ensure our selection sticks with contents changing.
pub fn (mut self ScreenSearch) do_select(to Select) bool {
	// XTODO: Full select requires reload_active() and prune_history()
	// to ensure all results point to valid nodes before selecting.
	return match to {
		.next { self.select_next() }
		.prev { self.select_prev() }
	}
}

fn (mut self ScreenSearch) select_next() bool {
	// Get our previous match so we can change it. If we have no
	// prior match, we have the easy task of getting the first.
	if mut prev := self.selected {
		next_idx := prev.idx + 1
		active_len := self.active_results.len
		history_len := self.history_results.len
		if next_idx >= active_len + history_len {
			// No more matches. We don't wrap or reset the match currently.
			return false
		}
		hl := if next_idx < active_len {
			self.active_results[active_len - 1 - next_idx]
		} else {
			self.history_results[next_idx - active_len]
		}

		// Pin it so we can track any movement.
		tracked := hl.untracked().track(mut self.screen)

		// Free our previous match and setup our new selection.
		prev.deinit(mut self.screen)
		self.selected = SelectedMatch{
			idx: next_idx
			hl: tracked
		}
		return true
	} else {
		// No prior selection, get the first match.
		hl := if self.active_results.len > 0 {
			// Active is in forward order.
			self.active_results[self.active_results.len - 1]
		} else if self.history_results.len > 0 {
			// History is in reverse order.
			self.history_results[0]
		} else {
			// No matches at all. Can't select anything.
			return false
		}

		// Pin it so we can track any movement.
		tracked := hl.untracked().track(mut self.screen)

		// Our selection is index zero since we just started.
		self.selected = SelectedMatch{
			idx: 0
			hl: tracked
		}
		return true
	}
}

fn (mut self ScreenSearch) select_prev() bool {
	// Get our previous match so we can change it. If we have no
	// prior match, we have the easy task of getting the last.
	if mut prev := self.selected {
		// Can't go below zero.
		if prev.idx == 0 {
			// No more matches. We don't wrap or reset the match currently.
			return false
		}

		next_idx := prev.idx - 1
		active_len := self.active_results.len
		hl := if next_idx < active_len {
			self.active_results[active_len - 1 - next_idx]
		} else {
			self.history_results[next_idx - active_len]
		}

		// Pin it so we can track any movement.
		tracked := hl.untracked().track(mut self.screen)

		// Free our previous match and setup our new selection.
		prev.deinit(mut self.screen)
		self.selected = SelectedMatch{
			idx: next_idx
			hl: tracked
		}
		return true
	} else {
		// No prior selection, get the oldest match.
		active_len := self.active_results.len
		history_len := self.history_results.len
		hl := if history_len > 0 {
			// History is in reverse order, so last item is oldest.
			self.history_results[history_len - 1]
		} else if active_len > 0 {
			// Active is in forward order, so first item is oldest.
			self.active_results[0]
		} else {
			// No matches at all. Can't select anything.
			return false
		}

		// Pin it so we can track any movement.
		tracked := hl.untracked().track(mut self.screen)

		// Our selection is the last index since we started from oldest.
		self.selected = SelectedMatch{
			idx: active_len + history_len - 1
			hl: tracked
		}
		return true
	}
}
