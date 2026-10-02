module main

import help_strings

pub type HelpEntry = help_strings.HelpEntry
pub type ConfigHelp = help_strings.ConfigHelp
pub type ActionHelp = help_strings.ActionHelp
pub type KeybindActionHelp = help_strings.KeybindActionHelp

pub fn gen_config() ConfigHelp { return help_strings.gen_config() }
pub fn gen_actions() ActionHelp { return help_strings.gen_actions() }
pub fn gen_keybind_actions() KeybindActionHelp { return help_strings.gen_keybind_actions() }
fn generated_help_entries(source string, marker string) []HelpEntry {
 return help_strings.generated_help_entries(source, marker)
}
