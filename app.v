module main

// App is the primary GUI application for ghostty. This builds the window,
// sets up the renderer, etc. The primary run loop is started by calling
// the "run" function.
//
// This is the core application logic that is shared across all application
// runtimes (GTK, macOS Cocoa, browser, etc.). The apprt module provides
// the platform-specific implementation, and this module contains the
// platform-independent logic.

import apprt
import configpkg
import font
import time

// SurfaceList is a list of active surfaces managed by the app.
// XTODO: When full apprt.Surface type is available, change to []&apprt.Surface.
type SurfaceList = []&SurfaceRef

// SurfaceRef is a reference to a surface. This is a placeholder type
// until the full Surface infrastructure is connected.
// XTODO: Replace with the actual Surface type from the surface module.
@[heap]
pub struct SurfaceRef {
pub mut:
	// A unique identifier for this surface (for debugging/tracking).
	id int
}

// core returns the core surface reference. This is a placeholder
// until the full Surface type is available.
pub fn (s &SurfaceRef) core() &SurfaceRef {
	return s
}

// needs_confirm_quit returns whether this surface needs confirmation
// before quitting (e.g. because it has a running process).
// XTODO: Implement when process tracking is available.
pub fn (s &SurfaceRef) needs_confirm_quit() bool {
	return false
}

// close requests the surface to close.
// XTODO: Implement when full surface lifecycle is available.
pub fn (s &SurfaceRef) close() {
}

// handle_message handles a message sent to this surface.
// XTODO: Implement when surface message handling is available.
pub fn (s &SurfaceRef) handle_message(msg SurfaceMessage) ! {
	_ = msg
}

// ChangeConfigMsg is a placeholder for config-change messages sent to a surface.
pub struct ChangeConfigMsg {
pub:
	// XTODO: Should hold a reference to the new config.
	placeholder int
}

// RedrawMsg is a placeholder for redraw messages sent to a surface.
pub struct RedrawMsg {}

// App is the primary application struct. It manages the list of surfaces,
// font grid sets, configuration state, and the mailbox for inter-thread
// messaging.
pub struct App {
pub mut:
	// The list of surfaces that are currently active.
	surfaces SurfaceList

	// This is true if the app that Ghostty is in is focused. This may
	// mean that no surfaces (terminals) are focused but the app is still
	// focused, i.e. maybe an about window. On macOS, this concept is known
	// as the "active" app while focused windows are known as the
	// "main" window.
	//
	// This is used to determine if keyboard shortcuts that are non-global
	// should be processed. If the app is not focused, then we don't want
	// to process keyboard shortcuts that are not global.
	//
	// This defaults to true since we assume that the app is focused when
	// Ghostty is initialized but a well behaved apprt should call
	// focusEvent to set this to the correct value right away.
	focused bool = true

	// The last focused surface. This surface may not be valid;
	// you must always call has_surface to validate it.
	focused_surface ?&SurfaceRef

	// The mailbox that can be used to send this thread messages. Note
	// this is a blocking queue so if it is full you will get errors (or block).
	mailbox Mailbox

	// The set of font GroupCache instances shared by surfaces with the
	// same font configuration.
	font_grid_set font.SharedGridSet

	// Used to rate limit desktop notifications. Some platforms (notably macOS)
	// will run out of resources if desktop notifications are sent too fast
	// and the OS will kill Ghostty.
	last_notification_digest u64
	last_notification_time   ?time.Time

	// The conditional state of the configuration. See the equivalent field
	// in the Surface struct for more information. In this case, this applies
	// to the app-level config and as a default for new surfaces.
	config_conditional_state configpkg.ConditionalState

	// Set to false once we've created at least one surface. This
	// never goes true again. This can be used by surfaces to determine
	// if they are the first surface.
	first bool = true
}

// create allocates and initializes a new App instance on the heap.
// Returns a stable pointer to the app instance which is required
// for callbacks.
pub fn App.create() !&App {
	mut a := &App{}
	a.init()!
	return a
}

// init initializes the main app instance. This creates the main window,
// sets up the renderer state, compiles the shaders, etc. This is the
// primary "startup" logic.
//
// After calling this function, well behaved apprts should then call
// focus_event to set the initial focus state of the app.
pub fn (mut self App) init() ! {
	self.font_grid_set = font.SharedGridSet.init() or { return err }
	self.surfaces = SurfaceList([]&SurfaceRef{})
	self.mailbox = Mailbox{}
	self.config_conditional_state = configpkg.ConditionalState{}
	self.focused = true
	self.first = true
}

// deinit cleans up the app, destroying all surfaces and freeing resources.
pub fn (mut self App) deinit() {
	// Clean up all our surfaces.
	// XTODO: Call deinit on each surface when surface lifecycle is implemented.
	self.surfaces = SurfaceList([]&SurfaceRef{})

	// Clean up our font group cache.
	// We should have zero items in the grid set at this point because
	// destroy only gets called when the app is shutting down and this
	// should gracefully close all surfaces.
	self.font_grid_set.deinit()
}

// destroy deinitializes the app and frees its memory.
pub fn (mut self App) destroy() {
	self.deinit()
	// In V, memory is managed by the GC, so no explicit free needed.
	// If using manual memory management, you would free here.
}

// tick ticks the app loop. This will drain our mailbox and process those
// events. This should be called by the application runtime on every loop
// tick.
pub fn (mut self App) tick(mut rt_app apprt.RuntimeApp) ! {
	// Drain our mailbox.
	self.drain_mailbox(mut rt_app)!
}

// update_config updates the configuration associated with the app. This
// can only be called from the main thread. The caller owns the config
// memory. The memory can be freed immediately when this returns.
//
// XTODO: Full implementation requires surface config update propagation.
pub fn (mut self App) update_config(mut rt_app apprt.RuntimeApp, config &configpkg.Config) ! {
	// Go through and update all of the surface configurations.
	// XTODO: Send change_config message to each surface when surface
	// message handling is fully implemented.

	// Apply our conditional state. If we fail to apply the conditional state
	// then we log and attempt to move forward with the old config.
	// We only apply this to the app-level config because the surface
	// config applies its own conditional state.
	// XTODO: Implement conditional config application.
	_ = config

	// Notify the apprt that the app has changed configuration.
	rt_app.perform_action(apprt.Target(apprt.AppTarget{}), .config_change, apprt.ActionValue{}) or {}
}

// add_surface adds an initialized surface to the app's surface list.
// This is really only for the runtime implementations to call and should
// NOT be called by general app users.
pub fn (mut self App) add_surface(surface &SurfaceRef) {
	self.surfaces << surface

	// Since we have non-zero surfaces, we can cancel the quit timer.
	// It is up to the apprt if there is a quit timer at all and if it
	// should be canceled.
	// XTODO: Notify apprt to stop quit timer.
}

// delete_surface removes a surface from the known surface list.
// This will NOT call the destructor or free the memory.
pub fn (mut self App) delete_surface(surface &SurfaceRef) {
	// If this surface is the focused surface then we need to clear it.
	// There was a bug where we relied on has_surface to return false and
	// just let focused surface be but the allocator was reusing addresses
	// after free and giving false positives, so we must clear it.
	if focused := self.focused_surface {
		if voidptr(focused) == voidptr(surface) {
			self.focused_surface = none
		}
	}

	// Remove the surface from the list.
	mut i := 0
	for i < self.surfaces.len {
		if voidptr(self.surfaces[i]) == voidptr(surface) {
			self.surfaces.delete(i)
			continue
		}
		i++
	}

	// If we have no surfaces, we can start the quit timer. It is up to the
	// apprt to determine if this is necessary.
	// XTODO: Notify apprt to start quit timer when surfaces.len == 0.
}

// focused_surface_valid returns the last focused surface if it is still
// a valid (known) surface. Returns none if no valid focused surface exists.
// This is only valid while on the main thread before tick is called.
pub fn (self &App) focused_surface_valid() ?&SurfaceRef {
	surface := self.focused_surface or { return none }
	if !self.has_surface(surface) {
		return none
	}
	return surface
}

// needs_confirm_quit returns true if confirmation is needed to quit
// the app. It is up to the apprt to call this.
pub fn (self &App) needs_confirm_quit() bool {
	for s in self.surfaces {
		if s.needs_confirm_quit() {
			return true
		}
	}
	return false
}

// drain_mailbox processes all pending messages in the mailbox.
fn (mut self App) drain_mailbox(mut rt_app apprt.RuntimeApp) ! {
	for {
		msg := self.mailbox.pop() or { break }
		match msg {
			OpenConfigMsg {
				// XTODO: Perform open_config action via rt_app.
				_ = rt_app
			}
			NewWindowMsg {
				self.new_window(mut rt_app, msg)!
			}
			CloseMsg {
				self.close_surface(msg.surface)
			}
			QuitMsg {
				// If we're quitting, then we stop draining the mailbox
				// immediately. This lets us defer mailbox processing to
				// the next tick so that the apprt can try to quit as
				// quickly as possible.
				rt_app.perform_action(apprt.Target(apprt.AppTarget{}), .quit, apprt.ActionValue{}) or {}
				return
			}
			RedrawSurfaceMsg {
				// XTODO: Perform redraw action via rt_app.
			}
		}
	}
}

// close_surface requests a surface to close, if it is still known.
pub fn (mut self App) close_surface(surface &SurfaceRef) {
	if !self.has_surface(surface) {
		return
	}
	surface.close()
}

// focus_surface sets the given surface as the focused surface,
// if it is a known surface.
pub fn (mut self App) focus_surface(surface &SurfaceRef) {
	if !self.has_surface(surface) {
		return
	}
	self.focused_surface = surface
}

// new_window creates a new terminal window.
// XTODO: Full implementation requires apprt.performAction for new_window.
pub fn (mut self App) new_window(mut rt_app apprt.RuntimeApp, msg NewWindowMsg) ! {
	// XTODO: Validate parent surface, determine target, call rt_app.perform_action.
	_ = msg
	rt_app.perform_action(apprt.Target(apprt.AppTarget{}), .new_window, apprt.ActionValue{}) or {}
}

// focus_event handles an app-level focus event. This should be called
// whenever the focus state of the entire app containing Ghostty changes.
// This is separate from surface focus events. See the `focused` field
// for more information.
pub fn (mut self App) focus_event(focused bool) {
	// Prevent redundant focus events.
	if self.focused == focused {
		return
	}
	self.focused = focused
}

// color_scheme_event is called to notify Ghostty that the color scheme
// for the app has changed. "Color scheme" in this case refers to system
// themes such as "light/dark".
pub fn (mut self App) color_scheme_event(mut rt_app apprt.RuntimeApp, scheme apprt.ColorScheme) ! {
	new_theme := match scheme {
		.light { configpkg.Theme.light }
		.dark { configpkg.Theme.dark }
	}

	// If our scheme didn't change, then we don't do anything.
	if self.config_conditional_state.theme == new_theme {
		return
	}

	// Setup our conditional state which has the current color theme.
	self.config_conditional_state.theme = new_theme

	// Request our configuration be reloaded because the new scheme may
	// impact the colors of the app.
	rt_app.perform_action(apprt.Target(apprt.AppTarget{}), .reload_config, apprt.ActionValue{}) or {}
}

// has_surface returns true if the given surface is in our known surface list.
fn (self &App) has_surface(surface &SurfaceRef) bool {
	for s in self.surfaces {
		if voidptr(s) == voidptr(surface) {
			return true
		}
	}
	return false
}

// The message types that can be sent to the app thread.
pub type Message = OpenConfigMsg | NewWindowMsg | CloseMsg | QuitMsg | RedrawSurfaceMsg

// OpenConfigMsg requests the configuration file to be opened.
pub struct OpenConfigMsg {}

// NewWindowMsg requests creation of a new terminal window.
pub struct NewWindowMsg {
pub:
	// The parent surface, if any. If set, the new window may inherit
	// properties from the parent (like working directory).
	parent ?&SurfaceRef
}

// CloseMsg requests a surface to be closed. This notifies the runtime
// that a surface should close.
pub struct CloseMsg {
pub:
	surface &SurfaceRef
}

// QuitMsg requests the application to quit.
pub struct QuitMsg {}

// RedrawSurfaceMsg requests a surface to be redrawn. This only has an
// effect for runtimes that use single-threaded draws. To redraw a surface
// for all runtimes, wake up the renderer thread. The renderer thread will
// send this message if it needs to.
pub struct RedrawSurfaceMsg {
pub:
	surface ?&SurfaceRef
}

// Mailbox is the way that other threads send the app thread messages.
// It is a bounded queue that can be used to send messages to the app
// from any thread.
pub struct Mailbox {
mut:
	// Internal message queue. This is a simple bounded buffer.
	// XTODO: Replace with a proper BlockingQueue/channel when available.
	queue []Message
}

// push adds a message to the mailbox queue.
pub fn (mut self Mailbox) push(msg Message) {
	self.queue << msg
}

// pop removes and returns the next message from the queue.
// Returns none if the queue is empty.
pub fn (mut self Mailbox) pop() ?Message {
	if self.queue.len == 0 {
		return none
	}
	msg := self.queue[0]
	self.queue.delete(0)
	return msg
}
