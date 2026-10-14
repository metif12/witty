module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_reader_exclusive_payload(&char, &u8, usize) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(usize, usize) int
fn C.witty_reader_delimiter_shutdown() int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_valid() int
fn C.witty_reader_delimiter_refs() int
fn C.witty_reader_delimiter_drain(&u8, usize) isize

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

fn sentinel_view(mut reader zigimg.ReadStream, api int, marker int) ![]u8 {
	mut adapter := reader.reader()
	value := if api == 0 {
		adapter.peek_sentinel(u8(marker))!
	} else {
		adapter.take_sentinel(u8(marker))!
	}
	prefix := value.bytes()
	full := value.with_sentinel()
	if prefix.len + 1 != full.len || prefix.data != full.data || full[full.len - 1] != u8(marker) {
		panic('Invalid sentinel view')
	}
	return full
}

fn operate(mut reader zigimg.ReadStream, mut output []u8, api int, marker int) string {
	value := sentinel_view(mut reader, api, marker) or { return err.msg() }
	output = value.clone()
	return 'ok'
}

// kind|api|capacity|start|sentinel|payload|replacement|consumed|seed|prime|delta
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
		fd := C.witty_reader_exclusive_payload(path.str, data.data, usize(data.len))
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
		reader.toss(usize(consumed))
	}
	mut out := '${status}|' + snapshot(mut reader, buffer, output) + '~'
	if borrow {
		mut alias := sentinel_view(mut reader, api, count) or { panic(err) }
		offset := usize(alias.data) - usize(buffer.data)
		if offset + usize(alias.len) > usize(buffer.len) {
			panic('Sentinel view escaped backing storage')
		}
		output = alias.clone()
		out += 'borrow|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}~'
		for i in 0 .. buffer.len {
			if i != int(offset) + alias.len - 1 { buffer[i] ^= 128 }
		}
		out += 'caller|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}~'
		if alias.len > 1 { alias[0] ^= 64 }
		out += 'alias|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}~'
		reader.toss_buffered()
		return out + 'toss|' + snapshot(mut reader, buffer, output) + '|${alias.hex()}|${offset}'
	}
	if replacement > 0 {
		if C.witty_reader_delimiter_replace(0) != 0
			|| C.witty_reader_delimiter_seed(0, usize(seed)) != 0 {
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
	mut drain := isize(-3)
	if replacement > 0 {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_reader_delimiter_drain(bytes.data, usize(bytes.len))
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
