module build_support

import os

// Structured argv is required: build options and paths can contain spaces,
// shell metacharacters, and newlines. No command passes through a shell.
pub fn run_process(root string, args []string) !os.Result {
	if args.len == 0 { return error('empty command') }
	exe := os.find_abs_path_of_executable(args[0])!
	mut process := os.new_process(exe)
	process.set_args(args[1..])
	process.set_work_folder(root)
	process.set_redirect_stdio()
	process.run()
	output := process.stdout_slurp()
	stderr := process.stderr_slurp()
	process.wait()
	code := process.code
	process.close()
	return os.Result{exit_code: code, output: if code == 0 { output } else { output + stderr }}
}

pub fn checked_process(root string, args []string) !string {
	result := run_process(root, args)!
	if result.exit_code != 0 { return error('${args[0]} failed (${result.exit_code}): ${result.output}') }
	return result.output
}
