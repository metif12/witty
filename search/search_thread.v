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
import terminal
import highlight
import datastruct
import internal_os
import log
import xev

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
// Source: Thread.Message (tagged union).

// Change the search term. If no prior search term is given this
// will start a search. If an existing search term is given this will
// stop the prior search and start a new one.
pub struct MessageChangeNeedle {
pub mut:
	needle datastruct.MessageData[u8]
}

// Select a search result.
pub struct MessageSelect {
pub:
	select Select
}

// SearchThreadMessage is the tagged union posted to the search thread's mailbox.
pub type SearchThreadMessage = MessageChangeNeedle | MessageSelect

pub type Message = SearchThreadMessage

// Events that can be emitted from the search thread. The caller
// chooses to handle these as they see fit.
//
// Source: Thread.Event (tagged union).

// ThreadSelectedMatch represents a selected search result for the search
// thread. Named ThreadSelectedMatch to avoid conflict with SelectedMatch
// in screen_search.v.
//
// Source: Thread.Event.SelectedMatch
pub struct ThreadSelectedMatch {
pub mut:
	idx       uint
	highlight highlight.Flattened
}

// Search is quitting. The search thread is exiting.
pub struct EventQuit {}

// Search is complete for the given needle on all screens.
pub struct EventComplete {}

// Total matches on the current active screen have changed.
pub struct EventTotalMatches {
pub:
	total uint
}

// Selected match changed.
pub struct EventSelectedMatch {
pub:
	selected ?ThreadSelectedMatch
}

// Matches in the viewport have changed. The memory is owned by the
// search thread and is only valid during the callback.
pub struct EventViewportMatches {
pub:
	matches []highlight.Flattened
}

// Event is an event emitted from the search thread: the source's tagged
// union.
pub type Event = EventComplete
	| EventQuit
	| EventSelectedMatch
	| EventTotalMatches
	| EventViewportMatches

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
pub struct SearchThread {
pub mut:
	// The mailbox that can be used to send this thread messages. Note
	// this is a blocking queue so if it is full you will get errors (or block).
	mailbox &Mailbox = unsafe { nil }

	// The event loop for the search thread.
	loop xev.Loop

	// This can be used to wake up the renderer and force a render safely from
	// any thread.
	wakeup   xev.Async
	wakeup_c xev.Completion

	// This can be used to stop the thread on the next loop iteration.
	stop   xev.Async
	stop_c xev.Completion

	// The timer used for refreshing the terminal state to determine if
	// we have a stale active area, viewport, screen change, etc. This is
	// CPU intensive so we stop doing this under certain conditions.
	refresh        xev.Timer
	refresh_c      xev.Completion
	refresh_active bool
mut:
	// Search state. Starts as none and is populated when a search is
	// started (a needle is given).
	search ?Search

	// The options used to initialize this thread.
	opts ThreadOptions
}

// The type used for sending messages to the thread.
pub type Mailbox = datastruct.BlockingQueue[SearchThreadMessage]

// create allocates the mailbox with its fixed source capacity. V generics have
// no integer parameters, so the capacity is supplied here instead of the type.
pub fn Mailbox.create() !&Mailbox {
	return datastruct.BlockingQueue.create[SearchThreadMessage](64)!
}

// Initialize the thread. This does not START the thread. This only sets
// up all the internal state necessary prior to starting the thread. It
// is up to the caller to start the thread with the threadMain entrypoint.
//
// The state is heap-allocated so its loop and completions keep a stable
// address, which Ghostty gets by storing it in the Surface.
pub fn SearchThread.init(opts ThreadOptions) !&SearchThread {
	// Zig's errdefers are emulated by reached defers that run until init succeeds.
	mut init_ok := false

	// The mailbox for messaging this thread
	mut mailbox := Mailbox.create()!
	defer {
		if !init_ok {
			mailbox.destroy()
		}
	}

	// Create our event loop.
	mut loop := xev.Loop.init(xev.Options{})!
	defer {
		if !init_ok {
			loop.deinit()
		}
	}

	// This async handle is used to "wake up" the renderer and force a render.
	mut wakeup_h := xev.Async.init()!
	defer {
		if !init_ok {
			wakeup_h.deinit()
		}
	}

	// This async handle is used to stop the loop and force the thread to end.
	mut stop_h := xev.Async.init()!
	defer {
		if !init_ok {
			stop_h.deinit()
		}
	}

	// Refresh timer, see comments.
	refresh_h := xev.Timer.init()!
	defer {
		if !init_ok {
			refresh_h.deinit()
		}
	}

	init_ok = true
	return &SearchThread{
		mailbox: mailbox
		loop:    loop
		wakeup:  wakeup_h
		stop:    stop_h
		refresh: refresh_h
		opts:    opts
	}
}

// Clean up the thread. This is only safe to call once the thread
// completes executing; the caller must join prior to this.
pub fn (mut self SearchThread) deinit() {
	self.refresh.deinit()
	self.wakeup.deinit()
	self.stop.deinit()
	self.loop.deinit()
	// Nothing can possibly access the mailbox anymore, destroy it.
	unsafe {
		self.mailbox.destroy()
	}

	if mut s := self.search {
		s.deinit()
		self.search = none
	}
}

// The main entrypoint for the thread.
pub fn (mut self SearchThread) thread_main() {
	// Call child function so we can use errors...
	self.thread_main_() or {
		// In the future, we should expose this on the thread struct.
		log.warn('search thread err=${err}')
	}
}

fn (mut self SearchThread) thread_main_() ! {
	defer {
		log.debug('search thread exited')
	}
	// Right now, on Darwin, `std.Thread.setName` can only name the current
	// thread, and we have no way to get the current thread from within it,
	// so instead we use this code to name the thread instead.
	$if macos {
		internal_os.set_thread_name('search')

		// We can run with lower priority than other threads.
		class := internal_os.QosClass.utility
		internal_os.set_qos_class(class) or {
			log.warn('error setting QoS class err=${err}')
		}
		log.debug('thread QoS class set class=${class}')
	}

	// Start the async handlers
	self.wakeup.wait(mut self.loop, &self.wakeup_c, self, search_thread_wakeup_callback)
	self.stop.wait(mut self.loop, &self.stop_c, self, search_thread_stop_callback)

	// Send an initial wakeup so we drain our mailbox immediately.
	self.wakeup.notify()!

	// Start the refresh timer
	self.start_refresh_timer()

	// Run
	log.debug('starting search thread')
	defer {
		log.debug('starting search thread shutdown')

		// Send the quit message
		if cb := self.opts.event_cb {
			cb(EventQuit{}, self.opts.event_userdata)
		}
	}

	// Unlike some of our other threads, we interleave search work
	// with our xev loop so that we can try to make forward search progress
	// while also listening for messages.
	for {
		// If our loop is canceled then we drain our messages and quit.
		if self.loop.stopped() {
			for {
				message := self.mailbox.pop() or { break }
				log.debug('mailbox message ignored during shutdown=${message}')
			}

			return
		}

		// V optionals hold the search by value, so it is written back before
		// the loop runs callbacks that may replace it.
		mut s := self.search or {
			// If we're not actively searching, we can block the loop
			// until it does some work.
			self.loop.run(.once)!
			continue
		}

		// If we have an active search, we always send any pending
		// notifications. Even if the search is complete, there may be
		// notifications to send.
		if cb := self.opts.event_cb {
			s.notify(cb, self.opts.event_userdata)
		}

		if s.is_complete() {
			// If our search is complete, there's no more work to do, we
			// can block until we have an xev action.
			self.search = s
			self.loop.run(.once)!
			continue
		}

		// Tick the search. This will trigger any event callbacks, lock
		// for data loading, etc.
		match s.tick() {
			// We're complete now when we were not before. Notify!
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

		// We have an active search, so we only want to process messages
		// we have but otherwise return immediately so we can continue the
		// search. If the above completed the search, we still want to
		// go around the loop as quickly as possible to send notifications,
		// and then we'll block on the loop next time.
		self.loop.run(.no_wait)!
	}
}

// Drain the mailbox.
fn (mut self SearchThread) drain_mailbox() ! {
	for {
		message := self.mailbox.pop() or { break }
		log.debug('mailbox message=${message}')
		match message {
			MessageChangeNeedle {
				mut v := message.needle
				self.change_needle(v.slice())
				v.deinit()
			}
		MessageSelect {
				self.do_select(message.select)!
			}
		}
	}
}

// Select a search result and scroll it into view when necessary.
//
// Source: Thread.select.
fn (mut self SearchThread) do_select(sel Select) ! {
	mut s := self.search or { return }
	key := s.last_screen.key

	self.opts.mutex.lock()
	if mut screen_search := s.screens[key] {
		// Make the selection. Ignore the result because we don't care if
		// the selection didn't change.
		screen_search.do_select(sel) or {
			self.opts.mutex.unlock()
			self.search = s
			return err
		}
		flattened := screen_search.selected_match() or {
			self.opts.mutex.unlock()
			self.search = s
			return
		}

		// No matter what we reset our selected match cache. This will
		// trigger a callback which will trigger the renderer to wake up so
		// it can be notified the screen scrolled.
		s.last_screen.selected = none

		// Grab the current screen and see if this match is visible within
		// the viewport already. If it is, we do nothing.
		mut screen := self.opts.terminal.screens.get(key) or {
			self.opts.mutex.unlock()
			self.search = s
			return
		}

		// Grab the viewport. Viewports and selections are usually small
		// so this check isn't very expensive, despite appearing O(N^2),
		// both Ns are usually equal to 1.
		mut it := screen.pages.page_iterator(.right_down, terminal.Point.new(.viewport,
			terminal.Coordinate{}), none)
		mut visible := false
		outer: for {
			chunk := it.next() or { break }
			for hl_chunk in flattened.chunks {
				if chunk.overlaps(terminal.PageChunk{
					node:  hl_chunk.node
					start: hl_chunk.start
					end:   hl_chunk.end
				})
				{
					visible = true
					break outer
				}
			}
		}

		if !visible {
			screen.scroll(terminal.ScrollPin{
				pin: flattened.start_pin()
			})
		}
	}
	self.opts.mutex.unlock()

	self.search = s
}

// Change the search term to the given value.
//
// Source: Thread.changeNeedle
fn (mut self SearchThread) change_needle(needle []u8) {
	log.debug("changing search needle to '${needle.bytestr()}'")

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
			cb(EventTotalMatches{ total: 0 }, self.opts.event_userdata)
			cb(EventSelectedMatch{ selected: none }, self.opts.event_userdata)
			cb(EventViewportMatches{ matches: [] }, self.opts.event_userdata)
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

fn (mut self SearchThread) start_refresh_timer() {
	// Set our active state so it knows we're running. We set this before
	// even checking the active state in case we have a pending shutdown.
	self.refresh_active = true

	// If our timer is already active, then we don't have to do anything.
	if self.refresh_c.state() == .active {
		return
	}

	// Start the timer which loops
	self.refresh.run(mut self.loop, &self.refresh_c, refresh_interval, self, search_thread_refresh_callback)
}

fn (mut self SearchThread) stop_refresh_timer() {
	// This will stop the refresh on the next iteration.
	self.refresh_active = false
}

fn search_thread_wakeup_callback(self_ voidptr, _ &xev.Loop, _ &xev.Completion, r ?xev.ErrorKind) xev.CallbackAction {
	if err := r {
		log.warn('error in wakeup err=${err}')
		return .rearm
	}

	mut self := unsafe { &SearchThread(self_) }

	// When we wake up, we drain the mailbox. Mailbox producers should
	// wake up our thread after publishing.
	self.drain_mailbox() or { log.warn('error draining mailbox err=${err}') }

	return .rearm
}

fn search_thread_stop_callback(self_ voidptr, _ &xev.Loop, _ &xev.Completion, r ?xev.ErrorKind) xev.CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	mut self := unsafe { &SearchThread(self_) }
	self.loop.stop()
	return .disarm
}

fn search_thread_refresh_callback(self_ voidptr, _ &xev.Loop, _ &xev.Completion, r ?xev.ErrorKind) xev.CallbackAction {
	if _ := r {
		panic('unreachable')
	}
	if self_ == unsafe { nil } {
		// This shouldn't happen so we log it.
		log.warn('refresh callback fired without data set')
		return .disarm
	}
	mut self := unsafe { &SearchThread(self_) }

	// Run our feed if we have a search active.
	if mut s := self.search {
		self.opts.mutex.lock()
		s.feed(mut self.opts.terminal)
		self.opts.mutex.unlock()
		self.search = s
	}

	// Only continue if we're still active
	if self.refresh_active {
		self.refresh.run(mut self.loop, &self.refresh_c, refresh_interval, self, search_thread_refresh_callback)
	}

	return .disarm
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
	total ?uint
	// Last notified selected match index + highlight.
	selected ?ScreenStateSelectedMatch
}

// ScreenStateSelectedMatch caches the last-notified selection so we can
// detect changes without re-notifying.
//
// Source: Search.ScreenState.SelectedMatch
struct ScreenStateSelectedMatch {
mut:
	idx       uint
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
		new_screen_search := ScreenSearch.init(mut screen, self.viewport.needle()) or {
			log.warn('error initializing screen search for key=${key} err=${err}')
			continue
		}
		mut ss := heap_screen_search(new_screen_search)
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
			ss.reload_active() or {
				log.warn('error reloading active area for screen key=${t.screens.active_key} err=${err}')
			}
		}
	}

	// Check our viewport for changes.
	if self.viewport.update(&t.screens.active.pages) {
		self.stale_viewport_matches = true
	}

	// Feed data to each screen search that needs it.
	for key, mut ss in self.screens {
		if ss.state.needs_feed() {
			ss.feed() or {
				log.warn('error feeding screen search key=${key} err=${err}')
			}
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
		log.debug('notifying total matches=${total}')
		self.last_screen.total = total
		cb(EventTotalMatches{ total: total }, ud)
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
		log.debug('notifying viewport matches len=${results.len}')
		cb(EventViewportMatches{ matches: results }, ud)
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
				log.debug('notifying selection updated idx=${m.idx}')
				self.last_screen.selected = ScreenStateSelectedMatch{
					idx: m.idx
					highlight: untracked
				}
				cb(EventSelectedMatch{
					selected: ThreadSelectedMatch{
						idx: m.idx
						highlight: flattened
					}
				}, ud)
			}
		}
	} else if self.last_screen.selected != none {
		log.debug('notifying selection cleared')
		self.last_screen.selected = none
		cb(EventSelectedMatch{ selected: none }, ud)
	}

	// Send our complete notification if we just completed.
	if !self.last_complete && self.is_complete() {
		log.debug('notifying search complete')
		self.last_complete = true
		cb(EventComplete{}, ud)
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
