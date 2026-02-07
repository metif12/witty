module renderer

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
				if self.flags.focused != msg.focused {
					self.flags.focused = msg.focused
					self.renderer.set_focus(msg.focused)!
					self.sync_draw_timer()
					if !msg.focused {
						// Stop cursor blink when not focused
					} else {
						// Restart cursor blink when focused
						self.flags.cursor_blink_visible = true
					}
				}
			}
			ResetCursorBlinkMessage {
				self.flags.cursor_blink_visible = true
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

// Returns the interval for the blinking cursor in milliseconds.
fn cursor_blink_interval() u64 {
	return cursor_blink_interval_ms
}
