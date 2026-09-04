module gtk

import configpkg
import input

fn test_command_palette_action_accelerator_from_config_keybind() {
	mut inner := configpkg.Config{}
	inner.keybind.parse_cli('ctrl+shift+a=new_window')!
	mut cfg := config_new(inner)
	mut command := command_new(cfg, input.Command{
		action: input.Action.new(.new_window)
		title: 'New Window'
	})

	assert command.prop_get_action() or { '' } == '<Shift><Ctrl>a'
	// The derived value is cached just as it is in Ghostty's GObject wrapper.
	assert command.prop_get_action() or { '' } == '<Shift><Ctrl>a'

	command.dispose()
	cfg.finalize()
}

fn test_command_palette_action_without_keybind_is_none() {
	mut cfg := config_new(configpkg.Config{})
	mut command := command_new(cfg, input.Command{
		action: input.Action.new(.new_window)
		title: 'New Window'
	})

	assert command.prop_get_action() == none

	command.dispose()
	cfg.finalize()
}

fn test_command_palette_uses_configured_entries() {
	mut inner := configpkg.Config.default_config()
	inner.load_string('command-palette-entry =\ncommand-palette-entry = title:Only Entry,description:Configured,action:ignore')
	mut cfg := config_new(inner)
	mut palette := new_command_palette()
	palette.config = cfg
	palette.prop_config()

	assert palette.commands.len == 1
	mut command := palette.commands[0]
	assert command.prop_get_title() or { '' } == 'Only Entry'
	assert command.prop_get_description() or { '' } == 'Configured'
	assert command.get_action() or { input.Action{} } == input.Action.new(.ignore)

	for mut item in palette.commands {
		item.dispose()
	}
	cfg.finalize()
}
