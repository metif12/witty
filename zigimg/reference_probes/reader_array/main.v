module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_reader_exclusive_payload(&char, &u8, uint) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(uint, uint) int
fn C.witty_reader_delimiter_shutdown() int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_valid() int
fn C.witty_reader_delimiter_refs() int
fn C.witty_reader_delimiter_drain(&u8, uint) int

__global (
	observed_path   string
	observed_status string
	observed_reader = &zigimg.ReadStream(unsafe { nil })
	observed_buffer []u8
	observed_output []u8
	observed_file   bool
)

// This observer omits get_pos, which may itself be the failed observation.
fn state(mut reader zigimg.ReadStream, buffer []u8, output []u8) string {
	mut size := ''
	length := reader.get_end_pos() or {
		size = err.msg()
		u64(0)
	}
	if size == '' { size = length.str() }
	valid := if observed_file { C.witty_reader_delimiter_valid() } else { 0 }
	refs := if observed_file { C.witty_reader_delimiter_refs() } else { 0 }
	return '${size}:${valid}:${refs}|${buffer.hex()}|${output.hex()}|${reader.buffered().hex()}'
}

fn snapshot(mut reader zigimg.ReadStream, buffer []u8, output []u8) string {
	return '${reader.get_pos()}:' + state(mut reader, buffer, output)
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' + state(mut observed_reader, observed_buffer, observed_output)
	os.write_file(observed_path, retained) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_reader_delimiter_cleanup()
}

type ByteAlias = u8
type Bytes1 = [1]u8
type Bytes2 = [2]u8
type Bytes4 = [4]u8
type Bytes8 = [8]u8
type Bytes16 = [16]u8
type Bytes32 = [32]u8
type AliasedBytes = [2]ByteAlias

fn view_0(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[[1]u8]()! } else { adapter.take_array[[1]u8]()! }
	return unsafe { (&u8(value.value)).vbytes(1) }
}

fn view_1(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[[2]u8]()! } else { adapter.take_array[[2]u8]()! }
	return unsafe { (&u8(value.value)).vbytes(2) }
}

fn view_2(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[[4]u8]()! } else { adapter.take_array[[4]u8]()! }
	return unsafe { (&u8(value.value)).vbytes(4) }
}

fn view_3(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[[8]u8]()! } else { adapter.take_array[[8]u8]()! }
	return unsafe { (&u8(value.value)).vbytes(8) }
}

fn view_4(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[[16]u8]()! } else { adapter.take_array[[16]u8]()! }
	return unsafe { (&u8(value.value)).vbytes(16) }
}

fn view_5(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[[32]u8]()! } else { adapter.take_array[[32]u8]()! }
	return unsafe { (&u8(value.value)).vbytes(32) }
}

fn view_6(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[Bytes1]()! } else { adapter.take_array[Bytes1]()! }
	return unsafe { (&u8(value.value)).vbytes(1) }
}

fn view_7(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[Bytes2]()! } else { adapter.take_array[Bytes2]()! }
	return unsafe { (&u8(value.value)).vbytes(2) }
}

fn view_8(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[Bytes4]()! } else { adapter.take_array[Bytes4]()! }
	return unsafe { (&u8(value.value)).vbytes(4) }
}

fn view_9(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[Bytes8]()! } else { adapter.take_array[Bytes8]()! }
	return unsafe { (&u8(value.value)).vbytes(8) }
}

fn view_10(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[Bytes16]()! } else { adapter.take_array[Bytes16]()! }
	return unsafe { (&u8(value.value)).vbytes(16) }
}

fn view_11(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 { adapter.peek_array[Bytes32]()! } else { adapter.take_array[Bytes32]()! }
	return unsafe { (&u8(value.value)).vbytes(32) }
}

fn view_12(mut reader zigimg.ReadStream, api int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 {
		adapter.peek_array[AliasedBytes]()!
	} else {
		adapter.take_array[AliasedBytes]()!
	}
	return unsafe { (&u8(value.value)).vbytes(2) }
}

fn array_view(mut reader zigimg.ReadStream, api int, tag int) ![]u8 {
	return match tag {
		0 { view_0(mut reader, api)! }
		1 { view_1(mut reader, api)! }
		2 { view_2(mut reader, api)! }
		3 { view_3(mut reader, api)! }
		4 { view_4(mut reader, api)! }
		5 { view_5(mut reader, api)! }
		6 { view_6(mut reader, api)! }
		7 { view_7(mut reader, api)! }
		8 { view_8(mut reader, api)! }
		9 { view_9(mut reader, api)! }
		10 { view_10(mut reader, api)! }
		11 { view_11(mut reader, api)! }
		12 { view_12(mut reader, api)! }
		else { panic('Invalid array type') }
	}
}

fn operate(mut reader zigimg.ReadStream, mut output []u8, api int, tag int) string {
	value := array_view(mut reader, api, tag) or { return err.msg() }
	output = value.clone()
	return 'ok'
}

// kind|api|capacity|start|array-type|payload|replacement|consumed|seed|prime|delta
fn record(line string, path string, borrow bool) string {
	f := line.split('|')
	kind, api, capacity, start, count := f[0].int(), f[1].int(), f[2].int(), f[3].int(), f[4].int()
	data := hex.decode(f[5]) or { panic(err) }
	replacement, consumed, seed, prime, delta := f[6].int(), f[7].int(), f[8].int(), f[9].int(), f[10].i64()
	mut buffer := []u8{len: capacity, init: 165}
	mut reader := zigimg.ReadStream.init_memory(data)
	if kind == 0 {
		buffer = unsafe { data }
	} else {
		fd := C.witty_reader_exclusive_payload(path.str, data.data, uint(data.len))
		if fd < 0 { panic('Reader setup failed') }
		reader = if kind == 1 { zigimg.ReadStream.init_file(os.File{ fd: fd }, mut buffer) } else { zigimg.ReadStream.init_file_streaming(os.File{
				fd: fd
			}, mut buffer) }
	}
	defer {
		if kind > 0 && C.witty_reader_delimiter_cleanup() != 0 { panic('Reader cleanup failed') }
	}
	mut output := []u8{}
	observed_reader = &reader
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	observed_file = kind > 0
	observed_status = 'ok'
	mut status := 'ok'
	if start > 0 { reader.seek_to(u64(start)) or { status = err.msg() } }
	if replacement > 0 {
		reader.peek(capacity) or { panic(err) }
		reader.toss(uint(consumed))
	}
	mut out := '${status}|' + snapshot(mut reader, buffer, output) + '~'
	if borrow {
		mut alias := array_view(mut reader, api, count) or { panic(err) }
		offset := uint(alias.data) - uint(buffer.data)
		if offset + uint(alias.len) > uint(buffer.len) {
			panic('Array pointer escaped backing storage')
		}
		output = alias.clone()
		out += 'borrow|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}~'
		for i in 0 .. buffer.len {
			buffer[i] ^= 128
		}
		out += 'caller|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}~'
		if alias.len > 0 { alias[0] ^= 64 }
		out += 'alias|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}~'
		reader.toss_buffered()
		return out + 'toss|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}'
	}
	if replacement > 0 {
		if C.witty_reader_delimiter_replace(0) != 0
			|| C.witty_reader_delimiter_seed(0, uint(seed)) != 0 {
			panic('Reader replacement failed')
		}
		if replacement == 2 && C.witty_reader_delimiter_shutdown() != 0 {
			panic('Reader shutdown failed')
		}
	}
	status = 'skip'
	if prime > 0 {
		status = 'ok'
		reader.peek(capacity) or { status = err.msg() }
		if prime == 2 { reader.toss_buffered() }
	}
	out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
	for attempt in 0 .. 3 {
		observed_status = 'calling'
		status = operate(mut reader, mut output, api, count)
		observed_status = status
		observed_output = unsafe { output }
		out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
		if attempt == 0 {
			status = 'ok'
			reader.seek_by(delta) or { status = err.msg() }
			out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
		}
	}
	mut wire := []u8{}
	mut drain := int(-3)
	if replacement > 0 {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_reader_delimiter_drain(bytes.data, uint(bytes.len))
			if drain <= 0 { break
			 }
			wire << bytes[..int(drain)]
		}
	}
	return out + '${drain}:${wire.hex()}'
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := record(os.args[3], os.args[2] + '.owned', false)
		observed_path = ''
		println(result)
		return
	}
	borrow := os.args[1] == '--borrow'
	path := os.args[if borrow { 2 } else { 1 }]
	for i, line in (os.read_lines(path) or { panic(err) }) {
		println(record(line, path + '.${i}.owned', borrow))
	}
}
