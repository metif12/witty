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

// Constants for renderer thread timing.
const draw_interval = 8 // 120 FPS (milliseconds)
const cursor_blink_interval_ms = 600 // milliseconds

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
		custom_shader_animation: .true_
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

	// Configuration we need derived from the main config.
	config ThreadDerivedConfig

	// Thread state flags.
	flags ThreadFlags

	// Whether the draw timer is currently active.
	draw_active bool

	// Whether the cursor blink timer is currently active. This mirrors
	// the state of the `cursor_c` completion in Ghostty (whether the
	// blink timer is running). The actual xev timer is a boundary, so
	// we track the logical active state here to faithfully reproduce the
	// focus-handler start/stop logic.
	cursor_blink_active bool
}

// The type used for sending messages to the renderer thread.
pub struct RendererMailbox {
pub mut:
	queue []RendererMessage
}

pub fn RendererMailbox.create() &RendererMailbox {
	return &RendererMailbox{}
}

pub fn (mut self RendererMailbox) destroy() {
	self.queue.clear()
}

// Push a message to the mailbox.
pub fn (mut self RendererMailbox) push(msg RendererMessage) int {
	self.queue << msg
	return 1
}

// Pop a message from the mailbox.
pub fn (mut self RendererMailbox) pop() ?RendererMessage {
	if self.queue.len == 0 {
		return none
	}
	msg := self.queue[0]
	self.queue.delete(0)
	return msg
}

// Initialize the thread. This does not START the thread. This only sets
// up all the internal state necessary prior to starting the thread.
pub fn RendererThread.init(config &configpkg.Config, renderer_impl &Renderer, state &RenderState) !RendererThread {
	mut mailbox := RendererMailbox.create()

	return RendererThread{
		config: ThreadDerivedConfig.init(config)
		renderer: unsafe { renderer_impl }
		state: unsafe { state }
		mailbox: mailbox
	}
}

// Clean up the thread.
pub fn (mut self RendererThread) deinit() {
	unsafe {
		self.mailbox.destroy()
	}
}

// The main entrypoint for the thread.
pub fn (mut self RendererThread) thread_main() {
	// XTODO: Thread main loop requires xev event loop integration.
	// The loop should:
	// 1. Start async handlers (wakeup, stop, draw_now)
	// 2. Start render timer (8ms interval = 120 FPS)
	// 3. Start cursor blink timer (600ms interval)
	// 4. Start draw timer if animations are enabled
	// 5. Run the event loop until stopped
	self.thread_main_inner() or {}
}

fn (mut self RendererThread) thread_main_inner() ! {
	// Start blinking the cursor
	self.flags.cursor_blink_visible = true
	self.cursor_blink_active = true

	// Sync draw timer
	self.sync_draw_timer()

	// Send an initial wakeup so that we render right away
	self.drain_mailbox()!

	// Render immediately
	self.render_callback()
}

// Sync the draw timer state based on configuration and focus.
fn (mut self RendererThread) sync_draw_timer() {
	// If our renderer supports animations and has them, then we
	// always have a draw timer.
	if self.renderer.has_animations() {
		self.draw_active = true
		return
	}

	// If our config says to always animate, we do so.
	match self.config.custom_shader_animation {
		.always {
			self.draw_active = true
			return
		}
		.true_ {
			if self.flags.focused {
				self.draw_active = true
				return
			}
		}
		.false_ {}
	}

	// We're skipping the draw timer.
	self.draw_active = false
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

					// Set it on the renderer
					self.renderer.set_focus(msg.focused)!

					// We always resync our draw timer (may disable it)
					self.sync_draw_timer()

					if !msg.focused {
						// If we're not focused, then we stop the cursor blink.
						// The xev timer cancel is a boundary; here we just mark
						// the blink timer as inactive so it stops toggling.
						if self.cursor_blink_active {
							self.cursor_blink_active = false
						}
					} else {
						// If we're focused, we immediately show the cursor again
						// and then restart the timer.
						if !self.cursor_blink_active {
							self.flags.cursor_blink_visible = true
							self.cursor_blink_active = true
						}
					}
				}
			}
			ResetCursorBlinkMessage {
				self.flags.cursor_blink_visible = true
				// If the blink timer is active, reset it so the cursor stays
				// visible for a full interval after the reset.
				if self.cursor_blink_active {
					// The xev timer reset is a boundary; the logical effect is
					// that cursor_blink_visible is now true (set above).
				}
			}
			FontGridMessage {
				self.renderer.set_font_grid(msg.grid)
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
				self.renderer.search_matches_dirty = true
			}
			SearchSelectedMatchMessage {
				self.renderer.search_matches_dirty = true
			}
			InspectorMessage {
				self.flags.has_inspector = msg.active
			}
			MacosDisplayIdMessage {
				// macOS display ID change handling
				_ = msg.display_id
			}
		}
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

	self.renderer.draw_frame(false) or {}
}

// Render callback - updates frame data and draws.
fn (mut self RendererThread) render_callback() {
	// Update our frame data
	self.renderer.update_frame(self.state.terminal_, self.flags.cursor_blink_visible) or {}

	// Draw
	self.draw_frame(false)
}

// Cursor blink timer callback. This is fired by the blink timer on each
// interval. It toggles the cursor's visibility, wakes up the renderer so
// the change is drawn, and (in Ghostty) re-arms the timer. The xev timer
// re-arm is a boundary; here we just perform the toggle + wakeup.
fn (mut self RendererThread) cursor_timer_callback() {
	// If the blink timer isn't active (e.g. we lost focus), do nothing.
	if !self.cursor_blink_active {
		return
	}

	// Toggle the cursor visibility state.
	self.flags.cursor_blink_visible = !self.flags.cursor_blink_visible

	// Wake up the renderer so it can redraw with the new blink state.
	self.wakeup() or {}
}

// Wake up the renderer thread to force a render. The xev async wakeup is
// a boundary; here we drain the mailbox and render immediately.
fn (mut self RendererThread) wakeup() ! {
	self.drain_mailbox()!
	self.render_callback()
}

// Returns the interval for the blinking cursor in milliseconds.
fn cursor_blink_interval() u64 {
	return cursor_blink_interval_ms
}
