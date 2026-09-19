module cli

import cli_args

const action_help_requested_message = 'ActionHelpRequested'
const action_help_data = $embed_file('cli_action_help.txt').to_string()

pub fn generated_action_help_data() string {
	return action_help_data
}

// action_options_help is the common body of each translated Options.help
// method. The source returns Action.help_error from every action module.
fn action_options_help() ! {
	return error(action_help_requested_message)
}

// parse_action_options is the common cli.args.parse path used by Ghostty's
// action option structs. Help is checked at the same point in argument order.
fn parse_action_options[T](args []string) !T {
	mut opts := T{}
	cli_args.parse(mut opts, args)!
	return opts
}

pub fn is_action_help_requested(err IError) bool {
	return err.msg() == action_help_requested_message
}

// action_help_output returns the generated help string for one CLI action.
// helpgen.zig emits a trailing newline in each multiline literal and
// Action.run appends one more before writing it.
pub fn action_help_output(name string) ?string {
	marker := '@@${name}\n'
	marker_index := action_help_data.index(marker) or { return none }
	start := marker_index + marker.len
	tail := action_help_data[start..]
	end := tail.index('\n@@') or { tail.len }
	return tail[..end].trim_string_right('\n') + '\n\n'
}
