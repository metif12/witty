module termio

import configpkg
import internal_os
import os

// Shell types we support
pub enum Shell {
	bash
	elvish
	fish
	nushell
	zsh
}

// The result of setting up a shell integration.
pub struct ShellIntegrationResult {
pub:
	// The successfully-integrated shell.
	shell Shell
	// The command to use to start the shell with the integration.
	// In most cases this is identical to the command given but for
	// bash in particular it may be different.
	command configpkg.Command
}

// Set up the command execution environment for automatic
// integrated shell integration and return a ShellIntegrationResult
// describing the integration. If integration fails
// (shell type couldn't be detected, etc.), this will return none.
pub fn setup_shell_integration(resource_dir string, command configpkg.Command, mut env map[string]string, force_shell ?Shell) ?ShellIntegrationResult {
	shell := force_shell or { detect_shell(command) or { return none } }

	new_command := match shell {
		.bash {
			setup_bash(command, resource_dir, mut env) or { return none }
		}
		.nushell {
			setup_nushell(command, resource_dir, mut env) or { return none }
		}
		.zsh {
			setup_zsh(command, resource_dir, mut env) or { return none }
		}
		.elvish, .fish {
			if !setup_xdg_data_dirs(resource_dir, mut env) {
				return none
			}
			command.clone()
		}
	}

	return ShellIntegrationResult{
		shell: shell
		command: new_command
	}
}

// detect_shell attempts to detect the shell from the command.
fn detect_shell(command configpkg.Command) ?Shell {
	mut iter := command.arg_iterator()

	arg0 := iter.next() or { return none }
	exe := os.base(arg0)

	if exe == 'bash' {
		// Apple distributes their own patched version of Bash 3.2
		// on macOS that disables the ENV-based POSIX startup path.
		// This means we're unable to perform our automatic shell
		// integration sequence in this specific environment.
		//
		// If we're running "/bin/bash" on Darwin, we can assume
		// we're using Apple's Bash because /bin is non-writable
		// on modern macOS due to System Integrity Protection.
		$if macos {
			if arg0 == '/bin/bash' {
				return none
			}
		}
		return .bash
	}

	if exe == 'elvish' {
		return .elvish
	}
	if exe == 'fish' {
		return .fish
	}
	if exe == 'nu' {
		return .nushell
	}
	if exe == 'zsh' {
		return .zsh
	}

	return none
}

// Set up the shell integration features environment variable.
pub fn setup_features(mut env map[string]string, features configpkg.ShellIntegrationFeatures) {
	// Build the features string with fields in sorted order.
	// The fields are sorted alphabetically at compile time for deterministic output.
	mut parts := []string{}

	if features.cursor {
		parts << 'cursor'
	}
	if features.path {
		parts << 'path'
	}
	if features.ssh_env {
		parts << 'ssh-env'
	}
	if features.ssh_terminfo {
		parts << 'ssh-terminfo'
	}
	if features.sudo {
		parts << 'sudo'
	}
	if features.title {
		parts << 'title'
	}

	if parts.len > 0 {
		env['GHOSTTY_SHELL_FEATURES'] = parts.join(',')
	}
}

// Setup the bash automatic shell integration. This works by
// starting bash in POSIX mode and using the ENV environment
// variable to load our bash integration script. This prevents
// bash from loading its normal startup files, which becomes
// our script's responsibility (along with disabling POSIX
// mode).
//
// This returns a new shell command string that
// enables the integration or none if integration failed.
fn setup_bash(command configpkg.Command, resource_dir string, mut env map[string]string) ?configpkg.Command {
	mut cmd := internal_os.ShellCommandBuilder.init()

	// Iterator that yields each argument in the original command line.
	mut iter := command.arg_iterator()

	// Start accumulating arguments with the executable and initial flags.
	exe := iter.next() or { return none }
	cmd.append_arg(exe)
	cmd.append_arg('--posix')

	// Stores the list of intercepted command line flags that will be passed
	// to our shell integration script: --norc --noprofile
	// We always include at least "1" so the script can differentiate between
	// being manually sourced or automatically injected (from here).
	mut inject_parts := []string{}
	inject_parts << '1'

	// Walk through the rest of the given arguments. If we see an option that
	// would require complex or unsupported integration behavior, we bail out
	// and skip loading our shell integration. Users can still manually source
	// the shell integration script.
	//
	// Unsupported options:
	//  -c          -c is always non-interactive
	//  --posix     POSIX mode (a la /bin/sh)
	mut rcfile := ?string(none)
	for {
		arg := iter.next() or { break }
		if arg == '--posix' {
			return none
		} else if arg == '--norc' {
			inject_parts << '--norc'
		} else if arg == '--noprofile' {
			inject_parts << '--noprofile'
		} else if arg == '--rcfile' || arg == '--init-file' {
			rcfile = iter.next()
		} else if arg.len > 1 && arg[0] == `-` && arg[1] != `-` {
			// '-c command' is always non-interactive
			if arg.contains('c') {
				return none
			}
			cmd.append_arg(arg)
		} else if arg == '-' || arg == '--' {
			// All remaining arguments should be passed directly to the shell
			// command. We shouldn't perform any further option processing.
			cmd.append_arg(arg)
			for {
				remaining_arg := iter.next() or { break }
				cmd.append_arg(remaining_arg)
			}
			break
		} else {
			cmd.append_arg(arg)
		}
	}

	// Preserve an existing ENV value. We're about to overwrite it.
	if v := env['ENV'] {
		if v.len > 0 {
			env['GHOSTTY_BASH_ENV'] = v
		}
	}

	// Set our new ENV to point to our integration script.
	script_path := '${resource_dir}/shell-integration/bash/ghostty.bash'
	if os.exists(script_path) {
		env['ENV'] = script_path
	} else {
		env.delete('GHOSTTY_BASH_ENV')
		return none
	}

	env['GHOSTTY_BASH_INJECT'] = inject_parts.join(' ')
	if rc := rcfile {
		env['GHOSTTY_BASH_RCFILE'] = rc
	}

	// In POSIX mode, HISTFILE defaults to ~/.sh_history, so unless we're
	// staying in POSIX mode (--posix), change it back to ~/.bash_history.
	if 'HISTFILE' !in env {
		if h := internal_os.home() {
			env['HISTFILE'] = '${h}/.bash_history'
			env['GHOSTTY_BASH_UNEXPORT_HISTFILE'] = '1'
		}
	}

	// Return a copy of our modified command line to use as the shell command.
	return configpkg.ShellCmd{ shell: cmd.to_owned_slice() }
}

// Setup automatic shell integration for shells that include
// their modules from paths in `XDG_DATA_DIRS` env variable.
//
// The shell-integration path is prepended to `XDG_DATA_DIRS`.
// It is also saved in the `GHOSTTY_SHELL_INTEGRATION_XDG_DIR` variable
// so that the shell can refer to it and safely remove this directory
// from `XDG_DATA_DIRS` when integration is complete.
fn setup_xdg_data_dirs(resource_dir string, mut env map[string]string) bool {
	// Get our path to the shell integration directory.
	integ_path := '${resource_dir}/shell-integration'
	if !os.is_dir(integ_path) {
		return false
	}

	// Set an env var so we can remove this from XDG_DATA_DIRS later.
	// This happens in the shell integration config itself. We do this
	// so that our modifications don't interfere with other commands.
	env['GHOSTTY_SHELL_INTEGRATION_XDG_DIR'] = integ_path

	// If no XDG_DATA_DIRS set use the default value as specified.
	// This ensures that the default directories aren't lost by setting
	// our desired integration dir directly. See #2711.
	// <https://specifications.freedesktop.org/basedir-spec/0.6/#variables>
	existing := if v := env['XDG_DATA_DIRS'] {
		v
	} else {
		'/usr/local/share:/usr/share'
	}
	env['XDG_DATA_DIRS'] = internal_os.prepend_env(existing, integ_path)

	return true
}

// Set up automatic Nushell shell integration. This works by adding our
// shell resource directory to the `XDG_DATA_DIRS` environment variable,
// which Nushell will use to load `nushell/vendor/autoload/ghostty.nu`.
//
// We then add `--execute 'use ghostty ...'` to the nu command line to
// automatically enable our shell features.
fn setup_nushell(command configpkg.Command, resource_dir string, mut env map[string]string) ?configpkg.Command {
	// Add our XDG_DATA_DIRS entry (for nushell/vendor/autoload/). This
	// makes our 'ghostty' module automatically available, even if any
	// of the later checks abort the rest of our automatic integration.
	if !setup_xdg_data_dirs(resource_dir, mut env) {
		return none
	}

	mut cmd := internal_os.ShellCommandBuilder.init()

	// Iterator that yields each argument in the original command line.
	mut iter := command.arg_iterator()

	// Start accumulating arguments with the executable and initial flags.
	exe := iter.next() or { return none }
	cmd.append_arg(exe)

	// Tell nu to immediately "use" all of the exported functions in our
	// 'ghostty' module.
	//
	// We can consider making this more specific based on the set of
	// enabled shell features (e.g. `use ghostty sudo`). At the moment,
	// shell features are all runtime-guarded in the nushell script.
	cmd.append_arg("--execute 'use ghostty *'")

	// Walk through the rest of the given arguments. If we see an option that
	// would require complex or unsupported integration behavior, we bail out
	// and skip loading our shell integration. Users can still manually source
	// the shell integration module.
	//
	// Unsupported options:
	//  -c / --command      -c is always non-interactive
	//  --lsp               --lsp starts the language server
	for {
		arg := iter.next() or { break }
		if arg == '--command' || arg == '--lsp' {
			return none
		} else if arg.len > 1 && arg[0] == `-` && arg[1] != `-` {
			if arg.contains('c') {
				return none
			}
			cmd.append_arg(arg)
		} else if arg == '-' || arg == '--' {
			// All remaining arguments should be passed directly to the shell
			// command. We shouldn't perform any further option processing.
			cmd.append_arg(arg)
			for {
				remaining_arg := iter.next() or { break }
				cmd.append_arg(remaining_arg)
			}
			break
		} else {
			cmd.append_arg(arg)
		}
	}

	// Return a copy of our modified command line to use as the shell command.
	return configpkg.ShellCmd{ shell: cmd.to_owned_slice() }
}

// Setup the zsh automatic shell integration. This works by setting
// ZDOTDIR to our resources dir so that zsh will load our config. This
// config then loads the true user config.
fn setup_zsh(command configpkg.Command, resource_dir string, mut env map[string]string) ?configpkg.Command {
	// Preserve an existing ZDOTDIR value. We're about to overwrite it.
	if old := env['ZDOTDIR'] {
		if old.len > 0 {
			env['GHOSTTY_ZSH_ZDOTDIR'] = old
		}
	}

	// Set our new ZDOTDIR to point to our shell resource directory.
	integ_path := '${resource_dir}/shell-integration/zsh'
	if !os.is_dir(integ_path) {
		return none
	}
	env['ZDOTDIR'] = integ_path

	return command.clone()
}
