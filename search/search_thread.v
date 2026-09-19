module search

// --- Original Ghostty Comments Start: src/terminal/search/Thread.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/search/Thread.zig
//
// Search thread that handles searching a terminal for a string match.
// This is expected to run on a dedicated thread to try to prevent too much
// overhead to other terminal read/write operations.
//
// The current architecture of search does acquire global locks for accessing
// terminal data, so there's still added contention, but we do our best to
// minimize this by trading off memory usage (copying data to minimize lock
// time).
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
// Allocator used for some state
// The mailbox that can be used to send this thread messages. Note
// this is a blocking queue so if it is full you will get errors (or block).
// The event loop for the search thread.
// This can be used to wake up the renderer and force a render safely from
// any thread.
// This can be used to stop the thread on the next loop iteration.
// The timer used for refreshing the terminal state to determine if
// we have a stale active area, viewport, screen change, etc. This is
// CPU intensive so we stop doing this under certain conditions.
// Search state. Starts as null and is populated when a search is
// started (a needle is given).
// The options used to initialize this thread.
// Initialize the thread. This does not START the thread. This only sets
// up all the internal state necessary prior to starting the thread. It
// is up to the caller to start the thread with the threadMain entrypoint.
// The mailbox for messaging this thread
// Create our event loop.
// This async handle is used to "wake up" the renderer and force a render.
// This async handle is used to stop the loop and force the thread to end.
// Refresh timer, see comments.
// Clean up the thread. This is only safe to call once the thread
// completes executing; the caller must join prior to this.
// Nothing can possibly access the mailbox anymore, destroy it.
// The main entrypoint for the thread.
// Call child function so we can use errors...
// In the future, we should expose this on the thread struct.
// Right now, on Darwin, `std.Thread.setName` can only name the current
// thread, and we have no way to get the current thread from within it,
// so instead we use this code to name the thread instead.
// We can run with lower priority than other threads.
// Start the async handlers
// Send an initial wakeup so we drain our mailbox immediately.
// Start the refresh timer
// Run
// Send the quit message
// Unlike some of our other threads, we interleave search work
// with our xev loop so that we can try to make forward search progress
// while also listening for messages.
// If our loop is canceled then we drain our messages and quit.
// If we're not actively searching, we can block the loop
// until it does some work.
// If we have an active search, we always send any pending
// notifications. Even if the search is complete, there may be
// notifications to send.
// If our search is complete, there's no more work to do, we
// can block until we have an xev action.
// Tick the search. This will trigger any event callbacks, lock
// for data loading, etc.
// We're complete now when we were not before. Notify!
// Forward progress was made.
// All searches are blocked. Let's grab the lock and feed data.
// We have an active search, so we only want to process messages
// we have but otherwise return immediately so we can continue the
// search. If the above completed the search, we still want to
// go around the loop as quickly as possible to send notifications,
// and then we'll block on the loop next time.
// Drain the mailbox.
// Make the selection. Ignore the result because we don't
// care if the selection didn't change.
// Grab our match if we have one. If we don't have a selection
// then we do nothing.
// No matter what we reset our selected match cache. This will
// trigger a callback which will trigger the renderer to wake up
// so it can be notified the screen scrolled.
// Grab the current screen and see if this match is visible within
// the viewport already. If it is, we do nothing.
// Grab the viewport. Viewports and selections are usually small
// so this check isn't very expensive, despite appearing O(N^2),
// both Ns are usually equal to 1.
// Change the search term to the given value.
// Stop the previous search
// If our search is unchanged, do nothing.
// When the search changes then we need to emit that it stopped.
// No needle means stop the search.
// Setup our search state.
// We need to grab the terminal lock and do an initial feed.
// Set our active state so it knows we're running. We set this before
// even checking the active state in case we have a pending shutdown.
// If our timer is already active, then we don't have to do anything.
// Start the timer which loops
// This will stop the refresh on the next iteration.
// When we wake up, we drain the mailbox. Mailbox producers should
// wake up our thread after publishing.
// This shouldn't happen so we log it.
// Run our feed if we have a search active.
// Only continue if we're still active
// Mutex that must be held while reading/writing the terminal.
// The terminal data to search.
// The callback for events from the search thread along with optional
// userdata. This can be null if you don't want to receive events,
// which could be useful for a one-time search (although, odd, you
// should use our search structures directly then).
// The type used for sending messages to the thread.
// The messages that can be sent to the thread.
// Represents a write request. Magic number comes from the max size
// we want this union to be.
// Change the search term. If no prior search term is given this
// will start a search. If an existing search term is given this will
// stop the prior search and start a new one.
// Select a search result.
// Events that can be emitted from the search thread. The caller
// chooses to handle these as they see fit.
// Search is quitting. The search thread is exiting.
// Search is complete for the given needle on all screens.
// Total matches on the current active screen have changed.
// Selected match changed.
// Matches in the viewport have changed. The memory is owned by the
// search thread and is only valid during the callback.
// Search state.
// Active viewport search for the active screen.
// The searchers for all the screens.
// All state related to screen switches, collected so that when
// we switch screens it makes everything related stale, too.
// True if we sent the complete notification yet.
// The last viewport matches we found.
// Last active screen key
// Last notified total matches count
// Last notified selected match index
// We use dirty tracking for active area changes. Start with it
// dirty so the first change is re-searched.
// Returns true if all searches on all screens are complete.
// All searches are complete.
// Progress was made on at least one screen.
// All incomplete searches are blocked on feed.
// Tick the search forward as much as possible without acquiring
// the big lock. Returns the overall tick progress.
// Ignore... nothing we can do.
// Ignore, good for us. State remains whatever it is.
// Ignore, too, progressed
// If we think we're complete, we're not because we're
// blocked now (nothing made progress).
// If we made some progress, we remain in progress
// since blocked means no progress at all.
// If we're blocked already then we remain blocked.
// log.debug("tick result={}", .{result});
// Grab the mutex and update any state that requires it, such as
// feeding additional data to the searches or updating the active screen.
// Update our active screen
// The default values will force resets of a bunch of other
// state too to force recalculations and notifications.
// Reconcile our screens with the terminal screens. Remove
// searchers for screens that no longer exist and add searchers
// for screens that do exist but we don't have yet.
// Remove screens we have that no longer exist or changed.
// If the screen doesn't exist at all, remove it.
// If the screen pointer changed, remove it, the screen
// was totally reinitialized.
// Add screens that exist but we don't have yet.
// OOM is probably going to sink the entire ship but
// we can just ignore it and wait on the next
// reconciliation to try again.
// See the `search_viewport_dirty` flag on the terminal to know
// what exactly this is for. But, if this is set, we know the renderer
// found the viewport/active area dirty, so we should mark it as
// dirty in our viewport searcher so it forces a re-search.
// Mark our viewport dirty so it researches the active
// Reload our active area for our active screen
// Check our viewport for changes.
// Feed data
// Notify about any changes to the search state.
//
// This doesn't require any locking as it only reads internal state.
// Check our total match data
// Check our viewport matches. If they're stale, we do the
// viewport search now. We do this as part of notify and not
// tick because the viewport search is very fast and doesn't
// require ticked progress or feeds.
// We always make stale as false. Even if we fail below
// we require a re-feed to re-search the viewport. The feed
// process will make it stale again.
// Reset the viewport so we force an update on the
// next feed.
// Check our last selected match data.
// Same selection, don't update it.
// New selection, notify!
// Send our complete notification if we just completed.
// Start our search
// Wait for completion
// Stop the thread
// 1 total matches
//
// --- Original Ghostty Comments End: src/terminal/search/Thread.zig

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

import sync
import time
import terminal
import highlight
import datastruct
import internal_os

// The interval at which we refresh the terminal state to check if
// there are any changes that require us to re-search. This should be
// balanced to be fast enough to be responsive but not so fast that
// we hold the terminal lock too often.
const refresh_interval = 24 // 40 FPS

// EventCallback is the type for event callbacks from the search thread.
// Mirrors Zig's `*const fn (event: Event, userdata: ?*anyopaque) void`.
pub type EventCallback = fn (event Event, userdata voidptr)

// Options for the search thread.
//
// Source: Thread.Options
pub struct ThreadOptions {
pub mut:
	// Mutex that must be held while reading/writing the terminal.
	mutex &sync.Mutex = unsafe { nil }

	// The terminal data to search.
	terminal &terminal.Terminal = unsafe { nil }

	// The callback for events from the search thread along with optional
	// userdata. This can be none if you don't want to receive events,
	// which could be useful for a one-time search (although, odd, you
	// should use our search structures directly then).
	event_cb       ?EventCallback
	event_userdata voidptr
}

// The messages that can be sent to the thread.
//
// Source: Thread.Message (tagged union). V has no ergonomic payload-
// carrying unions here, so we model the tag as an enum and carry the
// payload alongside in Message.
pub enum MessageType as u8 {
	// Change the search term. If no prior search term is given this
	// will start a search. If an existing search term is given this will
	// stop the prior search and start a new one.
	change_needle
	// Select a search result.
	select_result
}

// Message is a message posted to the search thread's mailbox.
pub struct Message {
pub:
	kind MessageType
	// For change_needle: the new needle bytes.
	needle datastruct.MessageData[u8]
	// For select_result: the direction to move the selection.
	select Select
}

pub fn Message.change_needle(data []u8) Message {
	return Message{
		kind: .change_needle
		needle: datastruct.MessageData.init[u8](255, data)
	}
}

// Events that can be emitted from the search thread. The caller
// chooses to handle these as they see fit.
//
// Source: Thread.Event (tagged union), modeled as tag + payload.
pub enum EventType as u8 {
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

// ThreadSelectedMatch represents a selected search result for the search
// thread. Named ThreadSelectedMatch to avoid conflict with SelectedMatch
// in screen_search.v.
//
// Source: Thread.Event.SelectedMatch
pub struct ThreadSelectedMatch {
pub mut:
	idx       usize
	highlight highlight.Flattened
}

// Event is an event emitted from the search thread. The active tag is
// `kind`; the remaining fields carry the payload for that tag.
pub struct Event {
pub mut:
	kind EventType
	// total_matches payload
	total usize
	// selected_match payload (none => selection cleared)
	selected ?ThreadSelectedMatch
	// viewport_matches payload. The memory is owned by the search thread
	// and is only valid during the callback.
	viewport_matches []highlight.Flattened
}

// Tick result for search progress.
//
// Source: Search.Tick
pub enum Tick as u8 {
	// All searches are complete.
	complete
	// Progress was made on at least one screen.
	progress
	// All incomplete searches are blocked on feed.
	blocked
}

// SearchThread handles searching a terminal for a string match.
//
// Source: Thread (@This()).
//
// V channels provide the same bounded-mailbox, wakeup, and stop semantics
// that Ghostty implements with BlockingQueue and xev async handles. The
// search state itself remains owned exclusively by this thread.
pub struct SearchThread {
mut:
	// The mailbox of pending messages for this thread.
	mailbox chan Message

	// Stop notification for the worker.
	stop chan bool

	// The timer-active flag, see startRefreshTimer/stopRefreshTimer.
	refresh_active bool

	// Search state. Starts as none and is populated when a search is
	// started (a needle is given).
	search ?Search

	// The options used to initialize this thread.
	opts ThreadOptions
}

// Initialize the thread. This does not START the thread. This only sets
// up all the internal state necessary prior to starting the thread. It
// is up to the caller to start the thread with the thread_main entrypoint.
//
// Source: Thread.init (minus xev loop/async/timer setup, see boundary
// note on SearchThread).
pub fn SearchThread.init(opts ThreadOptions) !&SearchThread {
	if opts.mutex == unsafe { nil } || opts.terminal == unsafe { nil } {
		return error('search thread requires a terminal and mutex')
	}
	return &SearchThread{
		opts: opts
		mailbox: chan Message{ cap: 64 }
		stop: chan bool{ cap: 1 }
	}
}

// Clean up the thread. This is only safe to call once the thread
// completes executing; the caller must join prior to this.
//
// Source: Thread.deinit
pub fn (mut self SearchThread) deinit() {
	if mut s := self.search {
		s.deinit()
		self.search = none
	}
	self.mailbox.close()
	self.stop.close()
}

// The main entrypoint for the thread.
//
// Source: Thread.threadMain / threadMain_. V channels replace xev's async
// wakeup and stop handles; a timed select replaces the repeating xev timer.
pub fn (mut self SearchThread) thread_main() {
	$if macos {
		internal_os.set_thread_name('search')
		internal_os.set_qos_class(.utility) or {}
	}
	self.start_refresh_timer()
	defer {
		if cb := self.opts.event_cb {
			cb(Event{ kind: .quit }, self.opts.event_userdata)
		}
	}

	for {
		mut s := self.search or {
			// With no search active, block until a producer wakes us or the
			// worker is stopped.
			if self.wait_for_work() {
				return
			}
			continue
		}

		// If we have an active search, we always send any pending
		// notifications. Even if the search is complete, there may be
		// notifications to send.
		if cb := self.opts.event_cb {
			s.notify(cb, self.opts.event_userdata)
		}

		if s.is_complete() {
			// A completed search sleeps until a new message or the refresh
			// timer fires. Refreshing feeds terminal changes back into it.
			self.search = s
			if self.wait_for_work() {
				return
			}
			continue
		}

		// Tick the search. This will trigger any event callbacks, lock
		// for data loading, etc.
		match s.tick() {
			// We're complete now when we were not before.
			.complete {}
			// Forward progress was made.
			.progress {}
			// All searches are blocked. Let's grab the lock and feed data.
			.blocked {
				self.opts.mutex.lock()
				s.feed(mut self.opts.terminal)
				self.opts.mutex.unlock()
			}
		}

		self.search = s

		// While a search is making progress we never block, but still check
		// all pending control messages between ticks.
		if self.poll_control() {
			return
		}
	}
}

// Handle one mailbox message.
fn (mut self SearchThread) handle_message(msg Message) {
	match msg.kind {
		.change_needle {
			self.change_needle(msg.needle.slice())
		}
		.select_result {
			self.do_select(msg.select)
		}
	}
}

// Wait for a message, stop request, or refresh tick. Returns true when the
// worker should exit.
fn (mut self SearchThread) wait_for_work() bool {
	select {
		msg := <-self.mailbox {
			self.handle_message(msg)
		}
		_ := <-self.stop {
			return true
		}
		refresh_interval * time.millisecond {
			self.refresh_search()
		}
	}
	return false
}

// Process all currently available messages without blocking. Returns true
// when a stop request was observed.
fn (mut self SearchThread) poll_control() bool {
	for {
		mut handled := false
		select {
			msg := <-self.mailbox {
				self.handle_message(msg)
				handled = true
			}
			_ := <-self.stop {
				return true
			}
			else {
			}
		}
		if !handled {
			return false
		}
	}
	return false
}

// Feed changed terminal state into the active search on each refresh tick.
fn (mut self SearchThread) refresh_search() {
	if !self.refresh_active {
		return
	}
	if mut s := self.search {
		self.opts.mutex.lock()
		s.feed(mut self.opts.terminal)
		self.opts.mutex.unlock()
		self.search = s
	}
}

// Post a message to this thread's mailbox. Producers should call
// thread_main (or resume the loop) after publishing.
pub fn (mut self SearchThread) push(msg Message) {
	self.mailbox <- msg
}

// Request the loop to stop on its next iteration.
//
// Source: Thread.stopCallback (loop.stop()).
pub fn (mut self SearchThread) request_stop() {
	select {
		self.stop <- true {
		}
		else {
		}
	}
}

// Select a search result and scroll it into view when necessary.
//
// Source: Thread.select. The canonical code checks overlapping PageList
// chunks; at the flat Screen boundary the equivalent check uses absolute row
// coordinates obtained from the search snapshot.
fn (mut self SearchThread) do_select(sel Select) {
	mut s := self.search or { return }
	key := s.last_screen.key

	self.opts.mutex.lock()
	if mut screen_search := s.screens[key] {
		// Make the selection. Ignore the result because we don't care if
		// the selection didn't change.
		screen_search.do_select(sel)
		flattened := screen_search.selected_match() or {
			self.opts.mutex.unlock()
			self.search = s
			return
		}

		// No matter what we reset our selected match cache. This will
		// trigger a callback which will trigger the renderer to wake up so
		// it can be notified the screen scrolled.
		s.last_screen.selected = none

		mut live_screen := self.opts.terminal.screens.get(key) or {
			self.opts.mutex.unlock()
			self.search = s
			return
		}
		start := screen_search.pages.point_from_pin(.screen, flattened.start_pin()) or {
			self.opts.mutex.unlock()
			self.search = s
			return
		}
		end := screen_search.pages.point_from_pin(.screen, flattened.end_pin()) or {
			self.opts.mutex.unlock()
			self.search = s
			return
		}
		viewport_top := live_screen.pages.viewport_start
		viewport_bot := viewport_top + int(live_screen.pages.rows) - 1
		if int(end.coord().y) < viewport_top || int(start.coord().y) > viewport_bot {
			target := if int(start.coord().y) > live_screen.pages.active_start {
				live_screen.pages.active_start
			} else {
				int(start.coord().y)
			}
			live_screen.pages.scroll_delta(target - viewport_top)
		}
	}
	self.opts.mutex.unlock()

	self.search = s
}

// Change the search term to the given value.
//
// Source: Thread.changeNeedle
fn (mut self SearchThread) change_needle(needle []u8) {
	// Stop the previous search.
	if mut s := self.search {
		// If our search is unchanged, do nothing.
		if eql_ignore_case(s.viewport.needle(), needle) {
			self.search = s
			return
		}

		s.deinit()
		self.search = none

		// When the search changes then we need to emit that it stopped.
		if cb := self.opts.event_cb {
			cb(Event{ kind: .total_matches, total: 0 }, self.opts.event_userdata)
			cb(Event{ kind: .selected_match, selected: none }, self.opts.event_userdata)
			cb(Event{ kind: .viewport_matches, viewport_matches: [] }, self.opts.event_userdata)
		}
	}

	// No needle means stop the search.
	if needle.len == 0 {
		return
	}

	// Setup our search state.
	mut new_search := Search.init(needle)

	// We need to grab the terminal lock and do an initial feed.
	self.opts.mutex.lock()
	new_search.feed(mut self.opts.terminal)
	self.opts.mutex.unlock()

	self.search = new_search
}

// Set our active state so it knows we're running.
//
// Source: Thread.startRefreshTimer.
fn (mut self SearchThread) start_refresh_timer() {
	self.refresh_active = true
}

// This will stop the refresh on the next iteration.
//
// Source: Thread.stopRefreshTimer.
fn (mut self SearchThread) stop_refresh_timer() {
	self.refresh_active = false
}

// ============================================================
// Search - the core cross-screen search state.
// ============================================================

// ScreenState collects all state related to screen switches, so that
// when we switch screens everything related goes stale too.
//
// Source: Search.ScreenState
struct ScreenState {
mut:
	// Last active screen key.
	key terminal.ScreenKey = .primary
	// Last notified total matches count.
	total ?usize
	// Last notified selected match index + highlight.
	selected ?ScreenStateSelectedMatch
}

// ScreenStateSelectedMatch caches the last-notified selection so we can
// detect changes without re-notifying.
//
// Source: Search.ScreenState.SelectedMatch
struct ScreenStateSelectedMatch {
mut:
	idx       usize
	highlight highlight.Untracked
}

// Search state.
//
// Source: Search
pub struct Search {
mut:
	// Active viewport search for the active screen.
	viewport ViewportSearch

	// The searchers for all the screens. Zig uses std.EnumMap keyed by
	// ScreenSet.Key; we model it as a map keyed by ScreenKey.
	screens map[terminal.ScreenKey]&ScreenSearch

	// All state related to screen switches.
	last_screen ScreenState

	// True if we sent the complete notification yet.
	last_complete bool

	// The last viewport matches we found are stale (need re-search).
	stale_viewport_matches bool
}

// Initialize the search state for the given needle.
//
// Source: Search.init
pub fn Search.init(needle []u8) Search {
	mut vp := ViewportSearch.init(needle)

	// We use dirty tracking for active area changes. Start with it dirty
	// so the first change is re-searched.
	vp.active_dirty = true

	return Search{
		viewport: vp
		screens: map[terminal.ScreenKey]&ScreenSearch{}
		last_screen: ScreenState{
			key: .primary
		}
		last_complete: false
		stale_viewport_matches: true
	}
}

// Free resources.
//
// Source: Search.deinit
pub fn (mut self Search) deinit() {
	self.viewport.deinit()
	for _, mut ss in self.screens {
		ss.deinit()
	}
	self.screens = map[terminal.ScreenKey]&ScreenSearch{}
}

// Returns true if all searches on all screens are complete.
//
// Source: Search.isComplete
pub fn (self &Search) is_complete() bool {
	for _, ss in self.screens {
		if !ss.state.is_complete() {
			return false
		}
	}
	return true
}

// Tick the search forward as much as possible without acquiring the big
// lock. Returns the overall tick progress.
//
// Source: Search.tick. Zig distinguishes tick outcomes via error unions
// (FeedRequired / SearchComplete / OutOfMemory). Our tick() returns a bool
// (more work?) and the state enum tells us if a feed is required, so we
// reproduce the same aggregate logic against that.
pub fn (mut self Search) tick() Tick {
	mut result := Tick.complete
	for _, mut ss in self.screens {
		if ss.state.is_complete() {
			// Ignore, good for us. State remains whatever it is.
			continue
		}

		if ss.state.needs_feed() {
			// Blocked on feed. If we think we're complete, we're not
			// because nothing made progress; otherwise keep our progress.
			if result == .complete {
				result = .blocked
			}
			continue
		}

		// Otherwise a tick makes progress.
		ss.tick()
		result = .progress
	}

	return result
}

// Grab the mutex and update any state that requires it, such as feeding
// additional data to the searches or updating the active screen.
//
// Source: Search.feed
pub fn (mut self Search) feed(mut t terminal.Terminal) {
	// Update our active screen.
	if t.screens.active_key != self.last_screen.key {
		// The default values will force resets of a bunch of other state
		// too to force recalculations and notifications.
		self.last_screen = ScreenState{
			key: t.screens.active_key
		}
	}

	// Reconcile our screens with the terminal screens. Remove searchers
	// for screens that no longer exist and add searchers for screens that
	// exist but we don't have yet.
	//
	// Remove screens we have that no longer exist or changed.
	for key in [terminal.ScreenKey.primary, terminal.ScreenKey.alternate] {
		if mut ss := self.screens[key] {
			actual := t.screens.get(key) or {
				// If the screen doesn't exist at all, remove it.
				ss.deinit()
				self.screens.delete(key)
				continue
			}
			// If the screen pointer changed, remove it; the screen was
			// totally reinitialized.
			if voidptr(actual) != voidptr(ss.screen) {
				ss.deinit()
				self.screens.delete(key)
			}
		}
	}
	// Add screens that exist but we don't have yet.
	for key in [terminal.ScreenKey.primary, terminal.ScreenKey.alternate] {
		if key in self.screens {
			continue
		}
		mut screen := t.screens.get(key) or { continue }
		mut ss := heap_screen_search(ScreenSearch.init(mut screen, self.viewport.needle()))
		self.screens[key] = ss
	}

	// See the `search_viewport_dirty` flag on the terminal to know what
	// exactly this is for. But, if this is set, we know the renderer found
	// the viewport/active area dirty, so we should mark it as dirty in our
	// viewport searcher so it forces a re-search.
	if t.flags.search_viewport_dirty() {
		t.flags.set_search_viewport_dirty(false)

		// Mark our viewport dirty so it researches the active.
		self.viewport.active_dirty = true

		// Reload our active area for our active screen.
		if mut ss := self.screens[t.screens.active_key] {
			ss.reload_active()
		}
	}

	// Check our viewport for changes against the same stable PageList
	// snapshot used by the active screen searcher.
	if active_search := self.screens[t.screens.active_key] {
		if self.viewport.update(active_search.pages) {
			self.stale_viewport_matches = true
		}
	}

	// Feed data to each screen search that needs it.
	for _, mut ss in self.screens {
		if ss.state.needs_feed() {
			ss.feed()
		}
	}
}

// Notify about any changes to the search state.
//
// This doesn't require any locking as it only reads internal state.
//
// Source: Search.notify
pub fn (mut self Search) notify(cb EventCallback, ud voidptr) {
	key := self.last_screen.key
	mut screen_search := self.screens[key] or { return }

	// Check our total match data.
	total := screen_search.matches_len()
	changed_total := if t := self.last_screen.total { t != total } else { true }
	if changed_total {
		self.last_screen.total = total
		cb(Event{ kind: .total_matches, total: total }, ud)
	}

	// Check our viewport matches. If they're stale, we do the viewport
	// search now. We do this as part of notify and not tick because the
	// viewport search is very fast and doesn't require ticked progress or
	// feeds.
	if self.stale_viewport_matches {
		// We always make stale as false. Even if we fail we require a
		// re-feed to re-search the viewport. The feed process makes it
		// stale again.
		self.stale_viewport_matches = false

		mut results := []highlight.Flattened{}
		for {
			hl := self.viewport.next() or { break }
			results << hl.clone()
		}
		cb(Event{ kind: .viewport_matches, viewport_matches: results }, ud)
	}

	// Check our last selected match data.
	if m := screen_search.selected {
		if flattened := screen_search.selected_match() {
			untracked := flattened.untracked()
			mut same := false
			if prev := self.last_screen.selected {
				if prev.idx == m.idx && prev.highlight.eql(untracked) {
					// Same selection, don't update it.
					same = true
				}
			}
			if !same {
				// New selection, notify!
				self.last_screen.selected = ScreenStateSelectedMatch{
					idx: m.idx
					highlight: untracked
				}
				cb(Event{
					kind: .selected_match
					selected: ThreadSelectedMatch{
						idx: m.idx
						highlight: flattened
					}
				}, ud)
			}
		}
	} else if self.last_screen.selected != none {
		self.last_screen.selected = none
		cb(Event{ kind: .selected_match, selected: none }, ud)
	}

	// Send our complete notification if we just completed.
	if !self.last_complete && self.is_complete() {
		self.last_complete = true
		cb(Event{ kind: .complete }, ud)
	}
}

// Heap-allocate a ScreenSearch so the screens map retains a stable pointer.
fn heap_screen_search(v ScreenSearch) &ScreenSearch {
	mut result := v
	return &result
}

// Case-insensitive ASCII byte-slice equality (std.ascii.eqlIgnoreCase).
fn eql_ignore_case(a []u8, b []u8) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		mut ca := a[i]
		mut cb := b[i]
		if ca >= `A` && ca <= `Z` {
			ca += 32
		}
		if cb >= `A` && cb <= `Z` {
			cb += 32
		}
		if ca != cb {
			return false
		}
	}
	return true
}
