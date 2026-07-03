module input

// --- Original Ghostty Comments Start: src/input/command.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/input/command.zig
//
// A command is a named binding action that can be executed from
// something like a command palette.
//
// A command must be associated with a binding; all commands can be
// mapped to traditional `keybind` configurations. This restriction
// makes it so that there is nothing special about commands and likewise
// it makes it trivial and consistent to define custom commands.
//
// For apprt implementers: a command palette doesn't have to make use
// of all the fields here. We try to provide as much information as
// possible to make it easier to implement a command palette in the way
// that makes the most sense for the application.
// ghostty_command_s
// Convert this command to a C struct at comptime.
// Convert this command to a C struct at runtime.
//
// This shares memory with the original command.
//
// The action string is allocated using the provided allocator. You can
// free the slice directly if you need to but we recommend an arena
// for this.
// Implements a comparison function for std.mem.sortUnstable
// and similar functions. The sorting is defined by Ghostty
// to be what we prefer. If a caller wants some other sorting,
// they should do it themselves.
// Defaults in C-compatible form.
// Returns the set of commands associated with this action key by
// default. Not all actions should have commands. As a general guideline,
// an action should have a command only if it is useful and reasonable
// to appear in a command palette.
// This is implemented as a function and switch rather than a
// flat comptime const because we want to ensure we get a compiler
// error when a new binding is added so that the contributor has
// to consider whether that new binding should have commands or not.
// Note: the use of `comptime` prefix on the return values
// ensures that the data returned is all in the binary and
// and not pointing to the stack.
// No commands because they're parameterized and there
// aren't obvious values users would use. It is possible that
// these may have commands in the future if there are very
// common values that users tend to use.
// No commands because I'm not sure they make sense in a command
// palette context.
// No commands for obvious reasons
// All generated commands should have the same action as the
// action passed in.
// This just ensures that defaults is analyzed and works.
//
// --- Original Ghostty Comments End: src/input/command.zig


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
