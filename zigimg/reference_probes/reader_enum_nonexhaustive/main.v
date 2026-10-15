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

@[nonexhaustive]
enum OpenU8 as u8 {
	first  = 0
	second = 2
	third  = 131
	fourth = 255
}
@[nonexhaustive]
enum OpenU16 as u16 {
	first  = 0
	second = 2
	third  = 32771
	fourth = 65535
}
@[nonexhaustive]
enum OpenU32 as u32 {
	first  = 0
	second = 2
	third  = 2147483651
	fourth = 4294967295
}
@[nonexhaustive]
enum OpenU64 as u64 {
	first  = 0
	second = 2
	third  = 9223372036854775811
	fourth = 18446744073709551615
}
@[nonexhaustive]
enum OpenI8 as i8 {
	first  = -128
	second = -3
	third  = 0
	fourth = 126
}
@[nonexhaustive]
enum OpenI16 as i16 {
	first  = -32768
	second = -3
	third  = 0
	fourth = 32766
}
@[nonexhaustive]
enum OpenI32 {
	first  = -2147483648
	second = -3
	third  = 0
	fourth = 2147483646
}
@[nonexhaustive]
enum OpenI64 as i64 {
	first  = -9223372036854775808
	second = -3
	third  = 0
	fourth = 9223372036854775806
}
type AliasOpenU8 = OpenU8
type AliasOpenU16 = OpenU16
type AliasOpenU32 = OpenU32
type AliasOpenU64 = OpenU64
type AliasOpenI8 = OpenI8
type AliasOpenI16 = OpenI16
type AliasOpenI32 = OpenI32
type AliasOpenI64 = OpenI64
type AliasCompression = zigimg.PngCompressionMethod
type AliasFilter = zigimg.PngFilterMethod
type AliasBig = zigimg.BigEndian
type AliasLittle = zigimg.LittleEndian

fn enum_read[T, E](mut reader zigimg.ReadStream, mut output []u8, order E, signed bool) string {
	mut adapter := reader.reader()
	value := adapter.take_enum_nonexhaustive[T, E](E{}) or { return err.msg() }
	mut word := u64(value)
	if sizeof(T) < 8 { word &= (u64(1) << (sizeof(T) * 8)) - 1 }
	output = (if signed { '${i64(value)}:${word}' } else { '${u64(value)}:${word}' }).bytes()
	return 'ok'
}

fn endian_read[T](mut reader zigimg.ReadStream, mut output []u8, order int, signed bool) string {
	return match order {
		0 { enum_read[T, zigimg.BigEndian](mut reader, mut output, zigimg.BigEndian{}, signed) }
		1 { enum_read[T, zigimg.LittleEndian](mut reader, mut output, zigimg.LittleEndian{}, signed) }
		2 { enum_read[T, AliasBig](mut reader, mut output, AliasBig{}, signed) }
		else { enum_read[T, AliasLittle](mut reader, mut output, AliasLittle{}, signed) }
	}
}

fn operate(mut reader zigimg.ReadStream, mut output []u8, tag int, order int) string {
	signed := tag < 32 && tag % 8 >= 4
	return match tag {
		8 { endian_read[OpenU8](mut reader, mut output, order, signed) }
		9 { endian_read[OpenU16](mut reader, mut output, order, signed) }
		10 { endian_read[OpenU32](mut reader, mut output, order, signed) }
		11 { endian_read[OpenU64](mut reader, mut output, order, signed) }
		12 { endian_read[OpenI8](mut reader, mut output, order, signed) }
		13 { endian_read[OpenI16](mut reader, mut output, order, signed) }
		14 { endian_read[OpenI32](mut reader, mut output, order, signed) }
		15 { endian_read[OpenI64](mut reader, mut output, order, signed) }
		24 { endian_read[AliasOpenU8](mut reader, mut output, order, signed) }
		25 { endian_read[AliasOpenU16](mut reader, mut output, order, signed) }
		26 { endian_read[AliasOpenU32](mut reader, mut output, order, signed) }
		27 { endian_read[AliasOpenU64](mut reader, mut output, order, signed) }
		28 { endian_read[AliasOpenI8](mut reader, mut output, order, signed) }
		29 { endian_read[AliasOpenI16](mut reader, mut output, order, signed) }
		30 { endian_read[AliasOpenI32](mut reader, mut output, order, signed) }
		31 { endian_read[AliasOpenI64](mut reader, mut output, order, signed) }
		32 { endian_read[zigimg.PngCompressionMethod](mut reader, mut output, order, signed) }
		33 { endian_read[zigimg.PngFilterMethod](mut reader, mut output, order, signed) }
		34 { endian_read[AliasCompression](mut reader, mut output, order, signed) }
		35 { endian_read[AliasFilter](mut reader, mut output, order, signed) }
		else { panic('Invalid enum type') }
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
		status = operate(mut reader, mut output, f[12].int(), f[13].int())
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
