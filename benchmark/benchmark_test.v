module benchmark

import os

fn test_parse_argument_string_matches_zig_general_iterator() {
	assert parse_argument_string('".\\..\\zig-cache\\build" "bin\\zig.exe" ".\\.." ".\\..\\zig-cache" "--help"') == [
		'.\\..\\zig-cache\\build',
		'bin\\zig.exe',
		'.\\..',
		'.\\..\\zig-cache',
		'--help',
	]
	assert parse_argument_string(' \'foo\' "bar"') == ["'foo'", 'bar']
	assert parse_argument_string('"" q ""') == ['', 'q', '']
	assert parse_argument_string('"u\\" v"') == ['u" v']
}

fn test_parse_action_covers_every_pinned_action() {
	assert (parse_action('codepoint-width') or { panic('missing action') }) == .codepoint_width
	assert (parse_action('grapheme-break') or { panic('missing action') }) == .grapheme_break
	assert (parse_action('screen-clone') or { panic('missing action') }) == .screen_clone
	assert (parse_action('terminal-parser') or { panic('missing action') }) == .terminal_parser
	assert (parse_action('terminal-stream') or { panic('missing action') }) == .terminal_stream
	assert (parse_action('is-symbol') or { panic('missing action') }) == .is_symbol
	assert (parse_action('osc-parser') or { panic('missing action') }) == .osc_parser
	assert parse_action('unknown') == none
}

fn test_no_data_benchmarks_run_once() {
	run_cli('codepoint-width', '')!
	run_cli('grapheme-break', '')!
	run_cli('terminal-parser', '')!
	run_cli('terminal-stream', '')!
	run_cli('is-symbol', '')!
	run_cli('osc-parser', '')!
}

fn test_data_benchmarks_process_input() {
	path := os.join_path(os.temp_dir(), 'witty-benchmark-${os.getpid()}')
	os.write_file(path, 'hello 👩‍👩')!
	defer {
		os.rm(path) or {}
	}
	quoted := '"${path}"'
	run_cli('codepoint-width', '--mode=table --data=${quoted}')!
	run_cli('codepoint-width', '--mode=simd --data=${quoted}')!
	run_cli('grapheme-break', '--data=${quoted}')!
	run_cli('terminal-parser', '--data=${quoted}')!
	run_cli('terminal-stream', '--terminal-rows=5 --terminal-cols=10 --data=${quoted}')!
	run_cli('is-symbol', '--mode=table --data=${quoted}')!
	run_cli('screen-clone', '--mode=noop --terminal-rows=2 --terminal-cols=3 --data=${quoted}')!
	run_cli('screen-clone', '--mode=clone --terminal-rows=2 --terminal-cols=3')!
	run_cli('screen-clone', '--mode=render --terminal-rows=2 --terminal-cols=3')!
}

fn test_osc_parser_benchmark_processes_length_prefixed_input() {
	path := os.join_path(os.temp_dir(), 'witty-benchmark-osc-${os.getpid()}')
	mut data := []u8{len: int(sizeof(usize)) + 3}
	data[0] = 3
	data[int(sizeof(usize))] = `0`
	data[int(sizeof(usize)) + 1] = `;`
	data[int(sizeof(usize)) + 2] = `x`
	os.write_bytes(path, data)!
	defer {
		os.rm(path) or {}
	}
	run_cli('osc-parser', '--data="${path}"')!
}

fn test_invalid_benchmark_input_fails() {
	mut failed := false
	run_cli('unknown', '') or {
		failed = true
	}
	assert failed

	failed = false
	run_cli('codepoint-width', '--mode=unknown') or {
		failed = true
	}
	assert failed
}
