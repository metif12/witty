// Translated from Ghostty's helpgen.zig
//
// XTODO: This module needs a V-specific help generation approach.
//
// In Ghostty, this program is used to generate the help strings from the
// configuration file and CLI actions. It works by parsing Zig AST at comptime
// using @embedFile and std.zig.Ast to extract doc comments from Config fields,
// Action enums, and KeybindAction union fields.
//
// This approach cannot be directly translated to V because:
// 1. V does not have Zig AST parsing capabilities
// 2. V does not have @embedFile for comptime file inclusion
// 3. V's comptime capabilities are different from Zig's
//
// A V-specific approach would need to either:
// - Use V's compile-time reflection ($for over struct fields)
// - Use a separate code generation script that parses V source files
// - Use V's built-in doc generation with custom post-processing
// - Parse V source files at runtime to extract comments

module helpgen

// HelpEntry represents a single help text entry for a configuration field
// or action.
pub struct HelpEntry {
pub:
	name string
	text string
}

// ConfigHelp holds generated help text for all configuration fields.
pub struct ConfigHelp {
pub:
	entries []HelpEntry
}

// ActionHelp holds generated help text for all CLI actions.
pub struct ActionHelp {
pub:
	entries []HelpEntry
}

// KeybindActionHelp holds generated help text for all keybind actions.
pub struct KeybindActionHelp {
pub:
	entries []HelpEntry
}

// gen_config generates help text for configuration fields.
// XTODO: Needs V-specific implementation. In Zig this parses Config.zig AST
// to extract doc comments from struct fields.
pub fn gen_config() ConfigHelp {
	return ConfigHelp{
		entries: []
	}
}

// gen_actions generates help text for CLI actions.
// XTODO: Needs V-specific implementation. In Zig this iterates over Action
// enum fields and finds the "run" function's doc comment in each action file.
pub fn gen_actions() ActionHelp {
	return ActionHelp{
		entries: []
	}
}

// gen_keybind_actions generates help text for keybind actions.
// XTODO: Needs V-specific implementation. In Zig this parses Binding.zig AST
// to extract doc comments from union fields.
pub fn gen_keybind_actions() KeybindActionHelp {
	return KeybindActionHelp{
		entries: []
	}
}

// find_common_prefix finds the minimum leading whitespace across all lines.
// This is used to strip common indentation from doc comments.
fn find_common_prefix(lines []string) int {
	mut m := max_int
	for line in lines {
		mut n := max_int
		for i, c in line {
			if c != ` ` {
				n = i
				break
			}
		}
		if n < m {
			m = n
		}
	}
	return m
}

const max_int = 2147483647
