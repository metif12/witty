module main

import configpkg
import macos

fn native_window_config(config &configpkg.Config) macos.NativeWindowConfig {
	c := config.background
	return macos.NativeWindowConfig{title: if title := config.title { title.clone() } else { none }, decorations: config.window_decoration != .none_, position_x: config.window_position_x, position_y: config.window_position_y, buttons_hidden: config.macos_window_buttons == .hidden, shadow: config.macos_window_shadow, titlebar_style: int(config.macos_titlebar_style), theme: int(config.window_theme), background: u32(c.r) << 16 | u32(c.g) << 8 | c.b, opacity: config.background_opacity, blur: config.background_blur.cval(), step_resize: config.window_step_resize, proxy_icon: config.macos_titlebar_proxy_icon == .visible, preserve_split_zoom: config.split_preserve_zoom.navigation()}
}
fn sync_native_window(current &TermState) {
	if current.controller == unsafe { nil } { return }
	mut chosen := current
	tree := current.controller.host.tree
	if node := tree.root.find(current.view) {
		if !tree.borders(.up, node) {
			views := tree.root.leaves()
			if views.len > 0 {
				chosen = state_from_userdata(macos.view_get_userdata(views[0])) or { current }
			}
		}
	}
	background := chosen.background_color or { chosen.native_config.background }
	macos.apply_native_window_config(current.view, current.native_config, false, background, chosen.native_config.opacity, current.controller.force_opaque)
}
