module gtk

// winproto_linux.v - The window-protocol abstraction (X11 + Wayland + no-op).
//
// Translated from ghostty/src/apprt/gtk/winproto.zig.
//
// Ghostty models this as a tagged union `union(Protocol)` with `inline else`
// dispatch. V has no comptime `inline for`/`inline else`, so we model the
// union as a struct carrying a `Protocol` tag plus one instance of each
// backend's state; dispatch is a plain `match` on the tag. Only the active
// backend's state is meaningful. This preserves ghostty's semantics: exactly
// one protocol is selected per application at init time.
//
// See:
//   - winproto_noop_linux.v    (NoopApp / NoopWindow)
//   - winproto_x11_linux.v     (X11App / X11Window)
//   - winproto_wayland_linux.v (WaylandApp / WaylandWindow)

import input
import configpkg

// Protocol enumerates the supported windowing protocols. Mirrors
// `winproto.Protocol`.
pub enum Protocol {
	none_
	wayland
	x11
}

// --- ApprtWindow placeholder -----------------------------------------------
//
// TODO(gtk): The GObject `Window` class (class/window.zig) is out of scope for
// this translation. In ghostty the winproto backends receive a
// `*class.window.Window` ("ApprtWindow") and call GObject accessors on it
// (getWindowDecoration, getConfig, isQuickTerminal, and the `as(...)` upcasts
// to gtk.Widget / gtk.Native / gtk.Window). This minimal stub stands in for
// that class so the winproto backends type-check with faithful call sites.
//
// The "Window" terminology here matches ghostty's winproto docs: this is the
// per-window apprt object, distinct from the winproto per-window state
// (X11Window / WaylandWindow / NoopWindow).
//
// `@[heap]` so the winproto per-window states may hold a stable `&ApprtWindow`
// reference (mirroring ghostty's `*ApprtWindow`).
@[heap]
pub struct ApprtWindow {
mut:
	// Cached config wrapper. In ghostty this is a `?*Config` on the widget.
	config &configpkg.Config = unsafe { nil }
	// Whether this window is the quick terminal.
	quick_terminal bool
	// The desired window decoration mode.
	decoration configpkg.WindowDecoration = .auto
}

// as_widget returns this window upcast to a GtkWidget. Mirrors
// `apprt_window.as(gtk.Widget)`.
pub fn (self &ApprtWindow) as_widget() GtkWidget {
	return unsafe { GtkWidget(nil) }
}

// as_window returns this window upcast to a GtkWindow. Mirrors
// `apprt_window.as(gtk.Window)`.
pub fn (self &ApprtWindow) as_window() GtkWindow {
	return unsafe { GtkWindow(nil) }
}

// get_surface returns the GdkSurface for this window, or none. Mirrors
// `apprt_window.as(gtk.Native).getSurface()`.
pub fn (self &ApprtWindow) get_surface() ?GdkSurface {
	return none
}

// get_surface_transform writes the surface transform (in surface coords) into
// x and y. Mirrors `apprt_window.as(gtk.Native).getSurfaceTransform`.
pub fn (self &ApprtWindow) get_surface_transform(x &f64, y &f64) {
	unsafe {
		*x = 0
		*y = 0
	}
}

// get_scale_factor returns the widget scale factor. Mirrors
// `apprt_window.as(gtk.Widget).getScaleFactor()`.
pub fn (self &ApprtWindow) get_scale_factor() int {
	return 1
}

// get_width returns the widget width. Mirrors
// `apprt_window.as(gtk.Widget).getWidth()`.
pub fn (self &ApprtWindow) get_width() int {
	return 0
}

// get_height returns the widget height. Mirrors
// `apprt_window.as(gtk.Widget).getHeight()`.
pub fn (self &ApprtWindow) get_height() int {
	return 0
}

// get_window_decoration returns the desired decoration mode. Mirrors
// `apprt_window.getWindowDecoration()`.
pub fn (self &ApprtWindow) get_window_decoration() configpkg.WindowDecoration {
	return self.decoration
}

// get_config returns the (optional) config wrapper. Mirrors
// `apprt_window.getConfig()`.
pub fn (self &ApprtWindow) get_config() ?&configpkg.Config {
	if self.config == unsafe { nil } {
		return none
	}
	return self.config
}

// is_quick_terminal reports whether this window is the quick terminal. Mirrors
// `apprt_window.isQuickTerminal()`.
pub fn (self &ApprtWindow) is_quick_terminal() bool {
	return self.quick_terminal
}

// --- App: per-application window-protocol state ----------------------------
//
// Mirrors `winproto.App`. Carries the active protocol tag plus one instance of
// each backend's app state.
pub struct WinProtoApp {
pub mut:
	protocol Protocol = .none_
	none_    NoopApp
	wayland  WaylandApp
	x11      X11App
}

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
		return WinProtoApp{
			protocol: .wayland
			wayland: v
		}
	}
	// x11
	if v := X11App.init(gdk_display, app_id, config) {
		return WinProtoApp{
			protocol: .x11
			x11: v
		}
	}

	return WinProtoApp{
		protocol: .none_
	}
}

// deinit mirrors `winproto.App.deinit`.
pub fn (mut self WinProtoApp) deinit() {
	match self.protocol {
		.none_ { self.none_.deinit() }
		.wayland { self.wayland.deinit() }
		.x11 { self.x11.deinit() }
	}
}

// event_mods mirrors `winproto.App.eventMods`. Falls back to the standard GDK
// modifier translation if the backend has no opinion.
pub fn (mut self WinProtoApp) event_mods(device GdkDevice, gtk_mods u32) input.Mods {
	backend := match self.protocol {
		.none_ { self.none_.event_mods(device, gtk_mods) }
		.wayland { self.wayland.event_mods(device, gtk_mods) }
		.x11 { self.x11.event_mods(device, gtk_mods) }
	}
	return backend or { translate_mods(gtk_mods) }
}

// supports_quick_terminal mirrors `winproto.App.supportsQuickTerminal`.
pub fn (self WinProtoApp) supports_quick_terminal() bool {
	return match self.protocol {
		.none_ { self.none_.supports_quick_terminal() }
		.wayland { self.wayland.supports_quick_terminal() }
		.x11 { self.x11.supports_quick_terminal() }
	}
}

// init_quick_terminal mirrors `winproto.App.initQuickTerminal`. Only Wayland
// has an effect (initializing gtk4-layer-shell).
pub fn (mut self WinProtoApp) init_quick_terminal(mut apprt_window ApprtWindow) ! {
	match self.protocol {
		.none_ { self.none_.init_quick_terminal(apprt_window)! }
		.wayland { self.wayland.init_quick_terminal(apprt_window)! }
		.x11 { self.x11.init_quick_terminal(apprt_window)! }
	}
}

// --- Window: per-window window-protocol state ------------------------------
//
// Mirrors `winproto.Window`. Carries the active protocol tag plus one instance
// of each backend's per-window state.
pub struct WinProtoWindow {
pub mut:
	protocol Protocol = .none_
	none_    NoopWindow
	wayland  WaylandWindow
	x11      X11Window
}

// WinProtoWindow.init constructs the per-window state for whichever protocol
// the app selected. Mirrors `winproto.Window.init`.
pub fn WinProtoWindow.init(mut app WinProtoApp, mut apprt_window ApprtWindow) !WinProtoWindow {
	return match app.protocol {
		.none_ {
			WinProtoWindow{
				protocol: .none_
				none_: NoopWindow.init(app.none_, apprt_window)!
			}
		}
		.wayland {
			WinProtoWindow{
				protocol: .wayland
				wayland: WaylandWindow.init(mut app.wayland, mut apprt_window)!
			}
		}
		.x11 {
			WinProtoWindow{
				protocol: .x11
				x11: X11Window.init(mut app.x11, mut apprt_window)!
			}
		}
	}
}

// deinit mirrors `winproto.Window.deinit`.
pub fn (mut self WinProtoWindow) deinit() {
	match self.protocol {
		.none_ { self.none_.deinit() }
		.wayland { self.wayland.deinit() }
		.x11 { self.x11.deinit() }
	}
}

// resize_event mirrors `winproto.Window.resizeEvent`.
pub fn (mut self WinProtoWindow) resize_event() ! {
	match self.protocol {
		.none_ { self.none_.resize_event()! }
		.wayland { self.wayland.resize_event()! }
		.x11 { self.x11.resize_event()! }
	}
}

// sync_appearance mirrors `winproto.Window.syncAppearance`.
pub fn (mut self WinProtoWindow) sync_appearance() ! {
	match self.protocol {
		.none_ { self.none_.sync_appearance()! }
		.wayland { self.wayland.sync_appearance()! }
		.x11 { self.x11.sync_appearance()! }
	}
}

// client_side_decoration_enabled mirrors
// `winproto.Window.clientSideDecorationEnabled`.
pub fn (self WinProtoWindow) client_side_decoration_enabled() bool {
	return match self.protocol {
		.none_ { self.none_.client_side_decoration_enabled() }
		.wayland { self.wayland.client_side_decoration_enabled() }
		.x11 { self.x11.client_side_decoration_enabled() }
	}
}

// add_subprocess_env mirrors `winproto.Window.addSubprocessEnv`.
pub fn (mut self WinProtoWindow) add_subprocess_env(mut env map[string]string) ! {
	match self.protocol {
		.none_ { self.none_.add_subprocess_env(mut env)! }
		.wayland { self.wayland.add_subprocess_env(mut env)! }
		.x11 { self.x11.add_subprocess_env(mut env)! }
	}
}

// set_urgent mirrors `winproto.Window.setUrgent`.
pub fn (mut self WinProtoWindow) set_urgent(urgent bool) ! {
	match self.protocol {
		.none_ { self.none_.set_urgent(urgent)! }
		.wayland { self.wayland.set_urgent(urgent)! }
		.x11 { self.x11.set_urgent(urgent)! }
	}
}
