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

	assert cfg.window_new_tab_position() == .end
	assert cfg.window_show_tab_bar() == .always
	assert !cfg.gtk_titlebar()
	assert cfg.gtk_tabs_location() == .bottom
	assert cfg.gtk_titlebar_hide_when_maximized()
	assert cfg.gtk_toolbar_style() == .flat
	assert cfg.gtk_titlebar_style() == .tabs
	assert !cfg.gtk_wide_tabs()

	cfg.finalize()
}
