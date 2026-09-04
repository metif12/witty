module gtk

// config_class_linux.v - The GObject config wrapper (GhosttyConfig).
//
// Translated from ghostty/src/apprt/gtk/class/config.zig.
//
// In ghostty this is a GObject class that wraps a `configpkg.Config` (the core
// config) so it can be reference counted; when the wrapper is freed the
// underlying config is freed. It also exposes GTK-ergonomic helpers over the
// config (diagnostics as a `gtk.TextBuffer`, a `has-diagnostics` flag) and is
// the canonical owner of the `Config` type used throughout the GTK apprt.
//
// This file is the OWNER of the `Config` type. (window_linux.v previously held
// a placeholder `Config`; that placeholder was removed and the canonical
// definition — plus the GTK-specific config getters window_linux.v relies on —
// moved here.)
//
// V has no GObject class-registration / comptime / property machinery, so:
//   * `Config` is a plain V struct wrapping the underlying GObject pointer
//     (`obj`) plus the core config value it owns (`inner`). The core
//     `configpkg.Config` is held by value since witty's gtk module owns it
//     directly (ghostty keeps it in the GObject `Private`).
//   * GObject type registration (`defineClass`), the `diagnostics-buffer` /
//     `has-diagnostics` GObject PROPERTIES, and the `finalize` vfunc are
//     STUBBED — see the "GObject class registration" section — with bodies that
//     type-check. The property GETTERS themselves (has_diagnostics /
//     diagnostics_buffer) are translated as real methods.

import configpkg

// --- New GTK C bindings ---------------------------------------------------
// Only functions not already declared anywhere else in the module.
// GtkTextBuffer is aliased in dialog_linux.v — reused here, NOT redeclared.

fn C.gtk_text_buffer_new(table voidptr) GtkTextBuffer
fn C.gtk_text_buffer_insert_at_cursor(buffer GtkTextBuffer, text &char, len int)

// --- Config ---------------------------------------------------------------

// Config is the GObject config wrapper (`GhosttyConfig`). It wraps a
// `configpkg.Config` so it can be reference counted, and exposes GTK-friendly
// accessors over it.
//
// It is highly recommended NOT to hold a long-lived reference to this object,
// since configuration takes up a lot of memory (relatively). Instead, receivers
// should usually derive a smaller struct, copy any memory they require, and own
// that instead.
//
// `@[heap]` so callers (Window etc.) can hold a stable `&Config`.
@[heap]
pub struct Config {
mut:
	// The underlying GhosttyConfig GObject instance pointer.
	//
	// TODO(gtk): GObject class registration — in ghostty this instance is
	// created via `gobject.ext.newInstance`; here it is a stubbed handle.
	obj GObject = unsafe { nil }

	// The wrapped core configuration. Ghostty keeps this in the GObject
	// `Private`; here we own it by value.
	inner configpkg.Config
}

// config_new wraps a core config value in a Config GObject. Mirrors
// `Config.new`, which clones the given config so the caller may free the
// original afterwards.
pub fn config_new(inner configpkg.Config) &Config {
	// TODO(gtk): ghostty calls `gobject.ext.newInstance(Self, .{})` then
	// `priv.config = try config.clone(alloc)`. Here we take the (already
	// cloned/owned) value directly.
	return &Config{
		inner: inner
	}
}

// get returns the wrapped (immutable) core configuration. It is unsafe to store
// this or access it beyond the lifetime of this object. Mirrors `Config.get`.
pub fn (self &Config) get() &configpkg.Config {
	return &self.inner
}

// get_mut returns the MUTABLE core configuration. This is usually NOT
// recommended because changes won't be propagated to holders of a reference to
// this object. Mirrors `Config.getMut`.
pub fn (mut self Config) get_mut() &configpkg.Config {
	return &self.inner
}

// has_diagnostics reports whether this configuration has any diagnostics.
// Mirrors `Config.hasDiagnostics` (backs the `has-diagnostics` property).
pub fn (self &Config) has_diagnostics() bool {
	return self.inner.diagnostics.len > 0
}

// diagnostics_buffer reads the diagnostics of this configuration as a
// GtkTextBuffer, or returns a nil buffer if there are no diagnostics. Mirrors
// `Config.diagnosticsBuffer` (backs the `diagnostics-buffer` property, transfer
// full).
pub fn (self &Config) diagnostics_buffer() GtkTextBuffer {
	if self.inner.diagnostics.len == 0 {
		return unsafe { nil }
	}

	text_buf := C.gtk_text_buffer_new(unsafe { nil })
	for diag in self.inner.diagnostics {
		// In ghostty each diagnostic is formatted into a fixed buffer via
		// `diag.format(&writer)`; here `Diagnostic.str()` yields the message.
		msg := diag.str()
		C.gtk_text_buffer_insert_at_cursor(text_buf, &char(msg.str), msg.len)
		C.gtk_text_buffer_insert_at_cursor(text_buf, c'\n', 1)
	}

	return text_buf
}

// --- GObject reference counting -------------------------------------------
// Mirrors the `Common(Self, Private)` ref helpers.

// ref increments the reference count of the config GObject. Mirrors `ref`.
pub fn (mut self Config) ref() &Config {
	if !isnil(self.obj) {
		object_ref(self.obj)
	}
	return self
}

// unref decrements the reference count of the config GObject. Mirrors `unref`.
// When the count reaches zero the GObject finalizer frees the wrapped config.
pub fn (mut self Config) unref() {
	if !isnil(self.obj) {
		object_unref(self.obj)
	}
}

// finalize deinitializes the wrapped configuration and chains to the parent
// finalizer. Mirrors the `finalize` vfunc.
//
// TODO(gtk): GObject class registration — in ghostty this is registered on the
// class and chained to `gobject.Object.virtual_methods.finalize`. Here it is a
// plain method; the core config is a plain V value freed by the GC.
fn (mut self Config) finalize() {
	// self.inner is a plain value; nothing to explicitly deinit.
}

// --- GTK-specific config accessors ----------------------------------------
//
// These expose GTK-only core configuration to the window wrapper.

// gtk_titlebar_style mirrors `config.@"gtk-titlebar-style"`.
pub fn (self &Config) gtk_titlebar_style() configpkg.GtkTitlebarStyle {
	return self.inner.gtk_titlebar_style
}

// gtk_titlebar mirrors `config.@"gtk-titlebar"`.
pub fn (self &Config) gtk_titlebar() bool {
	return self.inner.gtk_titlebar
}

// gtk_titlebar_hide_when_maximized mirrors
// `config.@"gtk-titlebar-hide-when-maximized"`.
pub fn (self &Config) gtk_titlebar_hide_when_maximized() bool {
	return self.inner.gtk_titlebar_hide_when_maximized
}

// window_show_tab_bar mirrors `config.@"window-show-tab-bar"`.
pub fn (self &Config) window_show_tab_bar() configpkg.WindowShowTabBar {
	return self.inner.window_show_tab_bar
}

// gtk_wide_tabs mirrors `config.@"gtk-wide-tabs"`.
pub fn (self &Config) gtk_wide_tabs() bool {
	return self.inner.gtk_wide_tabs
}

// gtk_toolbar_style mirrors `config.@"gtk-toolbar-style"`.
pub fn (self &Config) gtk_toolbar_style() configpkg.GtkToolbarStyle {
	return self.inner.gtk_toolbar_style
}

// gtk_tabs_location mirrors `config.@"gtk-tabs-location"`.
pub fn (self &Config) gtk_tabs_location() configpkg.GtkTabsLocation {
	return self.inner.gtk_tabs_location
}

// window_new_tab_position mirrors `config.@"window-new-tab-position"`.
pub fn (self &Config) window_new_tab_position() configpkg.WindowNewTabPosition {
	return self.inner.window_new_tab_position
}
