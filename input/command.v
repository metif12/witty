module input

// Command is a named binding action that can be executed from
// something like a command palette.
//
// A command must be associated with a binding; all commands can be
// mapped to traditional keybind configurations. This restriction
// makes it so that there is nothing special about commands and likewise
// it makes it trivial and consistent to define custom commands.
pub struct Command {
pub:
	// The action to perform when this command is triggered.
	action Action
	// The human-readable title of the command.
	title string
	// A longer description of what the command does.
	description string
}

// clone creates a deep copy of a Command.
pub fn (c Command) clone() Command {
	return Command{
		action: c.action
		title: c.title
		description: c.description
	}
}

// equal returns true if two commands are equal.
pub fn (a Command) equal(b Command) bool {
	return a.action.equal(b.action) && a.title == b.title && a.description == b.description
}

// less_than implements comparison for sorting commands alphabetically by title.
pub fn (a Command) less_than(b Command) bool {
	return a.title.to_lower() < b.title.to_lower()
}

// XTODO: defaults and defaultsC cannot be generated because they depend on
// iterating over Action.Key enum fields and calling actionCommands() for each,
// which requires the full Binding.zig Action type with all its variants.
// The Zig version uses comptime to build these at compile time.
pub const command_defaults = []Command{}
