module gtk

import configpkg

fn test_gtk_config_accessors_use_core_values() {
	mut inner := configpkg.Config.default_config()
	inner.load_string('window-new-tab-position = end
window-show-tab-bar = always
gtk-titlebar = false
gtk-tabs-location = bottom
gtk-titlebar-hide-when-maximized = true
gtk-toolbar-style = flat
gtk-titlebar-style = tabs
gtk-wide-tabs = false')
	mut cfg := config_new(inner)
	assert !isnil(cfg.obj)
	assert config_get_type() != GType(0)

	assert cfg.window_new_tab_position() == .end
	assert cfg.window_show_tab_bar() == .always
	assert !cfg.gtk_titlebar()
	assert cfg.gtk_tabs_location() == .bottom
	assert cfg.gtk_titlebar_hide_when_maximized()
	assert cfg.gtk_toolbar_style() == .flat
	assert cfg.gtk_titlebar_style() == .tabs
	assert !cfg.gtk_wide_tabs()

	cfg.unref()
}

fn test_gtk_config_diagnostics_buffer_matches_fixed_writer_capacity() {
	mut inner := configpkg.Config.default_config()
	mut empty_cfg := config_new(inner)
	if _ := empty_cfg.diagnostics_buffer() {
		assert false
	}
	empty_cfg.unref()

	inner.add_diagnostic_fmt('short')
	inner.add_diagnostic_fmt('x'.repeat(4095))
	inner.add_diagnostic_fmt('y'.repeat(4096))
	mut cfg := config_new(inner)

	buffer := cfg.diagnostics_buffer() or {
		assert false
		return
	}
	mut text_ptr := &char(unsafe { nil })
	C.g_object_get(GObject(buffer), c'text', &text_ptr, unsafe { nil })
	text := unsafe { cstring_to_vstring(text_ptr) }
	assert text == 'short\n${'x'.repeat(4095)}\n'

	C.g_free(text_ptr)
	object_unref(GObject(buffer))
	cfg.unref()
}
