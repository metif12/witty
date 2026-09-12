module cli

const action_help_requested_message = 'ActionHelpRequested'
const action_help_data = $embed_file('action_help.txt').to_string()

// request_action_help is the translated Action.help_error path shared by the
// option declarations for Ghostty CLI actions.
fn request_action_help(arg string) ! {
	if arg == '--help' || arg == '-h' {
		return error(action_help_requested_message)
	}
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
