module main

import configpkg
import input
import macos

fn sync_config_menu(config &configpkg.Config) {
	macos.sync_native_updater_config(native_update_config(config))
	for action_text in macos.menu_actions() {
		action := input.Action.parse(action_text) or { continue }
		macos.menu_set_shortcut(action_text, config.keybind.set.get_trigger(action))
	}
}
