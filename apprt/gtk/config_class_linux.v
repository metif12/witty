@[has_globals]
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
// Witty hand-expands Ghostty's GObject registration onto the C API. The V
// wrapper owns the core configuration while the GObject provides the
// `diagnostics-buffer` and `has-diagnostics` properties used by GTK bindings.

import configpkg

// --- New GTK C bindings ---------------------------------------------------
// Only functions not already declared anywhere else in the module.
// GtkTextBuffer is aliased in dialog_linux.v — reused here, NOT redeclared.

fn C.gtk_text_buffer_new(table voidptr) GtkTextBuffer

fn C.gtk_text_buffer_insert_at_cursor(buffer GtkTextBuffer, text &char, len int)

fn C.gtk_text_buffer_get_type() GType

// --- GObject class registration -------------------------------------------

struct C.GhosttyConfigPrivate {
mut:
	wrapper voidptr
}

__global g_config_type = GType(0)
__global g_config_pspec_diagnostics_buffer = &C.GParamSpec(unsafe { nil })
__global g_config_pspec_has_diagnostics = &C.GParamSpec(unsafe { nil })

const config_prop_diagnostics_buffer = u32(1)
const config_prop_has_diagnostics = u32(2)

fn config_priv(obj voidptr) &C.GhosttyConfigPrivate {
	return &C.GhosttyConfigPrivate(C.g_type_instance_get_private(obj, g_config_type))
}

fn config_get_property(obj voidptr, property_id u32, value voidptr, pspec voidptr) {
	_ = pspec
	priv := config_priv(voidptr(obj))
	if isnil(priv.wrapper) {
		match property_id {
			config_prop_diagnostics_buffer { C.g_value_set_object(value, unsafe { nil }) }
			config_prop_has_diagnostics { C.g_value_set_boolean(value, 0) }
			else {}
		}
		return
	}
	wrapper := unsafe { &Config(priv.wrapper) }
	match property_id {
		config_prop_diagnostics_buffer {
			buffer := wrapper.diagnostics_buffer()
			C.g_value_set_object(value, buffer)
			if !isnil(buffer) {
				object_unref(GObject(buffer))
			}
		}
		config_prop_has_diagnostics {
			C.g_value_set_boolean(value, b2i(wrapper.has_diagnostics()))
		}
		else {}
	}
}

fn config_finalize_object(obj voidptr) {
	mut priv := config_priv(voidptr(obj))
	if !isnil(priv.wrapper) {
		mut wrapper := unsafe { &Config(priv.wrapper) }
		wrapper.inner.deinit()
		wrapper.obj = unsafe { nil }
		priv.wrapper = unsafe { nil }
	}
	C.witty_gobject_call_parent_finalize(obj)
}

fn config_class_init(klass voidptr, class_data voidptr) {
	_ = class_data
	g_config_pspec_diagnostics_buffer = C.g_param_spec_object(c'diagnostics-buffer', c'diagnostics-buffer', c'The formatted configuration diagnostics', C.gtk_text_buffer_get_type(), g_param_readable)
	g_config_pspec_has_diagnostics = C.g_param_spec_boolean(c'has-diagnostics', c'has-diagnostics', c'Whether configuration diagnostics exist', 0, g_param_readable)
	C.witty_gobject_class_set_get_property(klass, voidptr(config_get_property))
	C.witty_gobject_class_set_finalize(klass, voidptr(config_finalize_object))
	C.g_object_class_install_property(klass, config_prop_diagnostics_buffer, g_config_pspec_diagnostics_buffer)
	C.g_object_class_install_property(klass, config_prop_has_diagnostics, g_config_pspec_has_diagnostics)
}

pub fn config_get_type() GType {
	if g_config_type == GType(0) {
		parent := C.g_object_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size: u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init: voidptr(config_class_init)
		}
		g_config_type = C.g_type_register_static(parent, c'GhosttyConfig', &info, 0)
		C.g_type_add_instance_private(g_config_type, sizeof(C.GhosttyConfigPrivate))
	}
	return g_config_type
}

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
	obj GObject = unsafe { nil }

	// The wrapped core configuration. Ghostty keeps this in the GObject
	// `Private`; here we own it by value.
	inner configpkg.Config
}

// config_new wraps a core config value in a Config GObject. Mirrors
// `Config.new`, which clones the given config so the caller may free the
// original afterwards.
pub fn config_new(inner configpkg.Config) &Config {
	obj := GObject(C.g_object_new(config_get_type(), &char(unsafe { nil })))
	mut self := &Config{
		obj: obj
		inner: inner.clone()
	}
	mut priv := config_priv(voidptr(obj))
	priv.wrapper = voidptr(self)
	return self
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

// replace swaps the owned core configuration. Application uses this to keep
// the stable wrapper shared by windows/global shortcuts synchronized across a
// reload, matching Ghostty's config GObject property replacement semantics.
pub fn (mut self Config) replace(inner configpkg.Config) {
	self.inner.deinit()
	self.inner = inner
	if !isnil(self.obj) {
		C.g_object_notify_by_pspec(self.obj, g_config_pspec_diagnostics_buffer)
		C.g_object_notify_by_pspec(self.obj, g_config_pspec_has_diagnostics)
	}
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
