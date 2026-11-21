module main

import zigimg

type Width = u16

struct Args {
	value     int
	text      []u8
	width     Width
	precision ?uint
}

type ArgsAlias = Args

struct Empty {}

struct PrintError {}

pub fn (value PrintError) msg() string { return 'PrintError' }

pub fn (value PrintError) code() int { return 47 }

pub fn (value PrintError) format(mut writer zigimg.WriteStream) ! {
	writer.write_all('custom-error'.bytes())!
	return error_with_code('FormatterStopped', 47)
}

struct CustomArgs {
	value PrintError
}

struct Mixed {
	bytes    [2]u8
	value    IError
	optional ?int
	nested   [][][][]int
}

fn run() ! {
	mut buffer := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	writer.print('a{{b}}{[value]d:0>[width]}:{[text]s:.<8}:{[value]d:.[precision]}!',
		ArgsAlias(Args{-17, 'hello'.bytes(), Width(7), ?uint(3)}))!
	assert writer.buffered().bytestr() == 'a{b}0000-17:hello...:-17!'
	writer = zigimg.WriteStream.init_memory(mut buffer)
	writer.print('{any}|{}|{?d}|{any}', Mixed{[u8(1), 255]!, PrintError{}, ?int(-7), [[[[1]]]]})!
	assert writer.buffered().bytestr() == '{ 1, 255 }|error.PrintError|-7|{ { { { ... } } } }'
	writer = zigimg.WriteStream.init_memory(mut buffer)
	mut failed := false
	writer.print('before{f}after', CustomArgs{}) or {
		failed = true
		assert err.msg() == 'FormatterStopped' && err.code() == 47
		assert writer.buffered().bytestr() == 'beforecustom-error'
	}
	assert failed
	for capacity in 0 .. 9 {
		mut short := []u8{len: capacity, init: 0xa5}
		mut limited := zigimg.WriteStream.init_memory(mut short)
		mut status := 'ok'
		limited.print('a{{b}}c{{d}}', Empty{}) or { status = err.msg() }
		assert status == if capacity < 8 { 'WriteFailed' } else { 'ok' }
		assert limited.buffered().bytestr() == 'a{b}c{d}'[..capacity]
	}
}

fn main() {
	run() or { panic(err) }
}
