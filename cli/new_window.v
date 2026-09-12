module cli

pub struct NewWindowOptions {
pub mut:
	class     ?string
	arguments ?[]string
}

pub struct NewWindowResult {
pub:
	code   int
	errors string
}

// parse_new_window_options mirrors the action's manual -e hook. Unknown
// configuration flags are deliberately ignored because upstream enables CLI
// diagnostics and only reports diagnostics for fields owned by this action.
fn parse_new_window_options(args []string) !NewWindowOptions {
	mut opts := NewWindowOptions{}
	mut index := 0
	for index < args.len {
		arg := args[index]
		if arg == '-e' {
			opts.arguments = args[index + 1..].clone()
			return opts
		}
		request_action_help(arg)!
		if arg == '--class' {
			return error('value required for --class')
		}
		if arg.starts_with('--class=') {
			value := arg.all_after('=')
			opts.class = if value.len == 0 { none } else { value }
		}
		index++
	}
	return opts
}

pub fn new_window_result(args []string) !NewWindowResult {
	opts := parse_new_window_options(args) or {
		if is_action_help_requested(err) {
			return err
		}
		return NewWindowResult{
			code: 1
			errors: 'Error parsing args: ${err}\n'
		}
	}
	if arguments := opts.arguments {
		if arguments.len == 0 {
			return NewWindowResult{
				code: 1
				errors: 'The -e flag was specified on the command line, but no other arguments were found.\n'
			}
		}
	}

	performed := perform_new_window_ipc(opts) or {
		if err.msg() == 'IPCFailed' {
			// The platform IPC layer prints its more specific error itself.
			return NewWindowResult{ code: 1 }
		}
		return NewWindowResult{
			code: 1
			errors: 'Sending the IPC failed: ${err}'
		}
	}
	if performed {
		return NewWindowResult{}
	}
	return NewWindowResult{
		code: 1
		errors: '+new-window is not supported on this platform.\n'
	}
}

pub fn run_new_window(args []string) !int {
	result := new_window_result(args)!
	eprint(result.errors)
	return result.code
}
