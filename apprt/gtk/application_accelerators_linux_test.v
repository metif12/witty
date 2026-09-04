module gtk

import configpkg
import input

fn test_application_accelerator_uses_reverse_keybind_lookup() {
	mut cfg := configpkg.Config{}
	cfg.keybind.parse_cli('ctrl+shift+a=new_split:left')!
	app := Application{
		config: cfg
	}
	action := input.Action.new_enum(.new_split, i32(input.SplitDirection.left))

	assert app.accelerator_for_action(action) or { '' } == '<Shift><Ctrl>a'
	assert app.accelerator_for_action(input.Action.new_enum(.new_split, i32(input.SplitDirection.right))) == none
}

fn test_application_accelerator_ignores_chained_binding() {
	mut cfg := configpkg.Config{}
	cfg.keybind.parse_cli('global:ctrl+b=ignore')!
	cfg.keybind.parse_cli('chain=new_window')!
	app := Application{
		config: cfg
	}

	assert app.accelerator_for_action(input.Action.new(.ignore)) == none
	assert app.accelerator_for_action(input.Action.new(.new_window)) == none
}
