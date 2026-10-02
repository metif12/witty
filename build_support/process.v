module build_support

import os

// Structured argv is required: build options and paths can contain spaces,
// shell metacharacters, and newlines. No command passes through a shell.
pub fn run_process(root string, args []string) !os.Result {
	return run_process_env(root, args, map[string]string{}, false)
}

pub fn run_process_env(root string, args []string, environment map[string]string, clear bool) !os.Result {
	if args.len == 0 { return error('empty command') }
	exe := os.find_abs_path_of_executable(args[0])!
	mut process := os.new_process(exe)
	process.set_args(args[1..])
	process.set_work_folder(root)
	if clear {
		process.set_environment(environment)
	} else if environment.len > 0 {
		mut merged := os.environ()
		for name, value in environment {
			merged[name] = value
		}
		process.set_environment(merged)
	}
	process.set_redirect_stdio()
	process.run()
	// Drain stderr alongside stdout. Compiler diagnostics can fill the pipe
	// before the child exits, so serial slurping can deadlock the build.
	errors := spawn process.stderr_slurp()
	output := process.stdout_slurp()
	stderr := errors.wait()
	process.wait()
	code := process.code
	process.close()
	return os.Result{
		exit_code: code
		output:    if code == 0 { output } else { output + stderr }
	}
}

pub fn checked_process_env(root string, args []string, environment map[string]string, clear bool) !string {
	result := run_process_env(root, args, environment, clear)!
	if result.exit_code != 0 {
		return error('${args[0]} failed (${result.exit_code}): ${result.output}')
	}
	return result.output
}

pub fn checked_process(root string, args []string) !string {
	result := run_process(root, args)!
	if result.exit_code != 0 {
		return error('${args[0]} failed (${result.exit_code}): ${result.output}')
	}
	return result.output
}

// Run artifacts inherit the terminal's standard streams. Captured compiler
// and generator subprocesses use run_process instead.
pub fn run_foreground(root string, args []string, environment map[string]string) ! {
	if args.len == 0 { return error('empty command') }
	executable := os.find_abs_path_of_executable(args[0])!
	mut process := os.new_process(executable)
	process.set_args(args[1..])
	process.set_work_folder(root)
	if environment.len > 0 {
		mut merged := os.environ()
		for name, value in environment { merged[name] = value }
		process.set_environment(merged)
	}
	process.run()
	process.wait()
	code := process.code
	process.close()
	if code != 0 { return error('${args[0]} failed (${code})') }
}
