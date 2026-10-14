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

type AliasU8 = u8
type AliasU16 = u16
type AliasU32 = u32
type AliasU64 = u64
type AliasI8 = i8
type AliasI16 = i16
type AliasInt = int
type AliasI64 = i64
type AliasUsize = usize
type AliasIsize = isize
type AliasBig = zigimg.BigEndian
type AliasLittle = zigimg.LittleEndian

fn endian_read[T](mut reader zigimg.ReadStream, mut destination []T, order int) string {
	mut adapter := reader.reader()
	match order {
		0 {
			adapter.read_slice_endian[T, zigimg.BigEndian](mut destination, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian[T, zigimg.LittleEndian](mut destination, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian[T, AliasBig](mut destination, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian[T, AliasLittle](mut destination, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	return 'ok'
}

fn record(line string, path string) string {
	return match line.split('|')[11].int() {
		0 { record_typed[u8](line, path) }
		1 { record_typed[u16](line, path) }
		2 { record_typed[u32](line, path) }
		3 { record_typed[u64](line, path) }
		4 { record_typed[i8](line, path) }
		5 { record_typed[i16](line, path) }
		6 { record_typed[int](line, path) }
		7 { record_typed[i64](line, path) }
		8 { record_typed[usize](line, path) }
		9 { record_typed[isize](line, path) }
		10 { record_typed[AliasU8](line, path) }
		11 { record_typed[AliasU16](line, path) }
		12 { record_typed[AliasU32](line, path) }
		13 { record_typed[AliasU64](line, path) }
		14 { record_typed[AliasI8](line, path) }
		15 { record_typed[AliasI16](line, path) }
		16 { record_typed[AliasInt](line, path) }
		17 { record_typed[AliasI64](line, path) }
		18 { record_typed[AliasUsize](line, path) }
		19 { record_typed[AliasIsize](line, path) }
		else { panic('Invalid integer type') }
	}
}

// kind|warmup|capacity|start|consume-mode|payload|replacement|consumed|seed|prime|delta|type|endian|count|offset
fn record_typed[T](line string, path string) string {
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
	n, offset := f[13].int(), f[14].int()
	mut allocation := []T{len: n + 2}
	mut output := unsafe { allocation.data.vbytes(allocation.len * int(sizeof(T))) }
	for i in 0 .. output.len {
		output[i] = u8(195 + i * 11)
	}
	mut destination := unsafe { allocation[offset..offset + n] }
	observed_reader = &reader
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	observed_file = kind > 0
	observed_status = 'ok'
	mut status := 'ok'
	if start > 0 { reader.seek_to(u64(start)) or { status = err.msg() } }
	if replacement > 0 && api == 1 {
		reader.peek(capacity) or { panic(err) }
		reader.toss(usize(consumed))
	}
	mut out := '${status}|' + snapshot(mut reader, buffer, output) + '~'
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
		status = endian_read[T](mut reader, mut destination, f[12].int())
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

		reader.toss(usize(consume))
		out += 'consumed-${consume}|' + snapshot(mut reader, buffer, output) + '~'
		if attempt == 0 {
			status = 'ok'
			reader.seek_by(delta) or { status = err.msg() }
			out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
			if api == 2 && replacement == 1
				&& C.witty_reader_delimiter_seed(0, usize(consumed)) != 0 {
				panic('Reader reseed failed')
			}
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
