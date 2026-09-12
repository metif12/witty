module cli

import apprt
import build_meta
import font
import os
import renderer
import v.util.version as vversion

// The version command displays the translated build metadata surface.
pub fn run_version() !int {
	print(version_output(os.is_atty(1) != 0))
	return 0
}

fn version_output(tty bool) string {
	mut header := ''
	if tty && build_meta.commit_hash.len > 0 {
		header += '\x1b]8;;https://github.com/ghostty-org/ghostty/commit/${build_meta.commit_hash}\x1b\\'
	}
	header += 'Ghostty ${build_meta.version_string}\n\n'
	if tty && build_meta.commit_hash.len > 0 {
		header += '\x1b]8;;\x1b\\'
	}
	mut output := ['Version']
	output << '  - version: ${build_meta.version_string}'
	output << '  - channel: ${build_meta.release_channel}'
	output << 'Build Config'
	output << '  - V version     : ${vversion.v_version}'
	output << '  - build mode    : ${build_mode_name()}'
	output << '  - app runtime   : ${runtime_name(apprt.Runtime.default())}'
	output << '  - font engine   : ${font.Backend.default_()}'
	output << '  - renderer      : ${renderer.Backend.default_()}'
	output << '  - libxev        : unavailable'
	output << platform_version_lines()
	return header + output.join('\n') + '\n'
}

fn build_mode_name() string {
	$if debug {
		return 'Debug'
	} $else {
		return 'ReleaseFast'
	}
}

fn runtime_name(runtime apprt.Runtime) string {
	return match runtime {
		.none_ { 'none' }
		.gtk { 'gtk' }
	}
}
