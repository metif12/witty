module gtk

// surface_linux.v - The thin apprt Surface adapter for the GTK runtime.
//
// Translated from ghostty/src/apprt/gtk/Surface.zig.
//
// Like the App adapter, in ghostty this is a thin wrapper around the GObject
// `Surface` class (class/surface.zig). That GObject class is out of scope for
// this translation, so `GtkSurface` (the GObject) is declared as a minimal
// placeholder stub below to keep this adapter type-checking. The real core
// surface is `core.Surface` (see core/surface.v); the SurfaceWidget input
// handlers dispatch directly to its callbacks.

import apprt
import core

// TODO(gtk): GObject class `Surface` (class/surface.zig) — out of scope. This
// minimal placeholder stands in for the GObject Surface instance. The real
// class is a GTK widget wrapping the terminal renderer, input handling, etc.
pub struct GtkSurface {}

// Surface is the apprt Surface adapter for the GTK runtime.
pub struct Surface {
pub mut:
	// The GObject Surface.
	surface &GtkSurface = unsafe { nil }
}

// deinit tears down the surface adapter. Mirrors `Surface.deinit`.
pub fn (mut self Surface) deinit() {}

// gobj returns the GObject surface for this apprt surface. This is a function
// so we can add extra logic if we ever have to. Mirrors `Surface.gobj`.
pub fn (mut self Surface) gobj() &GtkSurface {
	return self.surface
}

// core returns the core.Surface for this apprt surface. Mirrors `Surface.core`.
//
// In Zig this asserts non-optional because libghostty should only call this
// for initialized surfaces.
pub fn (mut self Surface) core() &core.Surface {
	return self.surface.core()
}

// rt_app returns the apprt App for this surface. Mirrors `Surface.rtApp`.
pub fn (self &Surface) rt_app() &App {
	return application_default().rt()
}

// close closes the surface. Mirrors `Surface.close`.
pub fn (mut self Surface) close(process_active bool) {
	_ = process_active
	self.surface.close()
}

// cgroup returns the cgroup path for this surface, if any. Mirrors
// `Surface.cgroup`.
pub fn (mut self Surface) cgroup() ?string {
	return self.surface.cgroup_path()
}

// get_title returns the surface title, if any. Mirrors `Surface.getTitle`.
pub fn (mut self Surface) get_title() ?string {
	return self.surface.get_title()
}

// get_content_scale returns the content scale. Mirrors `Surface.getContentScale`.
pub fn (self &Surface) get_content_scale() !apprt.ContentScale {
	return self.surface.get_content_scale()
}

// get_size returns the surface size in pixels. Mirrors `Surface.getSize`.
pub fn (self &Surface) get_size() !apprt.SurfaceSize {
	return self.surface.get_size()
}

// get_cursor_pos returns the cursor position in pixels. Mirrors
// `Surface.getCursorPos`.
pub fn (self &Surface) get_cursor_pos() !apprt.CursorPos {
	return self.surface.get_cursor_pos()
}

// supports_clipboard reports whether the given clipboard type is supported.
// Mirrors `Surface.supportsClipboard`. On GTK all clipboard types are
// supported.
pub fn (self &Surface) supports_clipboard(clipboard_type apprt.Clipboard) bool {
	return match clipboard_type {
		.standard, .selection, .primary { true }
	}
}

// clipboard_request requests clipboard contents. Mirrors
// `Surface.clipboardRequest`.
pub fn (mut self Surface) clipboard_request(clipboard_type apprt.Clipboard, state apprt.ClipboardRequest) !bool {
	return self.surface.clipboard_request(clipboard_type, state)
}

// set_clipboard sets the clipboard contents. Mirrors `Surface.setClipboard`.
pub fn (mut self Surface) set_clipboard(clipboard_type apprt.Clipboard, contents []apprt.ClipboardContent, confirm bool) ! {
	self.surface.set_clipboard(clipboard_type, contents, confirm)
}

// default_termio_env returns the default termio environment map. Mirrors
// `Surface.defaultTermioEnv`.
pub fn (mut self Surface) default_termio_env() !map[string]string {
	return self.surface.default_termio_env()
}

// redraw_inspector redraws the inspector for our surface. Mirrors
// `Surface.redrawInspector`.
pub fn (mut self Surface) redraw_inspector() {
	self.surface.redraw_inspector()
}

// --- GtkSurface placeholder methods ----------------------------------------
// TODO(gtk): all of these belong to the GObject `Surface` class
// (class/surface.zig) which is out of scope. They are stubbed so the adapter
// type-checks with faithful signatures.

// core returns the core.Surface. In the real GObject class this is the
// initialized core surface; here it is a stubbed nil placeholder.
pub fn (self &GtkSurface) core() &core.Surface {
	return unsafe { nil }
}

// close closes the GObject surface.
pub fn (mut self GtkSurface) close() {}

// cgroup_path returns the cgroup path, if any.
pub fn (self &GtkSurface) cgroup_path() ?string {
	return none
}

// get_title returns the surface title, if any.
pub fn (self &GtkSurface) get_title() ?string {
	return none
}

// get_content_scale returns the content scale.
pub fn (self &GtkSurface) get_content_scale() !apprt.ContentScale {
	return apprt.ContentScale{
		x: 1.0
		y: 1.0
	}
}

// get_size returns the surface size in pixels.
pub fn (self &GtkSurface) get_size() !apprt.SurfaceSize {
	return apprt.SurfaceSize{}
}

// get_cursor_pos returns the cursor position in pixels.
pub fn (self &GtkSurface) get_cursor_pos() !apprt.CursorPos {
	return apprt.CursorPos{}
}

// clipboard_request requests clipboard contents.
pub fn (mut self GtkSurface) clipboard_request(clipboard_type apprt.Clipboard, state apprt.ClipboardRequest) !bool {
	_ = clipboard_type
	_ = state
	return false
}

// set_clipboard sets the clipboard contents.
pub fn (mut self GtkSurface) set_clipboard(clipboard_type apprt.Clipboard, contents []apprt.ClipboardContent, confirm bool) {
	_ = clipboard_type
	_ = contents
	_ = confirm
}

// default_termio_env returns the default termio environment map.
pub fn (mut self GtkSurface) default_termio_env() !map[string]string {
	return map[string]string{}
}

// redraw_inspector redraws the inspector.
pub fn (mut self GtkSurface) redraw_inspector() {}

// --- Application default() / rt() placeholders -----------------------------
// TODO(gtk): `Application.default()` and `.rt()` live on the GObject
// Application class (class/application.zig). Stubbed for `rt_app`.

// application_default returns the default (singleton) Application. Mirrors
// `Application.default()`.
fn application_default() &Application {
	return &Application{}
}

// rt returns the apprt App backing this Application. Mirrors `Application.rt()`.
pub fn (self &Application) rt() &App {
	return &App{}
}
