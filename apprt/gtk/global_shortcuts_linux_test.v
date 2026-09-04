module gtk

import configpkg
import input

fn test_global_shortcuts_refreshes_map_from_config_bindings() {
	mut inner := configpkg.Config{}
	inner.keybind.parse_cli('ctrl+x=ignore')!
	inner.keybind.parse_cli('global:ctrl+shift+a=new_window')!
	inner.keybind.parse_cli('global:ctrl+b=ignore')!
	inner.keybind.parse_cli('chain=new_window')!
	mut cfg := config_new(inner)
	mut shortcuts := GlobalShortcuts{
		config: cfg
	}

	shortcuts.refresh()

	assert shortcuts.map.len == 1
	assert shortcuts.map[0].id == 'SHIFT+CTRL+a'
	assert shortcuts.map[0].action == input.Action.new(.new_window)
	assert shortcuts.action_for_id('SHIFT+CTRL+a') or { input.Action{} } == input.Action.new(.new_window)
	assert shortcuts.action_for_id('CTRL+x') == none

	shortcuts.dispose()
	cfg.finalize()
}

fn test_global_shortcut_action_description_uses_full_action_format() {
	action := input.Action.parse('text:hello world')!
	assert action_to_string(action) == 'text:hello world'
}
