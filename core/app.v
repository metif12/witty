module core

// --- Original Ghostty Comments Start: src/App.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/App.zig
//
// App is the primary GUI application for ghostty. This builds the window,
// sets up the renderer, etc. The primary run loop is started by calling
// the "run" function.
// General purpose allocator
// The list of surfaces that are currently active.
// This is true if the app that Ghostty is in is focused. This may
// mean that no surfaces (terminals) are focused but the app is still
// focused, i.e. may an about window. On macOS, this concept is known
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
// The last focused surface. This surface may not be valid;
// you must always call hasSurface to validate it.
// The mailbox that can be used to send this thread messages. Note
// this is a blocking queue so if it is full you will get errors (or block).
// The set of font GroupCache instances shared by surfaces with the
// same font configuration.
// Used to rate limit desktop notifications. Some platforms (notably macOS) will
// run out of resources if desktop notifications are sent too fast and the OS
// will kill Ghostty.
// The conditional state of the configuration. See the equivalent field
// in the Surface struct for more information. In this case, this applies
// to the app-level config and as a default for new surfaces.
// Set to false once we've created at least one surface. This
// never goes true again. This can be used by surfaces to determine
// if they are the first surface.
// Create a new app instance. This returns a stable pointer to the app
// instance which is required for callbacks.
// Initialize the main app instance. This creates the main window, sets
// up the renderer state, compiles the shaders, etc. This is the primary
// "startup" logic.
//
// After calling this function, well behaved apprts should then call
// `focusEvent` to set the initial focus state of the app.
// Clean up all our surfaces
// Clean up our font group cache
// We should have zero items in the grid set at this point because
// destroy only gets called when the app is shutting down and this
// should gracefully close all surfaces.
// Deinitialize the app
// Free the app memory
// Tick ticks the app loop. This will drain our mailbox and process those
// events. This should be called by the application runtime on every loop
// tick.
// Drain our mailbox
// Update the configuration associated with the app. This can only be
// called from the main thread. The caller owns the config memory. The
// memory can be freed immediately when this returns.
// Go through and update all of the surface configurations.
// Apply our conditional state. If we fail to apply the conditional state
// then we log and attempt to move forward with the old config.
// We only apply this to the app-level config because the surface
// config applies its own conditional state.
// Notify the apprt that the app has changed configuration.
// Add an initialized surface. This is really only for the runtime
// implementations to call and should NOT be called by general app users.
// The surface must be from the pool.
// Since we have non-zero surfaces, we can cancel the quit timer.
// It is up to the apprt if there is a quit timer at all and if it
// should be canceled.
// Delete the surface from the known surface list. This will NOT call the
// destructor or free the memory.
// If this surface is the focused surface then we need to clear it.
// There was a bug where we relied on hasSurface to return false and
// just let focused surface be but the allocator was reusing addresses
// after free and giving false positives, so we must clear it.
// If we have no surfaces, we can start the quit timer. It is up to the
// apprt to determine if this is necessary.
// The last focused surface. This is only valid while on the main thread
// before tick is called.
// Returns true if confirmation is needed to quit the app. It is up to
// the apprt to call this.
// Drain the mailbox.
// these tend to be way too verbose for normal debugging
// If we're quitting, then we set the quit flag and stop
// draining the mailbox immediately. This lets us defer
// mailbox processing to the next tick so that the apprt
// can try to quit as quickly as possible.
// Create a new window
// Handle an app-level focus event. This should be called whenever
// the focus state of the entire app containing Ghostty changes.
// This is separate from surface focus events. See the `focused`
// field for more information.
// Prevent redundant focus events
// Returns true if the given key event would trigger a keybinding
// if it were to be processed. This is useful for determining if
// a key event should be sent to the terminal or not.
// If we have a keybinding for this event then we return true.
// Handle a key event at the app-scope. If this key event is used,
// this will return true and the caller shouldn't continue processing
// the event. If the event is not used, this will return false.
//
// If the app currently has focus then all key events are processed.
// If the app does not have focus then only global key events are
// processed.
// We don't care about key release events.
// Continue processing key press events.
// Get the keybind entry for this event. We don't support key sequences
// so we can look directly in the top-level set.
// Sequences aren't supported. Our configuration parser verifies
// this for global keybinds but we may still get an entry for
// a non-global keybind.
// Leaf entries are good
// If we aren't focused, then we only process global keybinds.
// Global keybinds are done using performAll so that they
// can target all surfaces too.
// Must be focused to process non-global keybinds
// If we are focused, then we process keybinds only if they are
// app-scoped. Otherwise, we do nothing. Surface-scoped should
// be processed by Surface.keyEvent. For chained actions, all
// actions must be app-scoped.
// Call to notify Ghostty that the color scheme for the app has changed.
// "Color scheme" in this case refers to system themes such as "light/dark".
// If our scheme didn't change, then we don't do anything.
// Setup our conditional state which has the current color theme.
// Request our configuration be reloaded because the new scheme may
// impact the colors of the app.
// Perform a binding action. This only accepts actions that are scoped
// to the app. Callers can use performAllAction to perform any action
// and any non-app-scoped actions will be performed on all surfaces.
// Performs a chained action. We will continue executing each action
// even if there is a failure in a prior action.
// Perform an app-wide binding action. If the action is surface-specific
// then it will be performed on all surfaces. To perform only app-scoped
// actions, use performAction.
// App-scoped actions are handled by the app so that they aren't
// repeated for each surface (since each surface forwards
// app-scoped actions back up).
// Surface-scoped actions are performed on all surfaces. Errors
// are logged but processing continues.
// Handle a window message
// We want to ensure our window is still active. Window messages
// are quite rare and we normally don't have many windows so we do
// a simple linear search here.
// Window was not found, it probably quit before we handled the message.
// Not a problem.
// The message types that can be sent to the app thread.
// Open the configuration file
// Create a new terminal window.
// Close a surface. This notifies the runtime that a surface
// should close.
// Quit
// A message for a specific surface.
// Redraw a surface. This only has an effect for runtimes that
// use single-threaded draws. To redraw a surface for all runtimes,
// wake up the renderer thread. The renderer thread will send this
// message if it needs to.
// The parent surface
// Mailbox is the way that other threads send the app thread messages.
// The type used for sending messages to the app thread.
// Send a message to the surface.
// Wake up our app loop
// Wasm API.
// export fn app_new(config: *Config) ?*App {
//     return app_new_(config) catch |err| { log.err("error initializing app err={}", .{err});
//         return null;
//     };
// }
//
// fn app_new_(config: *Config) !*App {
//     const app = try App.create(alloc, config);
//     errdefer app.destroy();
//
//     const result = try alloc.create(App);
//     result.* = app;
//     return result;
// }
//
// export fn app_free(ptr: ?*App) void {
//     if (ptr) |v| {
//         v.destroy();
//         alloc.destroy(v);
//     }
// }
//
// --- Original Ghostty Comments End: src/App.zig


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
import input
import time

// SurfaceList is a list of active surfaces managed by the app.
// TODO: When full apprt.Surface type is available, change to []&apprt.Surface.
type SurfaceList = []&SurfaceRef

// SurfaceRef is a reference to a surface. This is a placeholder type
// until the full Surface infrastructure is connected.
// TODO: Replace with the actual Surface type from the surface module.
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
// TODO: Implement when process tracking is available.
pub fn (s &SurfaceRef) needs_confirm_quit() bool {
	return false
}

// close requests the surface to close.
// TODO: Implement when full surface lifecycle is available.
pub fn (s &SurfaceRef) close() {
}

// handle_message handles a message sent to this surface.
// TODO: Implement when surface message handling is available.
pub fn (s &SurfaceRef) handle_message(msg SurfaceMessage) ! {
	_ = msg
}

// perform_binding_action performs a surface-scoped binding action on this
// surface. Returns true if the action was performed.
// TODO: Route to the real Surface.perform_binding_action once SurfaceRef is
// backed by the full Surface type.
pub fn (s &SurfaceRef) perform_binding_action(action input.Action) !bool {
	_ = action
	return false
}

// ChangeConfigMsg is a placeholder for config-change messages sent to a surface.
pub struct ChangeConfigMsg {
pub:
	// TODO: Should hold a reference to the new config.
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
	// TODO: Call deinit on each surface when surface lifecycle is implemented.
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
pub fn (mut self App) update_config(mut rt_app apprt.RuntimeApp, config &configpkg.Config) ! {
	// Go through and update all of the surface configurations. Each surface
	// derives its own config from the change_config message, applying its
	// own conditional state.
	for surface in self.surfaces {
		surface.core().handle_message(SurfaceMessage{ kind: .change_config })!
	}

	// Apply our conditional state. If we fail to apply the conditional state
	// then we log and attempt to move forward with the old config. We only
	// apply this to the app-level config because the surface config applies
	// its own conditional state.
	//
	// The full implementation calls config.change_conditional_state(...) and
	// passes the derived config to the apprt below. The config stub here does
	// not yet expose that method, so we forward the caller's config as-is.
	_ = config

	// Notify the apprt that the app has changed configuration. The config
	// pointer is only valid for the duration of the action.
	cfg_change := unsafe {
		apprt.ConfigChange{
			config: config
		}
	}
	rt_app.perform_action(apprt.Target(apprt.AppTarget{}), .config_change, apprt.ActionValue{
		config_change_: cfg_change
	}) or {}
}

// add_surface adds an initialized surface to the app's surface list.
// This is really only for the runtime implementations to call and should
// NOT be called by general app users.
pub fn (mut self App) add_surface(surface &SurfaceRef) {
	self.surfaces << surface

	// Since we have non-zero surfaces, we can cancel the quit timer.
	// It is up to the apprt if there is a quit timer at all and if it
	// should be canceled.
	// TODO: Notify apprt to stop quit timer.
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
	// TODO: Notify apprt to start quit timer when surfaces.len == 0.
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
				// TODO: Perform open_config action via rt_app.
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
				// TODO: Perform redraw action via rt_app.
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
// TODO: Full implementation requires apprt.performAction for new_window.
pub fn (mut self App) new_window(mut rt_app apprt.RuntimeApp, msg NewWindowMsg) ! {
	// TODO: Validate parent surface, determine target, call rt_app.perform_action.
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

// BindingLeaf is a resolved keybinding leaf (a single or chained action) along
// with its flags. It mirrors ghostty's `input.Binding.Set.GenericLeaf`.
struct BindingLeaf {
	actions []input.Action
	flags   input.Flags
}

// lookup_binding looks up the keybinding entry for the given event in the
// app-level binding set. Returns none if there is no binding, or if the entry
// is a leader (key sequences aren't supported for app-scoped bindings).
//
// The full implementation reads `rt_app.config.keybind.set.get_event(event)`.
// The apprt.RuntimeApp stub doesn't yet carry a config, so this returns none.
// The dispatch logic below is written against the real return shape so that
// wiring up the config is the only remaining step.
fn (self &App) lookup_binding(mut rt_app apprt.RuntimeApp, event input.KeyEvent) ?BindingLeaf {
	_ = rt_app
	_ = event
	return none
}

// key_event_is_binding returns true if the given key event would trigger a
// keybinding if it were to be processed.
pub fn (mut self App) key_event_is_binding(mut rt_app apprt.RuntimeApp, event input.KeyEvent) bool {
	match event.action {
		.release {
			return false
		}
		.press, .repeat {}
	}

	// If we have a keybinding for this event then we return true.
	return self.lookup_binding(mut rt_app, event) != none
}

// key_event handles a key event at the app-scope. If this key event is used,
// this returns true and the caller shouldn't continue processing the event.
//
// If the app currently has focus then all key events are processed. If the
// app does not have focus then only global key events are processed.
pub fn (mut self App) key_event(mut rt_app apprt.RuntimeApp, event input.KeyEvent) bool {
	match event.action {
		// We don't care about key release events.
		.release {
			return false
		}
		// Continue processing key press events.
		.press, .repeat {}
	}

	// Get the keybind entry for this event. We don't support key sequences so
	// we look directly in the top-level set.
	leaf := self.lookup_binding(mut rt_app, event) or { return false }
	actions := leaf.actions
	if actions.len == 0 {
		return false
	}

	// If we aren't focused, then we only process global keybinds.
	if !self.focused && !leaf.flags.global {
		return false
	}

	// Global keybinds are done using performAll so they can target all
	// surfaces too.
	if leaf.flags.global {
		self.perform_all_chained_action(mut rt_app, actions)
		return true
	}

	// Must be focused to process non-global keybinds. If we are focused, then
	// we process keybinds only if they are app-scoped. Otherwise we do
	// nothing (surface-scoped is handled by Surface.key_event). For chained
	// actions, all actions must be app-scoped.
	for action in actions {
		if action.scope() != .app {
			return false
		}
	}
	for action in actions {
		self.perform_action(mut rt_app, action) or {
			// Log and continue; a failed app keybind action shouldn't stop
			// processing the remainder of the chain.
		}
	}

	return true
}

// perform_action performs an app-scoped binding action. This only accepts
// actions that are scoped to the app. Callers can use perform_all_action to
// perform any action and have non-app-scoped actions performed on all
// surfaces.
pub fn (mut self App) perform_action(mut rt_app apprt.RuntimeApp, action input.Action) ! {
	app_target := apprt.Target(apprt.AppTarget{})
	match action.tag {
		.unbind {
			// unreachable in ghostty; unbind is handled before reaching here.
		}
		.ignore {}
		.quit {
			rt_app.perform_action(app_target, .quit, apprt.ActionValue{})!
		}
		.new_window {
			self.new_window(mut rt_app, NewWindowMsg{ parent: none })!
		}
		.open_config {
			rt_app.perform_action(app_target, .open_config, apprt.ActionValue{})!
		}
		.reload_config {
			rt_app.perform_action(app_target, .reload_config, apprt.ActionValue{})!
		}
		.close_all_windows {
			rt_app.perform_action(app_target, .close_all_windows, apprt.ActionValue{})!
		}
		.toggle_quick_terminal {
			rt_app.perform_action(app_target, .toggle_quick_terminal, apprt.ActionValue{})!
		}
		.toggle_visibility {
			rt_app.perform_action(app_target, .toggle_visibility, apprt.ActionValue{})!
		}
		.check_for_updates {
			rt_app.perform_action(app_target, .check_for_updates, apprt.ActionValue{})!
		}
		.show_gtk_inspector {
			rt_app.perform_action(app_target, .show_gtk_inspector, apprt.ActionValue{})!
		}
		.undo {
			rt_app.perform_action(app_target, .undo, apprt.ActionValue{})!
		}
		.redo {
			rt_app.perform_action(app_target, .redo, apprt.ActionValue{})!
		}
		else {
			// Non-app-scoped action passed to perform_action. In ghostty this
			// is a compile error (the type only permits app-scoped actions);
			// here we ignore it defensively.
		}
	}
}

// perform_all_chained_action performs a chained action. We continue executing
// each action even if a prior action fails.
pub fn (mut self App) perform_all_chained_action(mut rt_app apprt.RuntimeApp, actions []input.Action) {
	for action in actions {
		self.perform_all_action(mut rt_app, action) or {
			// Log and continue to the next chained action.
		}
	}
}

// perform_all_action performs an app-wide binding action. If the action is
// surface-specific then it is performed on all surfaces. To perform only
// app-scoped actions, use perform_action.
pub fn (mut self App) perform_all_action(mut rt_app apprt.RuntimeApp, action input.Action) ! {
	match action.scope() {
		// App-scoped actions are handled by the app so that they aren't
		// repeated for each surface (each surface forwards app-scoped actions
		// back up).
		.app {
			self.perform_action(mut rt_app, action)!
		}
		// Surface-scoped actions are performed on all surfaces. Errors are
		// logged but processing continues.
		.surface {
			for surface in self.surfaces {
				surface.core().perform_binding_action(action) or {
					// Log and continue with the next surface.
				}
			}
		}
	}
}

// surface_message handles a message routed to a specific surface. We first
// ensure the surface is still active (a simple linear search) since messages
// are rare and windows are few.
fn (mut self App) surface_message(surface &SurfaceRef, msg SurfaceMessage) ! {
	if self.has_surface(surface) {
		surface.handle_message(msg)!
	}
	// If the surface was not found it probably quit before we handled the
	// message. That is not a problem.
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
	// TODO: Replace with a proper BlockingQueue/channel when available.
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
