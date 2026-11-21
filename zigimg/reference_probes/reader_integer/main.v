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
	return '${size}:${valid}:${refs}|${buffer.hex()}|${output.bytestr()}|${reader.buffered().hex()}'
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

type AliasU8 = u8
type AliasU16 = u16
type AliasU32 = u32
type AliasU64 = u64
type AliasI8 = i8
type AliasI16 = i16
type AliasInt = int
type AliasI64 = i64
type AliasUsize = uint
type AliasIsize = int
type AliasBig = zigimg.BigEndian
type AliasLittle = zigimg.LittleEndian

fn number_read[T, E](mut reader zigimg.ReadStream, mut output []u8, op int, order E, n uint) string {
	mut adapter := reader.reader()
	mut value := T(0)
	if op == 0 {
		value = adapter.peek_int[T, E](E{}) or { return err.msg() }
	} else {
		value = adapter.take_var_int[T, E](E{}, n) or { return err.msg() }
	}
	mut word := u64(value)
	if sizeof(T) < 8 { word &= (u64(1) << (sizeof(T) * 8)) - 1 }
	output = '${value}:${word}'.bytes()
	return 'ok'
}

fn endian_read[T](mut reader zigimg.ReadStream, mut output []u8, op int, order int, n uint) string {
	return match order {
		0 {
			number_read[T, zigimg.BigEndian](mut reader, mut output, op, zigimg.BigEndian{}, n)
		}
		1 {
			number_read[T, zigimg.LittleEndian](mut reader, mut output, op, zigimg.LittleEndian{},
				n)
		}
		2 {
			number_read[T, AliasBig](mut reader, mut output, op, AliasBig{}, n)
		}
		else {
			number_read[T, AliasLittle](mut reader, mut output, op, AliasLittle{}, n)
		}
	}
}

fn operate(mut reader zigimg.ReadStream, mut output []u8, op int, tag int, order int, n uint) string {
	return match tag {
		0 { endian_read[u8](mut reader, mut output, op, order, n) }
		1 { endian_read[u16](mut reader, mut output, op, order, n) }
		2 { endian_read[u32](mut reader, mut output, op, order, n) }
		3 { endian_read[u64](mut reader, mut output, op, order, n) }
		4 { endian_read[i8](mut reader, mut output, op, order, n) }
		5 { endian_read[i16](mut reader, mut output, op, order, n) }
		6 { endian_read[int](mut reader, mut output, op, order, n) }
		7 { endian_read[i64](mut reader, mut output, op, order, n) }
		8 { endian_read[uint](mut reader, mut output, op, order, n) }
		9 { endian_read[int](mut reader, mut output, op, order, n) }
		10 { endian_read[AliasU8](mut reader, mut output, op, order, n) }
		11 { endian_read[AliasU16](mut reader, mut output, op, order, n) }
		12 { endian_read[AliasU32](mut reader, mut output, op, order, n) }
		13 { endian_read[AliasU64](mut reader, mut output, op, order, n) }
		14 { endian_read[AliasI8](mut reader, mut output, op, order, n) }
		15 { endian_read[AliasI16](mut reader, mut output, op, order, n) }
		16 { endian_read[AliasInt](mut reader, mut output, op, order, n) }
		17 { endian_read[AliasI64](mut reader, mut output, op, order, n) }
		18 { endian_read[AliasUsize](mut reader, mut output, op, order, n) }
		19 { endian_read[AliasIsize](mut reader, mut output, op, order, n) }
		else { panic('Invalid integer type') }
	}
}

// kind|warmup|capacity|start|consume-mode|payload|replacement|consumed|seed|prime|delta|op|type|endian|count
fn record(line string, path string) string {
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
	if replacement > 0 && api == 1 {
		reader.peek(capacity) or { panic(err) }
		reader.toss(uint(consumed))
	}
	mut out := '${status}|' + snapshot(mut reader, buffer, output) + '~'
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
		status = operate(mut reader, mut output, f[11].int(), f[12].int(), f[13].int(),
			uint(f[14].u64()))
		observed_status = status
		observed_output = unsafe { output }
		out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
		available := reader.buffered_len()
		consume := match count {
			1 {
				available
			}
			2 {
				if available > 0 { 1 } else { 0 }
			}
			3 {
				(available + 1) / 2
			}
			else {
				0
			}
		}

		reader.toss(uint(consume))
		out += 'consumed-${consume}|' + snapshot(mut reader, buffer, output) + '~'
		if attempt == 0 {
			status = 'ok'
			reader.seek_by(delta) or { status = err.msg() }
			out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
			if api == 2 && replacement == 1
				&& C.witty_reader_delimiter_seed(0, uint(consumed)) != 0 {
				panic('Reader reseed failed')
			}
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
		result := record(os.args[3], os.args[2] + '.owned')
		observed_path = ''
		println(result)
		return
	}
	path := os.args[1]
	for i, line in (os.read_lines(path) or { panic(err) }) {
		println(record(line, path + '.${i}.owned'))
	}
}
