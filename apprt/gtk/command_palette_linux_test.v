module gtk

import configpkg
import input

fn test_command_palette_action_accelerator_from_config_keybind() {
	mut inner := configpkg.Config{}
	inner.keybind.parse_cli('ctrl+shift+a=new_window')!
	mut cfg := config_new(inner)
	mut command := Command.new(cfg, input.Command{
		action: input.Action.new(.new_window)
		title: 'New Window'
	})

	assert command.prop_get_action() or { '' } == '<Shift><Ctrl>a'
	// The derived value is cached just as it is in Ghostty's GObject wrapper.
	assert command.prop_get_action() or { '' } == '<Shift><Ctrl>a'

	command.dispose()
	cfg.unref()
}

fn test_command_palette_action_without_keybind_is_none() {
	mut cfg := config_new(configpkg.Config{})
	mut command := Command.new(cfg, input.Command{
		action: input.Action.new(.new_window)
		title: 'New Window'
	})

	assert command.prop_get_action() == none

	command.dispose()
	cfg.unref()
}

fn test_regular_command_has_no_jump_surface() {
	mut cfg := config_new(configpkg.Config{})
	mut command := Command.new(cfg, input.Command{
		action: input.Action.new(.new_window)
		title: 'New Window'
	})

	assert command.get_jump_surface() == none

	command.dispose()
	cfg.unref()
}

fn test_command_palette_action_key_uses_full_action_format() {
	mut cfg := config_new(configpkg.Config{})
	mut command := Command.new(cfg, input.Command{
		action: input.Action.new_str(.text, 'hello world')
		title: 'Type Text'
	})

	assert command.prop_get_action_key() or { '' } == 'text:hello world'

	command.dispose()
	cfg.unref()
}

fn test_command_palette_filter_matches_title_or_action_key() {
	mut palette := &CommandPalette{}
	palette.commands = [
		&Command{
			command: input.Command{
				action: input.Action.new(.new_window)
				title: 'Open a Window'
			}
		},
		&Command{
			command: input.Command{
				action: input.Action.new(.copy_to_clipboard)
				title: 'Copy Selection'
			}
		},
	]

	assert palette.filter('OPEN') == [0]
	assert palette.filter('copy_to_clipboard') == [1]
	assert palette.filter('missing').len == 0
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

	palette.dispose()
	cfg.unref()
}
