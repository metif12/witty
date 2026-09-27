module gtk

// winproto_linux.v - The window-protocol abstraction (X11 + Wayland + no-op).
//
// Translated from ghostty/src/apprt/gtk/winproto.zig.
//
// Ghostty models this as a tagged union `union(Protocol)` with `inline else`
// dispatch. V sum types retain the selected backend directly; explicit
// matches replace Zig's comptime field iteration and inline dispatch.
//
// See:
//   - winproto_noop_linux.v    (NoopApp / NoopWindow)
//   - winproto_x11_linux.v     (X11App / X11Window)
//   - winproto_wayland_linux.v (WaylandApp / WaylandWindow)

import input
import configpkg

// Protocol enumerates the supported windowing protocols. Mirrors
// `winproto.Protocol`.
pub enum Protocol as u8 {
	none_
	wayland
	x11
}

// --- ApprtWindow -----------------------------------------------------------
//
// Ghostty passes the concrete `*class.window.Window` into the protocol
// backends. Witty keeps the native GObject and its translated state in a
// stable heap-allocated `Window` wrapper, so this bridge holds that same
// object by reference and forwards every accessor to it. The separate bridge
// type avoids a recursive value layout (`Window` owns `WinProtoWindow`) while
// preserving the source's direct, live view of window state.
@[heap]
pub struct ApprtWindow {
mut:
	owner &Window = unsafe { nil }
}

// as_widget returns this window upcast to a GtkWidget. Mirrors
// `apprt_window.as(gtk.Widget)`.
pub fn (self &ApprtWindow) as_widget() GtkWidget {
	if isnil(self.owner) {
		return unsafe { GtkWidget(nil) }
	}
	return self.owner.as_widget()
}

// as_window returns this window upcast to a GtkWindow. Mirrors
// `apprt_window.as(gtk.Window)`.
pub fn (self &ApprtWindow) as_window() GtkWindow {
	if isnil(self.owner) {
		return unsafe { GtkWindow(nil) }
	}
	return self.owner.as_window()
}

// get_surface returns the GdkSurface for this window, or none. Mirrors
// `apprt_window.as(gtk.Native).getSurface()`.
pub fn (self &ApprtWindow) get_surface() ?GdkSurface {
	if isnil(self.owner) {
		return none
	}
	surface := C.gtk_native_get_surface(self.owner.as_native())
	if isnil(surface) {
		return none
	}
	return surface
}

// get_surface_transform writes the surface transform (in surface coords) into
// x and y. Mirrors `apprt_window.as(gtk.Native).getSurfaceTransform`.
pub fn (self &ApprtWindow) get_surface_transform(x &f64, y &f64) {
	if isnil(self.owner) {
		unsafe {
			*x = 0
			*y = 0
		}
		return
	}
	C.gtk_native_get_surface_transform(self.owner.as_native(), x, y)
}

// get_scale_factor returns the widget scale factor. Mirrors
// `apprt_window.as(gtk.Widget).getScaleFactor()`.
pub fn (self &ApprtWindow) get_scale_factor() int {
	if isnil(self.owner) {
		return 1
	}
	return C.gtk_widget_get_scale_factor(self.owner.as_widget())
}

// get_width returns the widget width. Mirrors
// `apprt_window.as(gtk.Widget).getWidth()`.
pub fn (self &ApprtWindow) get_width() int {
	if isnil(self.owner) {
		return 0
	}
	return C.gtk_widget_get_width(self.owner.as_widget())
}

// get_height returns the widget height. Mirrors
// `apprt_window.as(gtk.Widget).getHeight()`.
pub fn (self &ApprtWindow) get_height() int {
	if isnil(self.owner) {
		return 0
	}
	return C.gtk_widget_get_height(self.owner.as_widget())
}

// get_window_decoration returns the desired decoration mode. Mirrors
// `apprt_window.getWindowDecoration()`.
pub fn (self &ApprtWindow) get_window_decoration() configpkg.WindowDecoration {
	if isnil(self.owner) {
		return .auto
	}
	return self.owner.get_window_decoration()
}

// get_config returns the (optional) config wrapper. Mirrors
// `apprt_window.getConfig()`.
pub fn (self &ApprtWindow) get_config() ?&Config {
	if isnil(self.owner) {
		return none
	}
	return self.owner.get_config()
}

// is_quick_terminal reports whether this window is the quick terminal. Mirrors
// `apprt_window.isQuickTerminal()`.
pub fn (self &ApprtWindow) is_quick_terminal() bool {
	if isnil(self.owner) {
		return false
	}
	return self.owner.is_quick_terminal()
}

// --- App: per-application window-protocol state ----------------------------
//
// Mirrors `winproto.App`. Only the selected backend's app state is retained.
pub type WinProtoApp = NoopApp | WaylandApp | X11App

// WinProtoApp.init tries each protocol backend in turn (Wayland, then X11)
// and selects the first one whose `init` accepts the current display,
// falling back to the no-op backend. Mirrors `winproto.App.init`.
//
// Ghostty iterates the union fields via `inline for`; V requires an explicit
// ordered probe. Order matches ghostty's union field order.
pub fn WinProtoApp.init(gdk_display GdkDisplay, app_id string, config &configpkg.Config) !WinProtoApp {
	// none: noop.App (declines every display; never selected here)
	// wayland
	if v := WaylandApp.init(gdk_display, app_id, config) {
		return v
	}
	// x11
	if v := X11App.init(gdk_display, app_id, config) {
		return v
	}

	return NoopApp{}
}

// deinit mirrors `winproto.App.deinit`.
pub fn (mut self WinProtoApp) deinit() {
	match mut self {
		NoopApp { self.deinit() }
		WaylandApp { self.deinit() }
		X11App { self.deinit() }
	}
}

// event_mods mirrors `winproto.App.eventMods`. Falls back to the standard GDK
// modifier translation if the backend has no opinion.
pub fn (mut self WinProtoApp) event_mods(device GdkDevice, gtk_mods u32) input.Mods {
	backend := match mut self {
		NoopApp { self.event_mods(device, gtk_mods) }
		WaylandApp { self.event_mods(device, gtk_mods) }
		X11App { self.event_mods(device, gtk_mods) }
	}
	return backend or { translate_mods(gtk_mods) }
}

// supports_quick_terminal mirrors `winproto.App.supportsQuickTerminal`.
pub fn (self WinProtoApp) supports_quick_terminal() bool {
	return match self {
		NoopApp { self.supports_quick_terminal() }
		WaylandApp { self.supports_quick_terminal() }
		X11App { self.supports_quick_terminal() }
	}
}

// init_quick_terminal mirrors `winproto.App.initQuickTerminal`. Only Wayland
// has an effect (initializing gtk4-layer-shell).
pub fn (mut self WinProtoApp) init_quick_terminal(mut apprt_window ApprtWindow) ! {
	match mut self {
		NoopApp { self.init_quick_terminal(apprt_window)! }
		WaylandApp { self.init_quick_terminal(apprt_window)! }
		X11App { self.init_quick_terminal(apprt_window)! }
	}
}

// --- Window: per-window window-protocol state ------------------------------
//
// Mirrors `winproto.Window`. Only the selected backend's per-window state is
// retained.
pub type WinProtoWindow = NoopWindow | WaylandWindow | X11Window

// WinProtoWindow.init constructs the per-window state for whichever protocol
// the app selected. Mirrors `winproto.Window.init`.
pub fn WinProtoWindow.init(mut app WinProtoApp, mut apprt_window ApprtWindow) !WinProtoWindow {
	return match mut app {
		NoopApp { NoopWindow.init(app, apprt_window)! }
		WaylandApp { WaylandWindow.init(mut app, mut apprt_window)! }
		X11App { X11Window.init(mut app, mut apprt_window)! }
	}
}

// deinit mirrors `winproto.Window.deinit`.
pub fn (mut self WinProtoWindow) deinit() {
	match mut self {
		NoopWindow { self.deinit() }
		WaylandWindow { self.deinit() }
		X11Window { self.deinit() }
	}
}

// resize_event mirrors `winproto.Window.resizeEvent`.
pub fn (mut self WinProtoWindow) resize_event() ! {
	match mut self {
		NoopWindow { self.resize_event()! }
		WaylandWindow { self.resize_event()! }
		X11Window { self.resize_event()! }
	}
}

// sync_appearance mirrors `winproto.Window.syncAppearance`.
pub fn (mut self WinProtoWindow) sync_appearance() ! {
	match mut self {
		NoopWindow { self.sync_appearance()! }
		WaylandWindow { self.sync_appearance()! }
		X11Window { self.sync_appearance()! }
	}
}

// client_side_decoration_enabled mirrors
// `winproto.Window.clientSideDecorationEnabled`.
pub fn (self WinProtoWindow) client_side_decoration_enabled() bool {
	return match self {
		NoopWindow { self.client_side_decoration_enabled() }
		WaylandWindow { self.client_side_decoration_enabled() }
		X11Window { self.client_side_decoration_enabled() }
	}
}

// add_subprocess_env mirrors `winproto.Window.addSubprocessEnv`.
pub fn (mut self WinProtoWindow) add_subprocess_env(mut env map[string]string) ! {
	match mut self {
		NoopWindow { self.add_subprocess_env(mut env)! }
		WaylandWindow { self.add_subprocess_env(mut env)! }
		X11Window { self.add_subprocess_env(mut env)! }
	}
}

// set_urgent mirrors `winproto.Window.setUrgent`.
pub fn (mut self WinProtoWindow) set_urgent(urgent bool) ! {
	match mut self {
		NoopWindow { self.set_urgent(urgent)! }
		WaylandWindow { self.set_urgent(urgent)! }
		X11Window { self.set_urgent(urgent)! }
	}
}
