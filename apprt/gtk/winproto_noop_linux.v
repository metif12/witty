module gtk

// winproto_noop_linux.v - The no-op window-protocol backend.
//
// Translated from ghostty/src/apprt/gtk/winproto/noop.zig.
//
// This backend does nothing. It is used when neither X11 nor Wayland is
// available (or when their respective `init` functions decline the current
// display). It is also the fallback that both the X11 and Wayland backends
// compile to when their build option is disabled in ghostty; in witty we
// always compile all three and select at runtime via the `WinProto` union in
// winproto_linux.v.
import input
import configpkg

// NoopApp is the application-wide state for the no-op backend. It carries no
// state. Mirrors `noop.App`.
pub struct NoopApp {}

// NoopApp.init mirrors `noop.App.init`. It always returns `none`, signalling
// that this backend does not apply to the given display. Because it never
// matches a real display, it is only ever constructed directly as the
// fallback (see winproto_linux.v).
//
// Ghostty's signature is `!?App` (error union of optional). V has no
// Result-of-Option type, so throughout the winproto backends `init` returns a
// plain `?T`: `none` means "this backend does not apply (or failed to
// initialize)". Hard initialization failures are logged and mapped to `none`.
pub fn NoopApp.init(gdk_display GdkDisplay, app_id string, config &configpkg.Config) ?NoopApp {
	_ = gdk_display
	_ = app_id
	_ = config
	return none
}

// deinit mirrors `noop.App.deinit`.
pub fn (mut self NoopApp) deinit() {}

// event_mods mirrors `noop.App.eventMods`. Returns `none`, so the caller falls
// back to the standard GDK modifier translation.
pub fn (mut self NoopApp) event_mods(device GdkDevice, gtk_mods u32) ?input.Mods {
	_ = device
	_ = gtk_mods
	return none
}

// supports_quick_terminal mirrors `noop.App.supportsQuickTerminal`.
pub fn (self NoopApp) supports_quick_terminal() bool {
	return false
}

// init_quick_terminal mirrors `noop.App.initQuickTerminal`.
pub fn (mut self NoopApp) init_quick_terminal(apprt_window &ApprtWindow) ! {
	_ = apprt_window
}

// NoopWindow is the per-window state for the no-op backend. It carries no
// state. Mirrors `noop.Window`.
pub struct NoopWindow {}

// noop_window_init mirrors `noop.Window.init`.
pub fn NoopWindow.init(app &NoopApp, apprt_window &ApprtWindow) !NoopWindow {
	_ = app
	_ = apprt_window
	return NoopWindow{}
}

// deinit mirrors `noop.Window.deinit`.
pub fn (self NoopWindow) deinit() {}

// update_config_event mirrors the orphan `noop.Window.updateConfigEvent`
// declaration in the pinned source. That declaration refers to
// `ApprtWindow.DerivedConfig`, a type that is not declared anywhere in the
// pinned GTK window implementation, and the WinProtoWindow union never
// dispatches this method. Keep its unused argument opaque so the source entry
// point remains callable without inventing a configuration representation.
pub fn (mut self NoopWindow) update_config_event(derived_config voidptr) ! {
	_ = derived_config
}

// resize_event mirrors `noop.Window.resizeEvent`.
pub fn (mut self NoopWindow) resize_event() ! {}

// sync_appearance mirrors `noop.Window.syncAppearance`.
pub fn (mut self NoopWindow) sync_appearance() ! {}

// client_side_decoration_enabled mirrors
// `noop.Window.clientSideDecorationEnabled`. Returns true; this should be the
// actual present state of the window, not the desired state.
pub fn (self NoopWindow) client_side_decoration_enabled() bool {
	return true
}

// add_subprocess_env mirrors `noop.Window.addSubprocessEnv`.
pub fn (mut self NoopWindow) add_subprocess_env(mut env map[string]string) ! {
	_ = env
}

// set_urgent mirrors `noop.Window.setUrgent`.
pub fn (mut self NoopWindow) set_urgent(urgent bool) ! {
	_ = urgent
}
