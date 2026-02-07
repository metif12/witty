module search

// Search thread that handles searching a terminal for a string match.
// This is expected to run on a dedicated thread to try to prevent too much
// overhead to other terminal read/write operations.
//
// The current architecture of search does acquire global locks for accessing
// terminal data, so there's still added contention, but we do our best to
// minimize this by trading off memory usage (copying data to minimize lock
// time).
//
// Source: terminal/search/Thread.zig

// TODO: Some stuff that could be improved:
// - pause the refresh timer when the terminal isn't focused
// - we probably want to know our progress through the search
//   for viewport matches so we can show n/total UI.
// - notifications should be coalesced to avoid spamming a massive
//   amount of events if the terminal is changing rapidly.

// The interval at which we refresh the terminal state to check if
// there are any changes that require us to re-search. This should be
// balanced to be fast enough to be responsive but not so fast that
// we hold the terminal lock too often.
const refresh_interval = 24 // 40 FPS

// Options for the search thread.
pub struct ThreadOptions {
pub:
	// XTODO: mutex and terminal fields require threading and terminal
	// module integration respectively.
	// mutex &Mutex
	// terminal &Terminal

	// The callback for events from the search thread along with optional
	// userdata. This can be null if you don't want to receive events,
	// which could be useful for a one-time search (although, odd, you
	// should use our search structures directly then).
	// event_cb ?EventCallback
	// event_userdata voidptr
	placeholder int // avoid empty struct
}

// EventCallback is the type for event callbacks from the search thread.
// XTODO: pub type EventCallback = fn (event Event, userdata voidptr)

// The messages that can be sent to the thread.
pub enum MessageType {
	// Change the search term. If no prior search term is given this
	// will start a search. If an existing search term is given this will
	// stop the prior search and start a new one.
	change_needle
	// Select a search result.
	select_result
}

// Events that can be emitted from the search thread. The caller
// chooses to handle these as they see fit.
pub enum EventType {
	// Search is quitting. The search thread is exiting.
	quit
	// Search is complete for the given needle on all screens.
	complete
	// Total matches on the current active screen have changed.
	total_matches
	// Selected match changed.
	selected_match
	// Matches in the viewport have changed.
	viewport_matches
}

// ThreadSelectedMatch represents a selected search result for the search thread.
// Named ThreadSelectedMatch to avoid conflict with SelectedMatch in screen_search.v.
pub struct ThreadSelectedMatch {
pub:
	idx int
	// XTODO: highlight field needs FlattenedHighlight type
	// highlight FlattenedHighlight
}

// SearchThread handles searching a terminal for a string match.
// XTODO: Full implementation requires:
// - xev event loop (or equivalent async I/O)
// - Threading primitives (Mutex, Thread)
// - Terminal access
// - Mailbox/BlockingQueue
pub struct SearchThread {
mut:
	// XTODO: All fields depend on external libraries:
	// alloc: allocator
	// mailbox: &Mailbox
	// loop_: xev.Loop
	// wakeup: xev.Async
	// stop: xev.Async
	// refresh: xev.Timer
	// search: ?Search
	// opts: ThreadOptions
	placeholder int // placeholder to avoid empty struct
}

// Tick result for search progress.
pub enum Tick {
	// All searches are complete.
	complete
	// Progress was made on at least one screen.
	progress
	// All incomplete searches are blocked on feed.
	blocked
}

// Initialize the thread. This does not START the thread. This only sets
// up all the internal state necessary prior to starting the thread. It
// is up to the caller to start the thread with the thread_main entrypoint.
pub fn SearchThread.init(opts ThreadOptions) !SearchThread {
	// XTODO: Full implementation requires xev event loop, async handles,
	// and timer initialization.
	return SearchThread{}
}

// Clean up the thread. This is only safe to call once the thread
// completes executing; the caller must join prior to this.
pub fn (mut self SearchThread) deinit() {
	// XTODO: Cleanup of xev handles, mailbox, and search state.
}

// The main entrypoint for the thread.
pub fn (mut self SearchThread) thread_main() {
	// XTODO: Full implementation requires:
	// - xev event loop execution
	// - Mailbox draining
	// - Search tick/feed interleaving
	// - Platform thread naming (pthread_setname_np on macOS)
	// - QoS class setting on macOS
}
