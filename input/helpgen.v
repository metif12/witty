module input

// This module is a help generator for keybind actions documentation.
// It can generate documentation in different formats (plaintext for CLI,
// markdown for website) while maintaining consistent content.

// HelpFormat represents the output format for documentation.
pub enum HelpFormat {
	// Plain text output with indentation.
	plaintext
	// Markdown formatted output.
	markdown
}

// XTODO: generate() cannot be fully translated because it depends on
// iterating over the Action union fields and accessing help_strings,
// which requires the full Binding.zig infrastructure and comptime
// string generation. The Zig version uses @typeInfo to enumerate
// union fields and @hasDecl to check for help string declarations.

// generate_help generates keybind actions documentation.
pub fn generate_help(format HelpFormat, show_docs bool) string {
	// XTODO: Needs Binding.zig Action union field iteration and help_strings module
	return ''
}
