// Translated from Ghostty's helpgen.zig.
//
// Zig's generator combines compile-time reflection with its Zig AST parser.
// The generated records are embedded here so this translated interface has
// the same output without depending on source files at runtime.
module main

import cli
import configpkg
import input

// HelpEntry represents a single documented configuration field or action.
pub struct HelpEntry {
pub:
	name string
	text string
}

pub struct ConfigHelp {
pub:
	entries []HelpEntry
}

pub struct ActionHelp {
pub:
	entries []HelpEntry
}

pub struct KeybindActionHelp {
pub:
	entries []HelpEntry
}

// gen_config returns the generated public Config field documentation.
pub fn gen_config() ConfigHelp {
	return ConfigHelp{
		entries: generated_help_entries(configpkg.generated_config_help_data(), '\x1e').filter(!it.name.starts_with('_'))
	}
}

// gen_actions returns the generated documentation from every CLI action run
// function, in source enum order.
pub fn gen_actions() ActionHelp {
	return ActionHelp{
		entries: generated_help_entries(cli.generated_action_help_data(), '@@')
	}
}

// gen_keybind_actions returns the generated Binding.Action union docs.
pub fn gen_keybind_actions() KeybindActionHelp {
	return KeybindActionHelp{
		entries: generated_help_entries(input.generated_action_help_data(), '@@')
	}
}

fn generated_help_entries(source string, marker string) []HelpEntry {
	mut result := []HelpEntry{}
	mut name := ''
	mut docs := []string{}
	for line in source.split_into_lines() {
		if line.starts_with(marker) {
			if name.len > 0 && name != '__end' {
				result << HelpEntry{
					name: name
					text: docs.join('\n')
				}
			}
			name = line[marker.len..]
			docs = []string{}
			continue
		}
		docs << line
	}
	if name.len > 0 && name != '__end' {
		result << HelpEntry{
			name: name
			text: docs.join('\n')
		}
	}
	return result
}
