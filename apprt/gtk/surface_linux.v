module gtk

// surface_linux.v - The thin apprt Surface adapter for the GTK runtime.
//
// Translated from ghostty/src/apprt/gtk/Surface.zig.
//
// Like the App adapter, in ghostty this is a thin wrapper around the GObject
// `Surface` class (class/surface.zig). That GObject class is out of scope for
// this translation, so `GtkSurface` (the GObject) and `CoreSurface` are
// declared as minimal placeholder stubs below to keep this adapter
// type-checking; the apprt-interface method signatures stay faithful to the
// Zig original.

import apprt
import input

// TODO(gtk): GObject class `Surface` (class/surface.zig) — out of scope. This
// minimal placeholder stands in for the GObject Surface instance. The real
// class is a GTK widget wrapping the terminal renderer, input handling, etc.
pub struct GtkSurface {}

// TODO(gtk): CoreSurface is `witty`'s root `main.Surface`. The gtk module
// cannot import the `main` module, so this is a minimal placeholder used only
// to keep the adapter signatures faithful.
@[heap]
pub struct CoreSurface {}

// --- CoreSurface placeholder callbacks -------------------------------------
// TODO(gtk): these all live on `main.Surface` (unimportable). They are stubbed
// here with faithful signatures so surface_class_linux.v type-checks. The
// SurfaceWidget input handlers call these.

// key_callback forwards a key event to the core surface. Mirrors
// `CoreSurface.keyCallback`.
pub fn (mut self CoreSurface) key_callback(event input.KeyEvent) !apprt.InputEffect {
	_ = event
	return apprt.InputEffect.ignored
}

// preedit_callback updates the preedit (composing) text. Mirrors
// `CoreSurface.preeditCallback`. Empty string clears the preedit.
pub fn (mut self CoreSurface) preedit_callback(text string) ! {
	_ = text
}

// mouse_button_callback forwards a mouse button event. Mirrors
// `CoreSurface.mouseButtonCallback`.
pub fn (mut self CoreSurface) mouse_button_callback(state input.MouseButtonState, button input.MouseButton, mods input.Mods) !bool {
	_ = state
	_ = button
	_ = mods
	return false
}

// cursor_pos_callback forwards a cursor position. Mirrors
// `CoreSurface.cursorPosCallback`.
pub fn (mut self CoreSurface) cursor_pos_callback(pos apprt.CursorPos, mods input.Mods) ! {
	_ = pos
	_ = mods
}

// scroll_callback forwards a scroll event. Mirrors `CoreSurface.scrollCallback`.
pub fn (mut self CoreSurface) scroll_callback(xoff f64, yoff f64, mods input.ScrollMods) ! {
	_ = xoff
	_ = yoff
	_ = mods
}

// focus_callback forwards a focus change. Mirrors `CoreSurface.focusCallback`.
pub fn (mut self CoreSurface) focus_callback(focused bool) ! {
	_ = focused
}

// content_scale_callback forwards a content-scale change. Mirrors
// `CoreSurface.contentScaleCallback`.
pub fn (mut self CoreSurface) content_scale_callback(scale apprt.ContentScale) ! {
	_ = scale
}

// size_callback forwards a size change. Mirrors `CoreSurface.sizeCallback`.
pub fn (mut self CoreSurface) size_callback(size apprt.SurfaceSize) ! {
	_ = size
}

// has_selection reports whether the surface has an active selection. Mirrors
// `CoreSurface.hasSelection`.
pub fn (self &CoreSurface) has_selection() bool {
	return false
}

// display_realized notifies the renderer that the display was realized.
// Mirrors `CoreSurface.renderer.displayRealized`.
pub fn (mut self CoreSurface) display_realized() ! {}

// display_unrealized notifies the renderer that the display was unrealized.
// Mirrors `CoreSurface.renderer.displayUnrealized`.
pub fn (mut self CoreSurface) display_unrealized() {}

// draw_frame draws a frame. Mirrors `CoreSurface.renderer.drawFrame`.
pub fn (mut self CoreSurface) draw_frame(sync bool) ! {
	_ = sync
}

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

// core returns the CoreSurface for this apprt surface. Mirrors `Surface.core`.
//
// In Zig this asserts non-optional because libghostty should only call this
// for initialized surfaces.
pub fn (mut self Surface) core() &CoreSurface {
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

// core returns the (optional) CoreSurface. Here it is always non-nil.
pub fn (self &GtkSurface) core() &CoreSurface {
	return &CoreSurface{}
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
