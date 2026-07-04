module gtk

// app_linux.v - The thin apprt App adapter for the GTK runtime.
//
// Translated from ghostty/src/apprt/gtk/App.zig.
//
// In ghostty this struct is a thin wrapper around the GObject `Application`
// class (class/application.zig). All the heavy lifting lives in that GObject
// class. Since the GObject widget classes are out of scope for this
// translation, `Application` (and `CoreApp`) are declared as minimal
// placeholder stubs below so this adapter type-checks; the apprt-interface
// method signatures are kept faithful to the Zig original.

import apprt

// must_draw_from_app_thread is detected by the Renderer, in which case it
// sends a `redraw_surface` message so we can call `drawFrame` ourselves from
// the app thread, because GTK's `GLArea` does not support drawing from a
// different thread.
pub const must_draw_from_app_thread = true

// application_id is the GTK application ID.
//
// Ghostty selects between a "-debug" and release ID based on the build mode.
// We mirror that using V's `-prod` compile flag.
pub const application_id = $if prod {
	'com.mitchellh.ghostty'
} $else {
	'com.mitchellh.ghostty-debug'
}

// object_path is the GTK object path, likewise selected by build mode.
pub const object_path = $if prod {
	'/com/mitchellh/ghostty'
} $else {
	'/com/mitchellh/ghostty_debug'
}

// TODO(gtk): GObject class `Application` (class/application.zig) — out of
// scope. This minimal placeholder stands in for the GObject Application
// instance so the adapter below type-checks. The real class wraps a
// GtkApplication / AdwApplication and owns the run loop.
pub struct Application {
mut:
	core &CoreApp = unsafe { nil }
}

// TODO(gtk): CoreApp is `witty`'s root `main.App`. The gtk module cannot
// import the `main` module, so this is a minimal placeholder used only to
// keep the adapter signatures faithful.
@[heap]
pub struct CoreApp {}

// App is the main entrypoint to the apprt for the GTK runtime. It is
// initialized in main to start the application.
pub struct App {
pub mut:
	// The GObject Application instance.
	app &Application = unsafe { nil }
}

// init initializes the App. Mirrors `App.init`.
//
// `opts` is required by the apprt interface but unused (an empty struct in
// Zig). We omit it here since V has no anonymous empty-struct parameter idiom.
pub fn (mut self App) init(core_app &CoreApp) ! {
	app := Application.new(self, core_app)!
	self.app = app
}

// run starts the application main loop. Mirrors `App.run`.
pub fn (mut self App) run() ! {
	self.app.run()!
}

// terminate forcibly deinitializes the app. Mirrors `App.terminate`.
//
// We do not unref because other things tend to have a reference at this
// point, so this just forces disposal now.
pub fn (mut self App) terminate() {
	self.app.deinit()
}

// wakeup is called by CoreApp to wake up the event loop. Mirrors `App.wakeup`.
pub fn (mut self App) wakeup() {
	self.app.wakeup()
}

// perform_action performs an apprt action. Mirrors `App.performAction`.
pub fn (mut self App) perform_action(target apprt.Target, action apprt.ActionKey) !bool {
	return self.app.perform_action(target, action)
}

// perform_ipc sends the given IPC to a running Ghostty. Returns true if the
// action was performed, false otherwise. Mirrors `App.performIpc`.
//
// This is a static function. Since this is called from a CLI app (or some
// other process that is not Ghostty) there is no full-featured apprt App to
// use.
pub fn App.perform_ipc(target apprt.IpcTarget, action apprt.IpcAction) !bool {
	// TODO(gtk): translate ipc/new_window.zig (ipcNewWindow).
	return ipc_new_window(target, action)
}

// redraw_inspector redraws the inspector for the given surface. Mirrors
// `App.redrawInspector`.
pub fn (self &App) redraw_inspector(mut surface Surface) {
	surface.redraw_inspector()
}

// --- Application placeholder methods ---------------------------------------
// TODO(gtk): all of these belong to the GObject `Application` class
// (class/application.zig) which is out of scope. They are stubbed so the
// adapter type-checks with faithful signatures.

// new creates a new GObject Application. Mirrors `Application.new`.
pub fn Application.new(rt_app &App, core_app &CoreApp) !&Application {
	_ = rt_app
	return &Application{
		core: core_app
	}
}

// run runs the GTK application loop.
pub fn (mut self Application) run() ! {}

// deinit forces disposal of the application.
pub fn (mut self Application) deinit() {}

// wakeup wakes up the GTK event loop.
pub fn (mut self Application) wakeup() {}

// unref decrements the reference count of the Application GObject.
pub fn (mut self Application) unref() {}

// perform_action dispatches an apprt action against the application.
pub fn (mut self Application) perform_action(target apprt.Target, action apprt.ActionKey) !bool {
	_ = target
	_ = action
	return false
}

// ipc_new_window is a placeholder for ipc/new_window.zig's newWindow.
fn ipc_new_window(target apprt.IpcTarget, action apprt.IpcAction) !bool {
	_ = target
	_ = action
	return false
}
