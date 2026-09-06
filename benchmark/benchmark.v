module benchmark

import cli_args
import os
import osc
import simd
import terminal
import unicode

#flag -I @VMODROOT/benchmark

#include "benchmark_shims.h"

fn C.witty_benchmark_wcwidth(cp u32) int

fn C.witty_benchmark_do_not_optimize_u64(value u64)

fn C.witty_benchmark_do_not_optimize_ptr(value voidptr)

// This module translates src/benchmark from Ghostty commit
// 6c0e02d1138d5376e4ac2f5e311b225494514a97. The C API always uses the
// Benchmark.once run mode, so each action below performs its setup, one step,
// and teardown in that order.

pub enum Action {
	codepoint_width
	grapheme_break
	screen_clone
	terminal_parser
	terminal_stream
	is_symbol
	osc_parser
}

enum CodepointWidthMode {
	noop
	wcwidth
	simd
	table
}

struct CodepointWidthOptions {
mut:
	mode CodepointWidthMode
	data ?string
}

enum GraphemeBreakMode {
	noop
	table
}

struct GraphemeBreakOptions {
mut:
	mode GraphemeBreakMode = .table
	data ?string
}

enum IsSymbolMode {
	uucode
	table
}

struct IsSymbolOptions {
mut:
	mode IsSymbolMode
	data ?string
}

enum ScreenCloneMode {
	noop
	clone
	render
}

struct ScreenCloneOptions {
mut:
	mode          ScreenCloneMode = .clone
	terminal_rows u16 = 80
	terminal_cols u16 = 120
	data          ?string
}

struct TerminalStreamOptions {
mut:
	terminal_rows u16 = 80
	terminal_cols u16 = 120
	data          ?string
}

struct DataOptions {
mut:
	data ?string
}

struct DataFile {
mut:
	file    os.File
	present bool
	owned   bool
}

fn data_file(path ?string) !DataFile {
	value := path or { return DataFile{} }
	if value == '-' {
		return DataFile{
			file: os.stdin()
			present: true
		}
	}
	return DataFile{
		file: os.open(value)!
		present: true
		owned: true
	}
}

fn (mut self DataFile) close() {
	if self.present && self.owned {
		self.file.close()
	}
	self.present = false
}

fn (mut self DataFile) read(mut buf []u8) !int {
	if !self.present {
		return 0
	}
	return self.file.read(mut buf) or {
		if self.file.eof() {
			return 0
		}
		return err
	}
}

// parse_argument_string is std.process.ArgIteratorGeneral(.{}), which is what
// Ghostty's benchmark C API uses for its single argument string. Single quotes
// are ordinary characters in this mode; double quotes and backslash parity
// follow the Zig standard-library iterator exactly.
pub fn parse_argument_string(input string) []string {
	mut args := []string{}
	mut index := 0
	for {
		for index < input.len && input[index] in [` `, `\t`, `\r`, `\n`] {
			index++
		}
		if index >= input.len {
			break
		}

		mut token := []u8{}
		mut backslash_count := 0
		mut in_quote := false
		for {
			character := if index < input.len { input[index] } else { u8(0) }
			if character == 0 {
				for _ in 0 .. backslash_count {
					token << `\\`
				}
				args << token.bytestr()
				return args
			}
			if character == `'` {
				for _ in 0 .. backslash_count {
					token << `\\`
				}
				backslash_count = 0
				token << character
				index++
				continue
			}
			if character == `"` {
				quote_is_real := backslash_count % 2 == 0
				for _ in 0 .. backslash_count / 2 {
					token << `\\`
				}
				backslash_count = 0
				if quote_is_real {
					in_quote = !in_quote
				} else {
					token << `"`
				}
				index++
				continue
			}
			if character == `\\` {
				backslash_count++
				index++
				continue
			}
			if character in [` `, `\t`, `\r`, `\n`] {
				for _ in 0 .. backslash_count {
					token << `\\`
				}
				backslash_count = 0
				if in_quote {
					token << character
					index++
					continue
				}
				args << token.bytestr()
				index++
				break
			}
			for _ in 0 .. backslash_count {
				token << `\\`
			}
			backslash_count = 0
			token << character
			index++
		}
	}
	return args
}

pub fn parse_action(name string) ?Action {
	return match name {
		'codepoint-width' { .codepoint_width }
		'grapheme-break' { .grapheme_break }
		'screen-clone' { .screen_clone }
		'terminal-parser' { .terminal_parser }
		'terminal-stream' { .terminal_stream }
		'is-symbol' { .is_symbol }
		'osc-parser' { .osc_parser }
		else { none }
	}
}

// run_cli parses the action options, constructs its implementation, and runs
// it once, matching benchmark.cli.mainAction as invoked by CApi.zig.
pub fn run_cli(action_name string, argument_string string) ! {
	action := parse_action(action_name) or { return error('unknown action=${action_name}') }
	args := parse_argument_string(argument_string)
	match action {
		.codepoint_width { run_codepoint_width(args)! }
		.grapheme_break { run_grapheme_break(args)! }
		.screen_clone { run_screen_clone(args)! }
		.terminal_parser { run_terminal_parser(args)! }
		.terminal_stream { run_terminal_stream(args)! }
		.is_symbol { run_is_symbol(args)! }
		.osc_parser { run_osc_parser(args)! }
	}
}

fn run_codepoint_width(args []string) ! {
	mut opts := CodepointWidthOptions{}
	cli_args.parse(mut opts, args)!
	mut data := data_file(opts.data)!
	defer {
		data.close()
	}
	if opts.mode == .noop || !data.present {
		return
	}

	mut decoder := terminal.UTF8Decoder{}
	mut buf := []u8{len: 4096}
	for {
		n := data.read(mut buf)!
		if n == 0 {
			break
		}
		for c in buf[..n] {
			result := decoder.next(c)
			if !result.consumed {
				return error('invalid UTF-8 stream')
			}
			if cp := result.codepoint {
				value := match opts.mode {
					.wcwidth { C.witty_benchmark_wcwidth(cp) }
					.simd { int(simd.codepoint_width(cp)) }
					.table {
						if cp <= 0xff { 1 } else { int(unicode.get(cp).width) }
					}
					.noop { 0 }
				}
				C.witty_benchmark_do_not_optimize_u64(u64(value))
			}
		}
	}
}

fn run_grapheme_break(args []string) ! {
	mut opts := GraphemeBreakOptions{}
	cli_args.parse(mut opts, args)!
	mut data := data_file(opts.data)!
	defer {
		data.close()
	}
	if !data.present {
		return
	}

	mut decoder := terminal.UTF8Decoder{}
	mut state := unicode.BreakState.default
	mut cp1 := u32(0)
	mut buf := []u8{len: 4096}
	for {
		n := data.read(mut buf)!
		if n == 0 {
			break
		}
		for c in buf[..n] {
			result := decoder.next(c)
			if !result.consumed {
				return error('invalid UTF-8 stream')
			}
			if cp2 := result.codepoint {
				if opts.mode == .noop {
					continue
				}
				is_break := unicode.grapheme_break(cp1, cp2, &state)
				C.witty_benchmark_do_not_optimize_u64(u64(is_break))
				cp1 = cp2
			}
		}
	}
}

fn run_is_symbol(args []string) ! {
	mut opts := IsSymbolOptions{}
	cli_args.parse(mut opts, args)!
	mut data := data_file(opts.data)!
	defer {
		data.close()
	}
	if !data.present {
		return
	}

	mut decoder := terminal.UTF8Decoder{}
	mut buf := []u8{len: 4096}
	for {
		n := data.read(mut buf)!
		if n == 0 {
			break
		}
		for c in buf[..n] {
			result := decoder.next(c)
			if !result.consumed {
				return error('invalid UTF-8 stream')
			}
			if cp := result.codepoint {
				// The translated generated table is the materialized result of
				// Ghostty's pinned uucode is_symbol configuration, so both modes
				// have the same exact property result in a non-uucode V build.
				value := unicode.is_symbol(cp)
				C.witty_benchmark_do_not_optimize_u64(u64(value))
			}
		}
	}
}

fn run_terminal_parser(args []string) ! {
	mut opts := DataOptions{}
	cli_args.parse(mut opts, args)!
	mut data := data_file(opts.data)!
	defer {
		data.close()
	}
	if !data.present {
		return
	}

	mut parser := terminal.VTParser{}
	defer {
		parser.deinit()
	}
	mut buf := []u8{len: 4096}
	for {
		n := data.read(mut buf)!
		if n == 0 {
			break
		}
		for c in buf[..n] {
			actions := parser.next(c)
			C.witty_benchmark_do_not_optimize_ptr(actions.data)
		}
	}
}

fn run_terminal_stream(args []string) ! {
	mut opts := TerminalStreamOptions{}
	cli_args.parse(mut opts, args)!
	mut term := terminal.Terminal.init(terminal.Options{
		rows: opts.terminal_rows
		cols: opts.terminal_cols
	})!
	defer {
		term.deinit()
	}
	term.full_reset()

	mut data := data_file(opts.data)!
	defer {
		data.close()
	}
	if !data.present {
		return
	}

	mut stream := terminal.Stream.init()
	defer {
		stream.deinit()
	}
	mut buf := []u8{len: 4096}
	for {
		n := data.read(mut buf)!
		if n == 0 {
			break
		}
		stream.next_slice(buf[..n])
		for event in stream.events {
			if event.key == .print {
				term.print(event.payload.cp)!
			}
		}
		stream.clear_events()
	}
}

fn run_screen_clone(args []string) ! {
	mut opts := ScreenCloneOptions{}
	cli_args.parse(mut opts, args)!
	mut term := terminal.Terminal.init(terminal.Options{
		rows: opts.terminal_rows
		cols: opts.terminal_cols
	})!
	defer {
		term.deinit()
	}
	term.full_reset()

	mut setup_stream := term.vt_stream()
	setup_stream.next_slice('\x1b[48;2;20;40;60m')!
	for _ in 0 .. int(term.rows) - 1 {
		setup_stream.next_slice('hello\r\n')!
	}
	setup_stream.next_slice('hello')!
	setup_stream.deinit()

	mut data := data_file(opts.data)!
	defer {
		data.close()
	}
	if data.present {
		mut stream := term.vt_stream()
		defer {
			stream.deinit()
		}
		mut buf := []u8{len: 4096}
		for {
			n := data.read(mut buf)!
			if n == 0 {
				break
			}
			stream.next_slice(buf[..n].bytestr())!
		}
	}

	match opts.mode {
		.noop {
			for _ in 0 .. 1000 {
				screen := *term.screens.active
				C.witty_benchmark_do_not_optimize_ptr(&screen)
			}
		}
		.clone {
			for _ in 0 .. 1000 {
				copy := term.screens.active.clone(terminal.Point.new(.viewport, terminal.Coordinate{}), ?terminal.Point(none))!
				C.witty_benchmark_do_not_optimize_ptr(&copy)
			}
		}
		.render {
			mut state := terminal.RenderState.empty()
			defer {
				state.deinit()
			}
			state.update(mut term)
			for _ in 0 .. 1000 {
				state.screen = .alternate
				state.update(mut term)
				C.witty_benchmark_do_not_optimize_ptr(&state)
			}
		}
	}
}

fn read_exact(mut data DataFile, mut buf []u8) !bool {
	mut offset := 0
	for offset < buf.len {
		n := data.read(mut buf[offset..])!
		if n == 0 {
			if offset == 0 {
				return false
			}
			return error('truncated data')
		}
		offset += n
	}
	return true
}

fn run_osc_parser(args []string) ! {
	mut opts := DataOptions{}
	cli_args.parse(mut opts, args)!
	mut data := data_file(opts.data)!
	defer {
		data.close()
	}
	if !data.present {
		return
	}

	mut parser := osc.Parser.init(unsafe { nil })
	defer {
		parser.deinit()
	}
	mut length_bytes := []u8{len: int(sizeof(usize))}
	mut osc_buf := []u8{len: 4096}
	for {
		if !read_exact(mut data, mut length_bytes)! {
			return
		}
		mut length := usize(0)
		for index, value in length_bytes {
			length |= usize(value) << u32(index * 8)
		}
		if length > usize(osc_buf.len) {
			return error('OSC payload exceeds buffer')
		}
		if !read_exact(mut data, mut osc_buf[..int(length)])! {
			return error('truncated OSC payload')
		}
		for value in osc_buf[..int(length)] {
			parser.next(value)
		}
		command := parser.end(0x07)
		if value := command {
			C.witty_benchmark_do_not_optimize_ptr(&value)
		}
		parser.reset()
	}
}
