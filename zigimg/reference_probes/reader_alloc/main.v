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
	observed_held   []u8
	observed_file   bool
)

// This observer omits get_pos, which may itself be the failed observation.
fn state(mut reader zigimg.ReadStream, buffer []u8, output []u8, held []u8) string {
	mut size := ''
	length := reader.get_end_pos() or {
		size = err.msg()
		u64(0)
	}
	if size == '' { size = length.str() }
	valid := if observed_file { C.witty_reader_delimiter_valid() } else { 0 }
	refs := if observed_file { C.witty_reader_delimiter_refs() } else { 0 }
	alias := if output.len == 0 || held.len == 0 {
		'-'
	} else if output.data == held.data {
		'1'
	} else {
		'0'
	}
	return '${size}:${valid}:${refs}|${buffer.hex()}|${output.hex()}:${held.hex()}:${alias}|${reader.buffered().hex()}'
}

fn snapshot(mut reader zigimg.ReadStream, buffer []u8, output []u8, held []u8) string {
	return '${reader.get_pos()}:' + state(mut reader, buffer, output, held)
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' +
		state(mut observed_reader, observed_buffer, observed_output, observed_held)
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

fn number_read_0(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[u8, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[u8, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[u8, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[u8, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(u8))) }
	return 'ok'
}

fn number_read_1(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[u16, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[u16, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[u16, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[u16, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(u16))) }
	return 'ok'
}

fn number_read_2(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[u32, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[u32, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[u32, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[u32, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(u32))) }
	return 'ok'
}

fn number_read_3(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[u64, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[u64, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[u64, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[u64, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(u64))) }
	return 'ok'
}

fn number_read_4(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[i8, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[i8, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[i8, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[i8, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(i8))) }
	return 'ok'
}

fn number_read_5(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[i16, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[i16, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[i16, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[i16, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(i16))) }
	return 'ok'
}

fn number_read_6(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[int, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[int, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[int, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[int, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(int))) }
	return 'ok'
}

fn number_read_7(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[i64, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[i64, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[i64, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[i64, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(i64))) }
	return 'ok'
}

fn number_read_8(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[uint, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[uint, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[uint, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[uint, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(uint))) }
	return 'ok'
}

fn number_read_9(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[int, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[int, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[int, AliasBig](n, AliasBig{}) or { return err.msg() }
		}
		else {
			adapter.read_slice_endian_alloc[int, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(int))) }
	return 'ok'
}

fn number_read_10(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasU8, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasU8, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasU8, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasU8, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasU8))) }
	return 'ok'
}

fn number_read_11(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasU16, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasU16, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasU16, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasU16, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasU16))) }
	return 'ok'
}

fn number_read_12(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasU32, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasU32, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasU32, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasU32, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasU32))) }
	return 'ok'
}

fn number_read_13(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasU64, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasU64, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasU64, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasU64, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasU64))) }
	return 'ok'
}

fn number_read_14(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasI8, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasI8, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasI8, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasI8, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasI8))) }
	return 'ok'
}

fn number_read_15(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasI16, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasI16, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasI16, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasI16, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasI16))) }
	return 'ok'
}

fn number_read_16(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasInt, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasInt, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasInt, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasInt, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasInt))) }
	return 'ok'
}

fn number_read_17(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasI64, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasI64, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasI64, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasI64, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasI64))) }
	return 'ok'
}

fn number_read_18(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasUsize, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasUsize, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasUsize, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasUsize, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasUsize))) }
	return 'ok'
}

fn number_read_19(mut reader zigimg.ReadStream, mut output []u8, order int, n uint) string {
	mut adapter := reader.reader()
	values := match order {
		0 {
			adapter.read_slice_endian_alloc[AliasIsize, zigimg.BigEndian](n, zigimg.BigEndian{}) or {
				return err.msg()
			}
		}
		1 {
			adapter.read_slice_endian_alloc[AliasIsize, zigimg.LittleEndian](n, zigimg.LittleEndian{}) or {
				return err.msg()
			}
		}
		2 {
			adapter.read_slice_endian_alloc[AliasIsize, AliasBig](n, AliasBig{}) or {
				return err.msg()
			}
		}
		else {
			adapter.read_slice_endian_alloc[AliasIsize, AliasLittle](n, AliasLittle{}) or {
				return err.msg()
			}
		}
	}

	output = unsafe { values.data.vbytes(values.len * int(sizeof(AliasIsize))) }
	return 'ok'
}

fn operate(mut reader zigimg.ReadStream, mut output []u8, op int, tag int, order int, n uint) string {
	if op % 2 == 0 {
		output = reader.read_alloc(n) or { return err.msg() }
		return 'ok'
	}
	return match tag {
		0 { number_read_0(mut reader, mut output, order, n) }
		1 { number_read_1(mut reader, mut output, order, n) }
		2 { number_read_2(mut reader, mut output, order, n) }
		3 { number_read_3(mut reader, mut output, order, n) }
		4 { number_read_4(mut reader, mut output, order, n) }
		5 { number_read_5(mut reader, mut output, order, n) }
		6 { number_read_6(mut reader, mut output, order, n) }
		7 { number_read_7(mut reader, mut output, order, n) }
		8 { number_read_8(mut reader, mut output, order, n) }
		9 { number_read_9(mut reader, mut output, order, n) }
		10 { number_read_10(mut reader, mut output, order, n) }
		11 { number_read_11(mut reader, mut output, order, n) }
		12 { number_read_12(mut reader, mut output, order, n) }
		13 { number_read_13(mut reader, mut output, order, n) }
		14 { number_read_14(mut reader, mut output, order, n) }
		15 { number_read_15(mut reader, mut output, order, n) }
		16 { number_read_16(mut reader, mut output, order, n) }
		17 { number_read_17(mut reader, mut output, order, n) }
		18 { number_read_18(mut reader, mut output, order, n) }
		19 { number_read_19(mut reader, mut output, order, n) }
		else { panic('Invalid integer type') }
	}
}

// kind|warmup|capacity|start|consume-mode|payload|replacement|consumed|seed|prime|delta|api-and-mutation|type|endian|count
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
	mut held := []u8{}
	observed_reader = &reader
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	observed_held = unsafe { held }
	observed_file = kind > 0
	observed_status = 'ok'
	mut status := 'ok'
	if start > 0 { reader.seek_to(u64(start)) or { status = err.msg() } }
	if replacement > 0 && api == 1 {
		reader.peek(capacity) or { panic(err) }
		reader.toss(uint(consumed))
	}
	mut out := '${status}|' + snapshot(mut reader, buffer, output, held) + '~'
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
	out += '${status}|' + snapshot(mut reader, buffer, output, held) + '~'
	for attempt in 0 .. 3 {
		observed_status = 'calling'
		status = operate(mut reader, mut output, f[11].int(), f[12].int(), f[13].int(),
			uint(f[14].u64()))
		if status == 'ok' && held.len == 0 && output.len > 0 { held = unsafe { output } }
		observed_status = status
		observed_output = unsafe { output }
		observed_held = unsafe { held }
		out += '${status}|' + snapshot(mut reader, buffer, output, held) + '~'
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
		if f[11].int() >= 2 && output.len > 0 { output[0] ^= 90 }
		out += 'consumed-${consume}|' + snapshot(mut reader, buffer, output, held) + '~'
		if attempt == 0 {
			status = 'ok'
			reader.seek_by(delta) or { status = err.msg() }
			out += '${status}|' + snapshot(mut reader, buffer, output, held) + '~'
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
