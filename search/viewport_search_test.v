module search

// Tests for ViewportSearch.
//
// Source: terminal/search/viewport.zig (tests)
//
// All tests require Terminal/Screen instances with PageList integration,
// VT stream processing, and viewport scrolling support. Since the V
// implementation uses the simpler Pages model and ViewportSearch.update()
// is XTODO (needs PageList with page node tracking), these tests are
// stubbed with XTODO markers.

// XTODO: Original test: "simple search"
// Tests basic viewport search finding two matches, then verifying
// viewport re-search is triggered when viewport overlaps active area.
fn test_viewport_simple_search() {
	// XTODO: Requires Terminal.init, VT stream, ViewportSearch.init,
	// update(), next(), and pointFromPin() on PageList.
}

// XTODO: Original test: "clear screen and search"
// Tests that clearing the screen and rewriting content triggers
// re-search with updated results.
fn test_viewport_clear_screen_and_search() {
	// XTODO: Requires Terminal, VT stream with ESC[2J clear,
	// ViewportSearch with update() and next().
}

// XTODO: Original test: "clear screen and search dirty tracking"
// Tests the active_dirty flag mechanism: when dirty tracking is on,
// viewport only re-searches when active_dirty is set to true.
fn test_viewport_clear_screen_dirty_tracking() {
	// XTODO: Requires Terminal, VT stream, ViewportSearch with
	// active_dirty flag and update().
}

// XTODO: Original test: "history search, no active area"
// Tests viewport search when scrolled to top of history (viewport
// doesn't overlap active area), verifying that update returns false
// since viewport hasn't changed.
fn test_viewport_history_no_active_area() {
	// XTODO: Requires Terminal with multi-page scrollback,
	// scrollViewport(.top), and ViewportSearch with update().
}
