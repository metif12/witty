module gtk

import configpkg
import input

fn test_command_palette_action_accelerator_from_config_keybind() {
	mut inner := configpkg.Config{}
	inner.keybind.parse_cli('ctrl+shift+a=new_window')!
	mut cfg := config_new(inner)
	mut command := Command.new(cfg, input.Command{
		action: input.ActionNewWindow{}
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
		action: input.ActionNewWindow{}
		title: 'New Window'
	})

	assert command.prop_get_action() == none

	command.dispose()
	cfg.unref()
}

fn test_regular_command_has_no_jump_surface() {
	mut cfg := config_new(configpkg.Config{})
	mut command := Command.new(cfg, input.Command{
		action: input.ActionNewWindow{}
		title: 'New Window'
	})

	assert command.get_jump_surface() == none

	command.dispose()
	cfg.unref()
}

fn test_command_data_retains_only_the_active_payload() {
	regular := Command{
		data: RegularData{
			command: input.Command{
				action: input.ActionIgnore{}
				title: 'Regular'
			}
		}
	}
	assert regular.data is RegularData
	assert !regular.is_jump()

	jump := Command{
		data: JumpData{
			sort_key: 42
		}
	}
	assert jump.data is JumpData
	assert jump.is_jump()
	assert jump.get_action() == none
}

fn test_command_palette_action_key_uses_full_action_format() {
	mut cfg := config_new(configpkg.Config{})
	mut command := Command.new(cfg, input.Command{
		action: input.ActionText{ value: 'hello world' }
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
			data: RegularData{
				command: input.Command{
					action: input.ActionNewWindow{}
					title: 'Open a Window'
				}
			}
		},
		&Command{
			data: RegularData{
				command: input.Command{
					action: input.ActionCopyToClipboard{}
					title: 'Copy Selection'
				}
			}
		},
	]

	assert palette.filter('OPEN') == [0]
	assert palette.filter('copy_to_clipboard') == [1]
	assert palette.filter('missing').len == 0
}

fn C.gtk_init_check() bool

fn test_command_palette_uses_configured_entries() {
	// The palette builds real Adwaita widgets, which need GTK initialized
	// against a display. A headless test run has none, so skip there.
	if !C.gtk_init_check() {
		eprintln('skipping: GTK could not open a display')
		return
	}
	C.adw_init()
	mut inner := configpkg.Config.default_config()
	// Start from an empty list. `command-palette-entry =` would not do it: as in
	// Ghostty's cli/args.zig, an empty value resets a field with an `init` to
	// that `init`, which reloads the default entries.
	inner.command_palette_entry = configpkg.RepeatableCommand{}
	inner.load_string('command-palette-entry = title:Only Entry,description:Configured,action:ignore')
	mut cfg := config_new(inner)
	mut palette := new_command_palette()
	palette.config = cfg
	palette.prop_config()

	assert palette.commands.len == 1
	mut command := palette.commands[0]
	assert command.prop_get_title() or { '' } == 'Only Entry'
	assert command.prop_get_description() or { '' } == 'Configured'
	assert command.get_action() or { panic('missing command action') } == input.Action(input.ActionIgnore{})

	palette.dispose()
	cfg.unref()
}
