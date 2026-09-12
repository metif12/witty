module renderer

// --- Original Ghostty Comments Start: src/renderer/Thread.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/renderer/Thread.zig
//
// Represents the renderer thread logic. The renderer thread is able to
// be woken up to render.
// Whether calls to `drawFrame` must be done from the app thread.
//
// If this is `true` then we send a `redraw_surface` message to the apprt
// whenever we need to draw instead of calling `drawFrame` directly.
// The type used for sending messages to the IO thread. For now this is
// hardcoded with a capacity. We can make this a comptime parameter in
// the future if we want it configurable.
// Allocator used for some state
// The main event loop for the application. The user data of this loop
// is always the allocator used to create the loop. This is a convenience
// so that users of the loop always have an allocator.
// This can be used to wake up the renderer and force a render safely from
// any thread.
// This can be used to stop the renderer on the next loop iteration.
// The timer used for rendering
// The timer used for draw calls. Draw calls don't update from the
// terminal state so they're much cheaper. They're used for animation
// and are paused when the terminal is not focused.
// This async is used to force a draw immediately. This does not
// coalesce like the wakeup does.
// The timer used for cursor blinking
// The surface we're rendering to.
// The underlying renderer implementation.
// Pointer to the shared state that is used to generate the final render.
// The mailbox that can be used to send this thread messages. Note
// this is a blocking queue so if it is full you will get errors (or block).
// Mailbox to send messages to the app thread
// Configuration we need derived from the main config.
// This is true when a blinking cursor should be visible and false
// when it should not be visible. This is toggled on a timer by the
// thread automatically.
// This is true when the inspector is active.
// This is true when the view is visible. This is used to determine
// if we should be rendering or not.
// This is true when the view is focused. This defaults to true
// and it is up to the apprt to set the correct value.
// Initialize the thread. This does not START the thread. This only sets
// up all the internal state necessary prior to starting the thread. It
// is up to the caller to start the thread with the threadMain entrypoint.
// Create our event loop.
// This async handle is used to "wake up" the renderer and force a render.
// This async handle is used to stop the loop and force the thread to end.
// The primary timer for rendering.
// Draw timer, see comments.
// Draw now async, see comments.
// Setup a timer for blinking the cursor
// The mailbox for messaging this thread
// Clean up the thread. This is only safe to call once the thread
// completes executing; the caller must join prior to this.
// Nothing can possibly access the mailbox anymore, destroy it.
// The main entrypoint for the thread.
// Call child function so we can use errors...
// In the future, we should expose this on the thread struct.
// Right now, on Darwin, `std.Thread.setName` can only name the current
// thread, and we have no way to get the current thread from within it,
// so instead we use this code to name the thread instead.
// Setup our crash metadata
// Setup our thread QoS
// Run our loop start/end callbacks if the renderer cares.
// Run our thread start/end callbacks. This is important because some
// renderers have to do per-thread setup. For example, OpenGL has to set
// some thread-local state since that is how it works.
// Start the async handlers
// Send an initial wakeup message so that we render right away.
// Start blinking the cursor.
// Start the draw timer
// Run
// Thread QoS classes are only relevant on macOS.
// If we aren't visible (our view is fully occluded) then we
// always drop our rendering priority down because it's just
// mostly wasted work.
//
// The renderer itself should be doing this as well (for example
// Metal will stop our DisplayLink) but this also helps with
// general forced updates and CPU usage i.e. a rebuild cells call.
// If we're not focused, but we're visible, then we set a higher
// than default priority because framerates still matter but it isn't
// as important as when we're focused.
// We are focused and visible, we are the definition of user interactive.
// If our renderer supports animations and has them, then we
// always have a draw timer.
// If our config says to always animate, we do so.
// Always animate
// Only when focused
// Never animate
// We're skipping the draw timer. Stop it on the next iteration.
// Set our active state so it knows we're running. We set this before
// even checking the active state in case we have a pending shutdown.
// If our draw timer is already active, then we don't have to do anything.
// Start the timer which loops
// Drain the mailbox.
// There's probably a more elegant way to do this...
//
// This is effectively an @autoreleasepool{} block, which we need in
// order to ensure that autoreleased objects are properly released.
// If our state didn't change we do nothing.
// Set our visible state
// Visibility affects our QoS class
// If we became visible then we immediately trigger a draw.
// We don't need to update frame data because that should
// still be happening.
// Notify the renderer so it can update any state.
// Note that we're explicitly today not stopping any
// cursor timers, draw timers, etc. These things have very
// little resource cost and properly maintaining their active
// state across different transitions is going to be bug-prone,
// so its easier to just let them keep firing and have them
// check the visible state themselves to control their behavior.
// If our state didn't change we do nothing.
// Set our state
// Focus affects our QoS class
// Set it on the renderer
// We always resync our draw timer (may disable it)
// If we're not focused, then we stop the cursor blink
// If we're focused, we immediately show the cursor again
// and then restart the timer.
// Stop and start the draw timer to capture the new
// hasAnimations value.
// Note we don't free the new value because we expect our
// allocators to match.
// Note we don't free the new value because we expect our
// allocators to match.
// Trigger a draw. This will not update frame data or anything, it will
// just trigger a draw/paint.
// If we're invisible, we do not draw.
// If the renderer is managing a vsync on its own, we only draw
// when we're forced to via `now`.
// When we wake up, we check the mailbox. Mailbox producers should
// wake up our thread after publishing.
// Render immediately
// The below is not used anymore but if we ever want to introduce
// a configuration to introduce a delay to coalesce renders, we can
// use this.
//
// // If the timer is already active then we don't have to do anything.
// if (t.render_c.state() == .active) return .rearm;
//
// // Timer is not active, let's start it
// t.render_h.run(
//     &t.loop,
//     &t.render_c,
//     10,
//     Thread,
//     t,
//     renderCallback,
// );
// Draw immediately
// This shouldn't happen so we log it.
// Draw
// Only continue if we're still active
// This shouldn't happen so we log it.
// Update our frame data
// Draw
// This is sent when our timer is canceled. That's fine.
// This shouldn't happen so we log it.
// This makes it easier to work across platforms where different platforms
// support different sets of errors, so we just unify it.
// fn prepFrameCallback(h: *libuv.Prepare) void {
//     _ = h;
//
//     tracy.frameMark();
// }
// Returns the interval for the blinking cursor in milliseconds.
// If we're running under Valgrind, the cursor blink adds enough
// churn that it makes some stalls annoying unless you're on a
// super powerful computer, so we delay it.
//
// This is a hack, we should change some of our cursor timer
// logic to be more efficient:
// https://github.com/ghostty-org/ghostty/issues/8003
//
// --- Original Ghostty Comments End: src/renderer/Thread.zig

import configpkg
import crash
import internal_os
import sync
import time

// Constants for renderer thread timing.
const draw_interval = 8 // 120 FPS (milliseconds)
const cursor_blink_interval_ms = 600 // milliseconds
const renderer_mailbox_capacity = 64

// ThreadDerivedConfig holds configuration derived from the main config
// that is needed by the renderer thread.
pub struct ThreadDerivedConfig {
pub mut:
	custom_shader_animation CustomShaderAnimation
}

// Custom shader animation mode.
pub enum CustomShaderAnimation {
	// Always animate custom shaders.
	always
	// Animate only when focused.
	true_
	// Never animate custom shaders.
	false_
}

pub fn ThreadDerivedConfig.init(config &configpkg.Config) ThreadDerivedConfig {
	return ThreadDerivedConfig{
		custom_shader_animation: match config.custom_shader_animation {
			.false_ { CustomShaderAnimation.false_ }
			.true_ { CustomShaderAnimation.true_ }
			.always { CustomShaderAnimation.always }
		}
	}
}

// Flags for the renderer thread state.
pub struct ThreadFlags {
pub mut:
	// This is true when a blinking cursor should be visible and false
	// when it should not be visible. This is toggled on a timer by the
	// thread automatically.
	cursor_blink_visible bool
	// This is true when the inspector is active.
	has_inspector bool
	// This is true when the view is visible. This is used to determine
	// if we should be rendering or not.
	visible bool = true
	// This is true when the view is focused. This defaults to true
	// and it is up to the apprt to set the correct value.
	focused bool = true
}

// RendererThread represents the renderer thread logic. The renderer thread
// is able to be woken up to render.
pub struct RendererThread {
pub mut:
	// The underlying renderer implementation.
	renderer &Renderer = unsafe { nil }

	// Pointer to the shared state that is used to generate the final render.
	state &RenderState = unsafe { nil }

	// The mailbox that can be used to send this thread messages.
	mailbox &RendererMailbox = unsafe { nil }

	// GTK requires GPU work on the application thread. This callback is the
	// translated App.Mailbox redraw_surface message boundary used there.
	app_redraw           Wakeup
	draw_from_app_thread bool

	// Configuration we need derived from the main config.
	config ThreadDerivedConfig

	// Thread state flags.
	flags ThreadFlags

	// Whether the draw timer is currently active.
	draw_active bool
	// Whether the draw completion is armed. This remains true for one pending
	// callback after draw_active is disabled.
	draw_timer_armed bool

	// Whether the cursor blink timer is currently active. This mirrors
	// the state of the `cursor_c` completion in Ghostty (whether the
	// blink timer is running). The actual xev timer is a boundary, so
	// we track the logical active state here to faithfully reproduce the
	// focus-handler start/stop logic.
	cursor_blink_active bool

	// Monotonic deadlines for the two periodic xev timers used by Ghostty.
	// V doesn't provide xev, so the event semaphore below drives an equivalent
	// single-threaded loop and these fields preserve the timer semantics.
	next_draw_at         u64
	next_cursor_blink_at u64

	// Cross-thread event state. Wakeups coalesce, draw-now requests do not,
	// matching the two separate xev.Async handles in Ghostty.
	event              &sync.Semaphore = unsafe { nil }
	event_mutex        &sync.Mutex = unsafe { nil }
	wakeup_requested   bool
	draw_now_requested u32
	stop_requested     bool
}

// The type used for sending messages to the renderer thread.
pub struct RendererMailbox {
pub mut:
	queue []RendererMessage
	mutex &sync.Mutex = unsafe { nil }
	space &sync.Cond = unsafe { nil }
}

pub fn RendererMailbox.create() &RendererMailbox {
	mutex := sync.new_mutex()
	return &RendererMailbox{
		queue: []RendererMessage{cap: renderer_mailbox_capacity}
		mutex: mutex
		space: sync.new_cond(mutex)
	}
}

pub fn (mut self RendererMailbox) destroy() {
	if self.mutex == unsafe { nil } {
		for msg in self.queue {
			msg.deinit()
		}
		self.queue.clear()
		return
	}
	self.mutex.lock()
	for msg in self.queue {
		msg.deinit()
	}
	self.queue.clear()
	self.mutex.unlock()
	self.mutex.destroy()
}

// Push a message to the mailbox.
pub fn (mut self RendererMailbox) push(msg RendererMessage) int {
	if self.mutex == unsafe { nil } {
		self.mutex = sync.new_mutex()
	}
	self.mutex.lock()
	defer {
		self.mutex.unlock()
	}
	if self.queue.len >= renderer_mailbox_capacity {
		return 0
	}
	self.queue << msg
	return 1
}

// Pop a message from the mailbox.
pub fn (mut self RendererMailbox) pop() ?RendererMessage {
	if self.mutex == unsafe { nil } {
		self.mutex = sync.new_mutex()
	}
	self.mutex.lock()
	defer {
		self.mutex.unlock()
	}
	if self.queue.len == 0 {
		return none
	}
	msg := self.queue[0]
	self.queue.delete(0)
	if self.space != unsafe { nil } {
		self.space.signal()
	}
	return msg
}

// Push a message, waiting until the renderer consumes queue space. Surface
// control messages use Ghostty's forever timeout and therefore cannot drop.
pub fn (mut self RendererMailbox) push_wait(msg RendererMessage) {
	if self.mutex == unsafe { nil } {
		self.mutex = sync.new_mutex()
		self.space = sync.new_cond(self.mutex)
	}
	self.mutex.lock()
	defer {
		self.mutex.unlock()
	}
	for self.queue.len >= renderer_mailbox_capacity {
		self.space.wait()
	}
	self.queue << msg
}

// Initialize the thread. This does not START the thread. This only sets
// up all the internal state necessary prior to starting the thread.
pub fn RendererThread.init(config &configpkg.Config, renderer_impl &Renderer, state &RenderState, app_redraw Wakeup) !RendererThread {
	mut mailbox := RendererMailbox.create()

	mut result := RendererThread{
		config: ThreadDerivedConfig.init(config)
		renderer: unsafe { renderer_impl }
		state: unsafe { state }
		mailbox: mailbox
		app_redraw: app_redraw
		event: sync.new_semaphore()
		event_mutex: sync.new_mutex()
	}
	$if linux {
		result.draw_from_app_thread = true
	}
	return result
}

// Clean up the thread.
pub fn (mut self RendererThread) deinit() {
	unsafe {
		self.mailbox.destroy()
		self.event.destroy()
		self.event_mutex.destroy()
	}
}

// The main entrypoint for the thread.
pub fn (mut self RendererThread) thread_main() {
	self.thread_main_inner() or {}
}

fn (mut self RendererThread) thread_main_inner() ! {
	$if macos {
		internal_os.set_thread_name('renderer')
	}

	crash.set_thread_state(crash.ThreadState{
		kind: .renderer
		surface: self.renderer.surface_mailbox.user_data
	})
	defer {
		crash.clear_thread_state()
	}

	self.set_qos_class()

	// Run the renderer lifecycle hooks on the renderer thread. The loop hook
	// installs platform event sources such as macOS CVDisplayLink.
	self.renderer.loop_enter(self)!
	defer {
		self.renderer.loop_exit()
	}
	self.renderer.thread_enter()!
	defer {
		self.renderer.thread_exit()
	}

	// Start blinking the cursor and arm the animation timer exactly as the
	// xev-backed renderer thread does.
	now := time.sys_mono_now()
	self.cursor_blink_active = true
	self.next_cursor_blink_at = now + cursor_blink_interval()

	self.sync_draw_timer()

	// Ghostty queues an initial async wakeup so the first iteration drains
	// messages and renders immediately.
	self.request_wakeup()

	for {
		timeout := self.next_timer_timeout(time.sys_mono_now())
		if timeout < 0 {
			self.event.wait()
		} else if timeout > 0 {
			_ = self.event.timed_wait(timeout)
		}

		stop, wakeup, draw_now_count := self.take_pending_events()
		if stop {
			break
		}
		if wakeup {
			self.drain_mailbox()!
			self.render_callback()
		}
		for _ in 0 .. draw_now_count {
			self.draw_frame(true)
		}

		current := time.sys_mono_now()
		if self.cursor_blink_active && current >= self.next_cursor_blink_at {
			self.next_cursor_blink_at = current + cursor_blink_interval()
			self.cursor_timer_callback()
		}
		if self.draw_timer_armed && current >= self.next_draw_at {
			self.draw_timer_callback()
		}
	}

	self.draw_active = false
	self.draw_timer_armed = false
	self.cursor_blink_active = false
}

// Sync the draw timer state based on configuration and focus.
fn (mut self RendererThread) sync_draw_timer() {
	mut active := false

	// If our renderer supports animations and has them, then we
	// always have a draw timer.
	if self.renderer.has_animations() {
		active = true
	}

	// If our config says to always animate, we do so.
	if !active {
		match self.config.custom_shader_animation {
			.always {
				active = true
			}
			.true_ {
				active = self.flags.focused
			}
			.false_ {}
		}
	}

	self.draw_active = active
	if active && !self.draw_timer_armed {
		self.draw_timer_armed = true
		self.next_draw_at = time.sys_mono_now() + draw_interval_ns()
	}
}

// Drain the mailbox.
fn (mut self RendererThread) drain_mailbox() ! {
	for {
		msg := self.mailbox.pop() or { break }
		match msg {
			CrashMessage {
				panic('crash request, crashing intentionally')
			}
			VisibleMessage {
				if self.flags.visible != msg.visible {
					self.flags.visible = msg.visible
					$if macos {
						self.set_qos_class()
					}
					if msg.visible {
						self.draw_frame(false)
					}
					self.renderer.set_visible(msg.visible)
				}
			}
			FocusMessage {
				// If our state didn't change we do nothing.
				if self.flags.focused != msg.focused {
					// Set our state
					self.flags.focused = msg.focused
					$if macos {
						self.set_qos_class()
					}

					// Set it on the renderer
					self.renderer.set_focus(msg.focused)!

					// We always resync our draw timer (may disable it)
					self.sync_draw_timer()

					if !msg.focused {
						if self.cursor_blink_active {
							self.cursor_blink_active = false
						}
					} else {
						// If we're focused, we immediately show the cursor again
						// and then restart the timer.
						if !self.cursor_blink_active {
							self.flags.cursor_blink_visible = true
							self.cursor_blink_active = true
							self.next_cursor_blink_at = time.sys_mono_now() + cursor_blink_interval()
						}
					}
				}
			}
			ResetCursorBlinkMessage {
				self.flags.cursor_blink_visible = true
				if self.cursor_blink_active {
					self.next_cursor_blink_at = time.sys_mono_now() + cursor_blink_interval()
				}
			}
			FontGridMessage {
				self.renderer.set_font_grid(msg.grid)
				if msg.set != unsafe { nil } {
					mut set := unsafe { msg.set }
					set.deref(msg.old_key)
				}
			}
			ResizeMessage {
				self.renderer.set_screen_size(msg.size)
			}
			ChangeConfigMessage {
				self.change_config(msg.thread_config)
				self.renderer.change_config(msg.renderer_config)!
				self.sync_draw_timer()
			}
			SearchViewportMatchesMessage {
				for mut old in self.renderer.search_matches {
					old.deinit()
				}
				self.renderer.search_matches = msg.matches
				self.renderer.search_matches_dirty = true
			}
			SearchSelectedMatchMessage {
				if mut old := self.renderer.search_selected_match {
					old.deinit()
				}
				self.renderer.search_selected_match = msg.match_
				self.renderer.search_matches_dirty = true
			}
			InspectorMessage {
				self.flags.has_inspector = msg.active
			}
			MacosDisplayIdMessage {
				self.renderer.set_macos_display_id(msg.display_id)
			}
		}
	}
}

// Apply the same visibility/focus priority policy as Ghostty's renderer
// thread. This only exists on Darwin at compile time.
fn (self &RendererThread) set_qos_class() {
	$if macos {
		class := if !self.flags.visible {
			internal_os.QosClass.utility
		} else if !self.flags.focused {
			internal_os.QosClass.user_initiated
		} else {
			internal_os.QosClass.user_interactive
		}
		internal_os.set_qos_class(class) or {}
	}
}

fn (mut self RendererThread) change_config(config &ThreadDerivedConfig) {
	self.config = *config
}

// Trigger a draw. This will not update frame data or anything, it will
// just trigger a draw/paint.
fn (mut self RendererThread) draw_frame(now bool) {
	// If we're invisible, we do not draw.
	if !self.flags.visible {
		return
	}

	// If the renderer is managing a vsync on its own, we only draw
	// when we're forced to via `now`.
	if !now && self.renderer.has_vsync() {
		return
	}

	if self.draw_from_app_thread {
		self.app_redraw.notify() or {}
	} else {
		self.renderer.draw_frame(false) or {}
	}
}

// Render callback - updates frame data and draws.
fn (mut self RendererThread) render_callback() {
	if self.state == unsafe { nil } || self.state.terminal_ == unsafe { nil } {
		return
	}
	// Terminal state is shared with termio. Keep the same critical section as
	// Ghostty while rebuilding the renderer's immutable frame snapshot.
	if self.state.mutex != unsafe { nil } {
		self.state.mutex.lock()
		self.renderer.update_frame(self.state, self.flags.cursor_blink_visible) or {}
		self.state.mutex.unlock()
	} else {
		self.renderer.update_frame(self.state, self.flags.cursor_blink_visible) or {}
	}

	// Draw
	self.draw_frame(false)
}

// Cursor blink timer callback. This is fired by the blink timer on each
// interval. It toggles the cursor's visibility and wakes up the renderer.
fn (mut self RendererThread) cursor_timer_callback() {
	// If the blink timer isn't active (e.g. we lost focus), do nothing.
	if !self.cursor_blink_active {
		return
	}

	// Toggle the cursor visibility state.
	self.flags.cursor_blink_visible = !self.flags.cursor_blink_visible

	// Wake up the renderer so it can redraw with the new blink state.
	self.request_wakeup()
}

// Draw once for an armed timer completion and rearm only when animation is
// still active. A disabled timer therefore fires its already-pending callback.
fn (mut self RendererThread) draw_timer_callback() {
	self.draw_timer_armed = false
	self.draw_frame(false)
	if self.draw_active {
		self.draw_timer_armed = true
		self.next_draw_at = time.sys_mono_now() + draw_interval_ns()
	}
}

// send publishes a mailbox message and wakes the render loop. A full mailbox
// is reported to the producer, matching Ghostty's bounded BlockingQueue.
pub fn (mut self RendererThread) send(msg RendererMessage) bool {
	if self.mailbox.push(msg) == 0 {
		return false
	}
	self.request_wakeup()
	return true
}

// send_wait publishes an undroppable surface-control message and wakes the
// render loop after it has been enqueued.
pub fn (mut self RendererThread) send_wait(msg RendererMessage) {
	self.mailbox.push_wait(msg)
	self.request_wakeup()
}

// wakeup coalesces frame rebuilds until the render loop observes the request.
pub fn (mut self RendererThread) wakeup() {
	self.request_wakeup()
}

// draw_now queues a draw that does not rebuild terminal frame data.
pub fn (mut self RendererThread) draw_now() {
	self.event_mutex.lock()
	self.draw_now_requested++
	self.event_mutex.unlock()
	self.event.post()
}

// stop ends the render loop on its next iteration.
pub fn (mut self RendererThread) stop() {
	self.event_mutex.lock()
	self.stop_requested = true
	self.event_mutex.unlock()
	self.event.post()
}

fn (mut self RendererThread) request_wakeup() {
	self.event_mutex.lock()
	should_post := !self.wakeup_requested
	self.wakeup_requested = true
	self.event_mutex.unlock()
	if should_post {
		self.event.post()
	}
}

fn (mut self RendererThread) take_pending_events() (bool, bool, u32) {
	self.event_mutex.lock()
	stop := self.stop_requested
	wakeup := self.wakeup_requested
	draw_now_count := self.draw_now_requested
	self.wakeup_requested = false
	self.draw_now_requested = 0
	self.event_mutex.unlock()
	return stop, wakeup, draw_now_count
}

fn (self &RendererThread) next_timer_timeout(now u64) i64 {
	mut deadline := u64(0)
	if self.cursor_blink_active {
		deadline = self.next_cursor_blink_at
	}
	if self.draw_timer_armed && (deadline == 0 || self.next_draw_at < deadline) {
		deadline = self.next_draw_at
	}
	if deadline == 0 {
		return -1
	}
	if deadline <= now {
		return 0
	}
	return i64(deadline - now)
}

// Returns the interval for the blinking cursor in nanoseconds.
fn cursor_blink_interval() u64 {
	return cursor_blink_interval_ms * u64(time.millisecond)
}

fn draw_interval_ns() u64 {
	return draw_interval * u64(time.millisecond)
}
