// Translated from Ghostty's helpgen.zig.
//
// Zig's generator combines compile-time reflection with its Zig AST parser.
// V does not expose its parser as a stable library API, so this translation
// reads the declarations that are the source of truth and extracts their
// adjacent documentation comments at generation time.
module main

import os

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

// gen_config extracts the public fields of configpkg.Config.
pub fn gen_config() ConfigHelp {
	return ConfigHelp{
		entries: declaration_help('configpkg/configpkg.v', 'pub struct Config {')
	}
}

// gen_actions extracts the CLI action enum used by global initialization.
pub fn gen_actions() ActionHelp {
	return ActionHelp{
		entries: declaration_help('global_state/global_state.v', 'pub enum Action {')
	}
}

// gen_keybind_actions extracts input.ActionTag, the keybinding action union
// equivalent in the V translation.
pub fn gen_keybind_actions() KeybindActionHelp {
	return KeybindActionHelp{
		entries: declaration_help('input/binding.v', 'pub enum ActionTag {')
	}
}

fn declaration_help(relative_path string, declaration string) []HelpEntry {
	path := os.join_path(os.dir(@FILE), relative_path)
	source := os.read_file(path) or { return []HelpEntry{} }
	return extract_declaration_help(source, declaration)
}

fn extract_declaration_help(source string, declaration string) []HelpEntry {
	mut result := []HelpEntry{}
	mut found := false
	mut depth := 0
	mut docs := []string{}

	for raw_line in source.split_into_lines() {
		line := raw_line.trim_space()
		if !found {
			if line == declaration {
				found = true
				depth = 1
			}
			continue
		}

		// Fields live at declaration depth one. Braces in defaults or later
		// method bodies must not be mistaken for fields.
		if depth == 1 {
			if line == '}' {
				break
			}
			if line.starts_with('//') {
				docs << line[2..].trim_string_left('/').trim_space()
				continue
			}
			if line.len == 0 {
				docs = []
				continue
			}
			if line == 'pub:' || line == 'mut:' || line == 'pub mut:' || line.starts_with('@[') {
				continue
			}

			name := declaration_member_name(line)
			if name.len > 0 && !name.starts_with('_') {
				result << HelpEntry{
					name: name
					text: normalize_doc_lines(docs)
				}
			}
			docs = []
		}

		depth += brace_delta(line)
		if depth <= 0 {
			break
		}
	}

	return result
}

fn declaration_member_name(line string) string {
	// Enum members may carry an explicit value and struct fields are followed
	// by whitespace and a type. Commas and attributes are stripped as well.
	mut end := line.len
	for separator in [` `, `\t`, `=`, `,`] {
		idx := line.index_u8(separator)
		if idx >= 0 && idx < end {
			end = idx
		}
	}
	if end == 0 {
		return ''
	}
	name := line[..end]
	if name.contains('(') || name.contains(':') || name == '{' {
		return ''
	}
	return name.trim('`"')
}

fn brace_delta(line string) int {
	mut delta := 0
	mut quoted := false
	mut quote := u8(0)
	mut escaped := false
	for c in line.bytes() {
		if escaped {
			escaped = false
			continue
		}
		if quoted && c == `\\` {
			escaped = true
			continue
		}
		if c == `'` || c == `"` {
			if !quoted {
				quoted = true
				quote = c
			} else if quote == c {
				quoted = false
			}
			continue
		}
		if quoted {
			continue
		}
		if c == `{` {
			delta++
		} else if c == `}` {
			delta--
		}
	}
	return delta
}

fn normalize_doc_lines(lines []string) string {
	if lines.len == 0 {
		return ''
	}
	prefix := find_common_prefix(lines)
	mut normalized := []string{cap: lines.len}
	for line in lines {
		start := if prefix < line.len { prefix } else { line.len }
		normalized << line[start..]
	}
	return normalized.join('\n')
}

// find_common_prefix finds the minimum leading whitespace across non-empty
// lines. Empty documentation lines do not force the prefix to zero.
fn find_common_prefix(lines []string) int {
	mut minimum := max_int
	for line in lines {
		if line.len == 0 {
			continue
		}
		mut count := 0
		for c in line.bytes() {
			if c != ` ` && c != `\t` {
				break
			}
			count++
		}
		if count < minimum {
			minimum = count
		}
	}
	return if minimum == max_int { 0 } else { minimum }
}

const max_int = 2147483647
