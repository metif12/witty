module main

import encoding.hex
import os
import strings
import zigimg

#flag -I @VMODROOT/zigimg/reference_probes/streams
#include "fixture_shims.h"

fn C.witty_stream_probe_pipe(&int) int
fn C.witty_stream_probe_close(int) int
fn C.witty_stream_probe_read(int, &u8, usize) isize

type AliasU8 = u8
type AliasU16 = u16
type AliasU32 = u32
type AliasU64 = u64
type AliasI8 = i8
type AliasI16 = i16
type AliasInt = int
type AliasI64 = i64
type AliasFloat = f32
type AliasDouble = f64
type AliasUsize = usize
type AliasIsize = isize
type AliasBig = zigimg.BigEndian
type AliasLittle = zigimg.LittleEndian

fn value_from_bits[T](value u64) T {
	$if T.unaliased_typ is f32 {
		word := u32(value)
		return T(unsafe { *(&f32(&word)) })
	} $else $if T.unaliased_typ is f64 {
		return T(unsafe { *(&f64(&value)) })
	} $else {
		return T(value)
	}
}

fn value_bits[T](value T) u64 {
	$if T.unaliased_typ is f32 {
		return unsafe { *(&u32(&value)) }
	} $else $if T.unaliased_typ is f64 {
		return unsafe { *(&u64(&value)) }
	} $else {
		mut word := u64(value)
		if sizeof(T) < 8 { word &= (u64(1) << (sizeof(T) * 8)) - 1 }
		return word
	}
}

fn emit_reader[E](mut out strings.Builder, reader zigimg.BitReader[E]) {
	out.write_string('@${reader.bits}:${reader.count}:')
	out.write_string(reader.reader.get_pos().str())
	out.write_string(';')
}

fn bit_reads[E, T](mut out strings.Builder, data []u8, actions string) {
	mut input := zigimg.ReadStream.init_memory(data)
	mut bits := zigimg.BitReader[E]{
		reader: input.reader()
	}
	for action in actions.split(',') {
		if action == 'a' {
			bits.align_to_byte()
			out.write_string('Ok')
			emit_reader(mut out, bits)
			continue
		}
		if action[0] == `s` {
			input.seek_to(action[1..].u64()) or {
				out.write_string(err.msg())
				emit_reader(mut out, bits)
				continue
			}
			out.write_string('Ok')
			emit_reader(mut out, bits)
			continue
		}
		num := u16(action[1..].u16())
		if action[0] == `t` {
			value, count := bits.read_bits_tuple[E, T](num) or {
				out.write_string(err.msg())
				emit_reader(mut out, bits)
				continue
			}
			out.write_string('Ok:')
			out.write_string(value_bits(value).str())
			out.write_string(':${count}')
		} else if action[0] == `r` {
			mut count := u16(999)
			value := bits.read_bits[E, T](num, &count) or {
				out.write_string('${err.msg()}:${count}')
				emit_reader(mut out, bits)
				continue
			}
			out.write_string('Ok:')
			out.write_string(value_bits(value).str())
			out.write_string(':${count}')
		} else {
			value := bits.read_bits_no_eof[E, T](num) or {
				out.write_string(err.msg())
				emit_reader(mut out, bits)
				continue
			}
			out.write_string('Ok:')
			out.write_string(value_bits(value).str())
		}
		emit_reader(mut out, bits)
	}
}

fn bit_writes[E, T](mut out strings.Builder, capacity int, actions string) {
	mut data := []u8{len: capacity, init: 0xa5}
	mut output := zigimg.WriteStream.init_memory(mut data)
	mut bits := zigimg.BitWriter[E]{
		writer: output.writer()
	}
	for action in actions.split(',') {
		mut status := 'Ok'
		if action == 'f' {
			bits.flush_bits() or { status = err.msg() }
		} else if action[0] == `s` {
			output.seek_to(action[1..].u64()) or { status = err.msg() }
		} else {
			parts := action[1..].split(':')
			bits.write_bits[E, T](value_from_bits[T](parts[1].u64()), parts[0].u16()) or {
				status = err.msg()
			}
		}
		out.write_string('${status}@${bits.bits}:${bits.count}:')
		out.write_string(output.get_pos().str())
		out.write_string(':${hex.encode(data)};')
	}
}

fn bit_case[E, T](mut out strings.Builder, mode int, data []u8, capacity int, actions string) {
	if mode == 0 {
		bit_reads[E, T](mut out, data, actions)
	} else {
		bit_writes[E, T](mut out, capacity, actions)
	}
}

fn integer_case[E, T](mut out strings.Builder, data []u8, capacity int, raw u64) {
	mut input := zigimg.ReadStream.init_memory(data)
	mut reader := input.reader()
	for position in [u64(0), 1] {
		mut status := 'Ok'
		input.seek_to(position) or { status = err.msg() }
		out.write_string('${status}:')
		value := reader.take_int[T, E](E{}) or {
			status = err.msg()
			T(0)
		}
		out.write_string('${status}:')
		out.write_string(value_bits(value).str())
		out.write_string('@')
		out.write_string(input.get_pos().str())
		out.write_string(';')
	}
	mut bytes := []u8{len: capacity, init: 0xa5}
	mut output := zigimg.WriteStream.init_memory(mut bytes)
	mut writer := output.writer()
	for _ in 0 .. 2 {
		mut status := 'Ok'
		writer.write_int[T, E](value_from_bits[T](raw), E{}) or { status = err.msg() }
		out.write_string('${status}@')
		out.write_string(output.get_pos().str())
		out.write_string(':${hex.encode(bytes)};')
	}
}

fn dispatch_integer[E](mut out strings.Builder, kind int, data []u8, capacity int, raw u64) {
	match kind {
		0 { integer_case[E, u8](mut out, data, capacity, raw) }
		1 { integer_case[E, u16](mut out, data, capacity, raw) }
		2 { integer_case[E, u32](mut out, data, capacity, raw) }
		3 { integer_case[E, u64](mut out, data, capacity, raw) }
		4 { integer_case[E, i8](mut out, data, capacity, raw) }
		5 { integer_case[E, i16](mut out, data, capacity, raw) }
		6 { integer_case[E, int](mut out, data, capacity, raw) }
		7 { integer_case[E, i64](mut out, data, capacity, raw) }
		10 { integer_case[E, usize](mut out, data, capacity, raw) }
		11 { integer_case[E, isize](mut out, data, capacity, raw) }
		12 { integer_case[E, AliasU8](mut out, data, capacity, raw) }
		13 { integer_case[E, AliasU16](mut out, data, capacity, raw) }
		14 { integer_case[E, AliasU32](mut out, data, capacity, raw) }
		15 { integer_case[E, AliasU64](mut out, data, capacity, raw) }
		16 { integer_case[E, AliasI8](mut out, data, capacity, raw) }
		17 { integer_case[E, AliasI16](mut out, data, capacity, raw) }
		18 { integer_case[E, AliasInt](mut out, data, capacity, raw) }
		19 { integer_case[E, AliasI64](mut out, data, capacity, raw) }
		22 { integer_case[E, AliasUsize](mut out, data, capacity, raw) }
		23 { integer_case[E, AliasIsize](mut out, data, capacity, raw) }
		else { panic('Invalid integer type') }
	}
}

fn dispatch[E](mut out strings.Builder, mode int, kind int, data []u8, capacity int, actions string) {
	match kind {
		0 { bit_case[E, u8](mut out, mode, data, capacity, actions) }
		1 { bit_case[E, u16](mut out, mode, data, capacity, actions) }
		2 { bit_case[E, u32](mut out, mode, data, capacity, actions) }
		3 { bit_case[E, u64](mut out, mode, data, capacity, actions) }
		4 { bit_case[E, i8](mut out, mode, data, capacity, actions) }
		5 { bit_case[E, i16](mut out, mode, data, capacity, actions) }
		6 { bit_case[E, int](mut out, mode, data, capacity, actions) }
		7 { bit_case[E, i64](mut out, mode, data, capacity, actions) }
		8 { bit_case[E, f32](mut out, mode, data, capacity, actions) }
		9 { bit_case[E, f64](mut out, mode, data, capacity, actions) }
		10 { bit_case[E, usize](mut out, mode, data, capacity, actions) }
		11 { bit_case[E, isize](mut out, mode, data, capacity, actions) }
		12 { bit_case[E, AliasU8](mut out, mode, data, capacity, actions) }
		13 { bit_case[E, AliasU16](mut out, mode, data, capacity, actions) }
		14 { bit_case[E, AliasU32](mut out, mode, data, capacity, actions) }
		15 { bit_case[E, AliasU64](mut out, mode, data, capacity, actions) }
		16 { bit_case[E, AliasI8](mut out, mode, data, capacity, actions) }
		17 { bit_case[E, AliasI16](mut out, mode, data, capacity, actions) }
		18 { bit_case[E, AliasInt](mut out, mode, data, capacity, actions) }
		19 { bit_case[E, AliasI64](mut out, mode, data, capacity, actions) }
		20 { bit_case[E, AliasFloat](mut out, mode, data, capacity, actions) }
		21 { bit_case[E, AliasDouble](mut out, mode, data, capacity, actions) }
		22 { bit_case[E, AliasUsize](mut out, mode, data, capacity, actions) }
		23 { bit_case[E, AliasIsize](mut out, mode, data, capacity, actions) }
		else { panic('Invalid type') }
	}
}

fn emit_stream(mut out strings.Builder, mut stream zigimg.ReadStream) {
	out.write_string('@')
	out.write_string(stream.get_pos().str())
	out.write_string(':')
	end := stream.get_end_pos() or {
		out.write_string('${err.msg()};')
		return
	}
	out.write_string(end.str())
	out.write_string(';')
}

fn byte_reads(mut out strings.Builder, mode int, data []u8, capacity int, actions string, path string) {
	mut buffer := []u8{len: capacity, init: 0xa5}
	mut file := os.File{}
	mut closed := true
	mut stream := zigimg.ReadStream.init_memory(data)
	if mode == 3 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		closed = false
		stream = zigimg.ReadStream.init_file(file, mut buffer)
	}
	defer {
		if !closed { file.close() }
	}
	mut reader := stream.reader()
	for action in actions.split(',') {
		mut status := 'Ok'
		match action[0] {
			`p`, `t`, `q`, `d`, `b` {
				mut bytes := []u8{}
				if action[0] == `p` {
					bytes = reader.peek(action[1..].int()) or {
						status = err.msg()
						[]u8{}
					}
				} else if action[0] == `t` {
					bytes = reader.take(action[1..].int()) or {
						status = err.msg()
						[]u8{}
					}
				} else if action[0] == `q` {
					bytes = reader.peek_delimiter_inclusive(action[1..].u8()) or {
						status = err.msg()
						[]u8{}
					}
				} else if action[0] == `d` {
					bytes = reader.take_delimiter_inclusive(action[1..].u8()) or {
						status = err.msg()
						[]u8{}
					}
				} else {
					value := reader.take_byte() or {
						status = err.msg()
						u8(0)
					}
					if status == 'Ok' { bytes = [value] }
				}
				out.write_string('${status}:${hex.encode(bytes)}')
			}
			`h`, `l` {
				mut bytes := []u8{len: action[1..].int(), init: 0xa5}
				if action[0] == `h` {
					count := reader.read_slice_short(mut bytes) or {
						status = err.msg()
						usize(0)
					}
					out.write_string('${status}:${count}:${hex.encode(bytes)}')
				} else {
					reader.read_slice_all(mut bytes) or { status = err.msg() }
					out.write_string('${status}:${hex.encode(bytes)}')
				}
			}
			`s` {
				stream.seek_to(action[1..].u64()) or { status = err.msg() }
				out.write_string(status)
			}
			`y` {
				stream.seek_by(action[1..].i64()) or { status = err.msg() }
				out.write_string(status)
			}
			`x` {
				reader.discard_all(usize(action[1..].u64())) or { status = err.msg() }
				out.write_string(status)
			}
			`o` {
				reader.toss(usize(action[1..].u64()))
				out.write_string(status)
			}
			`z` {
				os.write_file_array(path, hex.decode(action[1..]) or { panic(err) }) or {
					panic(err)
				}
				out.write_string(status)
			}
			`c` {
				file.close()
				closed = true
				out.write_string(status)
			}
			`e` {
				out.write_string(status)
			}
			else {
				panic('Invalid read action')
			}
		}

		emit_stream(mut out, mut stream)
	}
}

fn byte_writes(mut out strings.Builder, mode int, capacity int, actions string, path string) {
	mut buffer := []u8{len: capacity, init: 0xa5}
	mut file := os.File{}
	mut closed := true
	mut stream := zigimg.WriteStream.init_memory(mut buffer)
	if mode == 5 {
		file = os.create(path) or { panic(err) }
		closed = false
		stream = zigimg.WriteStream.init_file(file, mut buffer)
	}
	defer {
		if !closed { file.close() }
	}
	mut writer := stream.writer()
	for action in actions.split(',') {
		mut status := 'Ok'
		match action[0] {
			`w` {
				count := writer.write(hex.decode(action[1..]) or { panic(err) }) or {
					status = err.msg()
					usize(0)
				}
				out.write_string('${status}:${count}')
			}
			`a` {
				writer.write_all(hex.decode(action[1..]) or { panic(err) }) or {
					status = err.msg()
				}
				out.write_string(status)
			}
			`b` {
				writer.write_byte(action[1..].u8()) or { status = err.msg() }
				out.write_string(status)
			}
			`f` {
				writer.flush() or { status = err.msg() }
				out.write_string(status)
			}
			`s` {
				stream.seek_to(action[1..].u64()) or { status = err.msg() }
				out.write_string(status)
			}
			`c` {
				file.close()
				closed = true
				out.write_string(status)
			}
			else {
				panic('Invalid write action')
			}
		}

		out.write_string('@')
		out.write_string(stream.get_pos().str())
		out.write_string(':${hex.encode(writer.buffered())}:')
		if mode == 5 {
			contents := os.read_bytes(path) or { panic(err) }
			out.write_string(hex.encode(contents))
		} else {
			out.write_string(hex.encode(buffer))
		}
		out.write_string(';')
	}
}

fn pipe_writes(mut out strings.Builder, capacity int, actions string) {
	mut fds := [2]int{}
	if C.witty_stream_probe_pipe(&fds[0]) != 0 { panic('Cannot create fixture pipe') }
	defer { C.witty_stream_probe_close(fds[0]) }
	mut closed := false
	defer {
		if !closed { C.witty_stream_probe_close(fds[1]) }
	}
	mut buffer := []u8{len: capacity, init: 0xa5}
	mut stream := zigimg.WriteStream.init_file(os.File{ fd: fds[1] }, mut buffer)
	mut writer := stream.writer()
	mut delivered := []u8{}
	for action in actions.split(',') {
		mut status := 'Ok'
		match action[0] {
			`w` {
				count := writer.write(hex.decode(action[1..]) or { panic(err) }) or {
					status = err.msg()
					usize(0)
				}
				out.write_string('${status}:${count}')
			}
			`a` {
				writer.write_all(hex.decode(action[1..]) or { panic(err) }) or {
					status = err.msg()
				}
				out.write_string(status)
			}
			`b` {
				writer.write_byte(action[1..].u8()) or { status = err.msg() }
				out.write_string(status)
			}
			`f` {
				writer.flush() or { status = err.msg() }
				out.write_string(status)
			}
			`s` {
				stream.seek_to(action[1..].u64()) or { status = err.msg() }
				out.write_string(status)
			}
			`c` {
				C.witty_stream_probe_close(fds[1])
				closed = true
				out.write_string(status)
			}
			else {
				panic('Invalid pipe action')
			}
		}

		mut target := []u8{len: 128}
		for {
			n := C.witty_stream_probe_read(fds[0], target.data, usize(target.len))
			if n <= 0 { break
			 }
			delivered << target[..int(n)]
		}
		out.write_string('@')
		out.write_string(stream.get_pos().str())
		out.write_string(':${hex.encode(writer.buffered())}:${hex.encode(delivered)};')
	}
}

fn trap(code int, path string) {
	mut data := []u8{len: 32, init: 0xab}
	mut input := zigimg.ReadStream.init_memory(data)
	mut output := zigimg.WriteStream.init_memory(mut data)
	match code {
		0 {
			_ := input.take_byte() or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			input.seek_by(i64(0x7fffffffffffffff)) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		1 {
			mut bits := zigimg.BitReader[zigimg.LittleEndian]{
				reader: input.reader()
			}
			_, _ := bits.read_bits_tuple[zigimg.LittleEndian, u8](16) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		2 {
			mut bits := zigimg.BitReader[zigimg.LittleEndian]{
				reader: input.reader()
			}
			_, _ := bits.read_bits_tuple[zigimg.LittleEndian, u16](17) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		3 {
			mut bits := zigimg.BitWriter[zigimg.BigEndian]{
				writer: output.writer()
			}
			bits.write_bits[zigimg.BigEndian, u8](0xab, 16) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		4 {
			mut bits := zigimg.BitWriter[zigimg.BigEndian]{
				writer: output.writer()
			}
			bits.write_bits[zigimg.BigEndian, u8](1, 1) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			bits.write_bits[zigimg.BigEndian, u8](0xab, 16) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		5 {
			input.toss(33)
		}
		6, 7, 8, 14 {
			os.write_file(path, '0123456789') or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			mut file := os.open(path) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			defer { file.close() }
			mut buffer := []u8{len: if code == 7 { 0 } else { 8 }}
			mut stream := zigimg.ReadStream.init_file(file, mut buffer)
			if code == 8 || code == 14 {
				_ := stream.take_byte() or {
					eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
					return
				}
				if code == 14 {
					stream.seek_by(-1) or {
						eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
						return
					}
				}
				stream.seek_by(i64(0x7fffffffffffffff)) or {
					eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
					return
				}
			} else {
				_ := stream.take(if code == 7 { 1 } else { 9 }) or {
					eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
					return
				}
			}
		}
		9 {
			mut bits := zigimg.BitReader[zigimg.BigEndian]{
				reader: input.reader()
				count:  8
			}
			_, _ := bits.read_bits_tuple[zigimg.BigEndian, u8](0) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		10 {
			mut bits := zigimg.BitReader[zigimg.LittleEndian]{
				reader: input.reader()
				count:  9
			}
			_, _ := bits.read_bits_tuple[zigimg.LittleEndian, u8](9) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		11 {
			mut bits := zigimg.BitWriter[zigimg.BigEndian]{
				writer: output.writer()
				count:  9
			}
			bits.write_bits[zigimg.BigEndian, u8](0, 0) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		12 {
			mut bits := zigimg.BitWriter[zigimg.LittleEndian]{
				writer: output.writer()
				count:  8
			}
			bits.write_bits[zigimg.LittleEndian, u8](0, 0) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		13 {
			mut bits := zigimg.BitWriter[zigimg.BigEndian]{
				writer: output.writer()
				count:  9
			}
			bits.flush_bits() or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		15 {
			mut fds := [2]int{}
			if C.witty_stream_probe_pipe(&fds[0]) != 0 { panic('Cannot create fixture pipe') }
			defer { C.witty_stream_probe_close(fds[0]) }
			mut buffer := []u8{}
			mut stream := zigimg.WriteStream.init_file(os.File{ fd: fds[1] }, mut buffer)
			_ := stream.write('abc'.bytes()) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			C.witty_stream_probe_close(fds[1])
			stream.seek_to(0) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
		}
		16 {
			mut file := os.create(path) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			defer { file.close() }
			mut buffer := []u8{len: 1}
			mut stream := zigimg.WriteStream.init_file(file, mut buffer)
			stream.seek_to(u64(0xffffffffffffffff)) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			stream.write_byte(1) or {
				eprintln('UNEXPECTED_RETURNED_ERROR:${err.msg()}')
				return
			}
			println(stream.get_pos())
		}
		else {
			panic('Invalid trap')
		}
	}

	println('returned')
}

fn main() {
	path := os.join_path(os.dir(os.args[1]), 'translated-fixture.bin')
	defer { os.rm(path) or {} }
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut out := strings.new_builder(contents.len * 8)
	for line in contents.split_into_lines() {
		parts := line.split('|')
		mode := parts[0].int()
		endian := parts[1].int()
		kind := parts[2].int()
		capacity := parts[3].int()
		data := hex.decode(parts[4]) or { panic(err) }
		actions := parts[5]
		if mode == 6 {
			trap(kind, path)
			return
		}
		if mode == 7 {
			match endian {
				0 {
					dispatch_integer[zigimg.BigEndian](mut out, kind, data, capacity, actions.u64())
				}
				1 {
					dispatch_integer[zigimg.LittleEndian](mut out, kind, data, capacity,
						actions.u64())
				}
				2 {
					dispatch_integer[AliasBig](mut out, kind, data, capacity, actions.u64())
				}
				else {
					dispatch_integer[AliasLittle](mut out, kind, data, capacity, actions.u64())
				}
			}

			out.write_string('\n')
			continue
		}
		if mode == 8 {
			pipe_writes(mut out, capacity, actions)
			out.write_string('\n')
			continue
		}
		if mode <= 1 {
			match endian {
				0 { dispatch[zigimg.BigEndian](mut out, mode, kind, data, capacity, actions) }
				1 { dispatch[zigimg.LittleEndian](mut out, mode, kind, data, capacity, actions) }
				2 { dispatch[AliasBig](mut out, mode, kind, data, capacity, actions) }
				else { dispatch[AliasLittle](mut out, mode, kind, data, capacity, actions) }
			}
		} else if mode <= 3 {
			byte_reads(mut out, mode, data, capacity, actions, path)
		} else {
			byte_writes(mut out, mode, capacity, actions, path)
		}
		out.write_string('\n')
	}
	print(out.str())
}
