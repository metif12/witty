module main

import encoding.hex
import math
import os
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, uint) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_view(&u8, uint) int
fn C.witty_writer_seek_drain(&u8, uint) int

__global (
	seen string
)

type VectorLane = i64
type VectorAliasOne = [1]VectorLane
type VectorAliasThree = [3]VectorLane
type VectorAliasEight = [8]VectorLane

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	format := (hex.decode(f[1])!).bytestr()
	raw := f[8].u64()
	options := zigimg.FormatOptions{
		width:     if f[10] == '-' { ?uint(none) } else { ?uint(uint(f[10].u64())) }
		precision: if f[11] == '-' { ?uint(none) } else { ?uint(uint(f[11].u64())) }
		alignment: unsafe { zigimg.Alignment(f[14].int()) }
		fill:      u8(f[15].int())
	}
	depth := uint(f[13].u64())
	match f[0].int() {
		0 {
			match f[12].int() {
				1 {
					lanes := [i64((raw + u64(0) * u64(0x9e3779b97f4a7c15)))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lanes := [i64((raw + u64(0) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(1) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(2) * u64(0x9e3779b97f4a7c15)))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lanes := [i64((raw + u64(0) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(1) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(2) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(3) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(4) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(5) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(6) * u64(0x9e3779b97f4a7c15))),
						i64((raw + u64(7) * u64(0x9e3779b97f4a7c15)))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		1 {
			match f[12].int() {
				1 {
					lanes := [u8((raw + u64(0) * u64(0x9e3779b97f4a7c15)))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lanes := [u8((raw + u64(0) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(1) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(2) * u64(0x9e3779b97f4a7c15)))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lanes := [u8((raw + u64(0) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(1) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(2) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(3) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(4) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(5) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(6) * u64(0x9e3779b97f4a7c15))),
						u8((raw + u64(7) * u64(0x9e3779b97f4a7c15)))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		2 {
			match f[12].int() {
				1 {
					lanes := [((raw >> 0) & 1) != 0]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(int(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lanes := [((raw >> 0) & 1) != 0, ((raw >> 1) & 1) != 0, ((raw >> 2) & 1) != 0]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(int(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lanes := [((raw >> 0) & 1) != 0, ((raw >> 1) & 1) != 0, ((raw >> 2) & 1) != 0,
						((raw >> 3) & 1) != 0, ((raw >> 4) & 1) != 0, ((raw >> 5) & 1) != 0,
						((raw >> 6) & 1) != 0, ((raw >> 7) & 1) != 0]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(int(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		3 {
			match f[12].int() {
				1 {
					lanes := [math.f32_from_bits(u32((raw ^ u64(0))))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(math.f32_bits(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lanes := [math.f32_from_bits(u32((raw ^ u64(0)))),
						math.f32_from_bits(u32((raw ^ u64(2147483648)))), math.f32_from_bits(u32(0))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(math.f32_bits(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lanes := [math.f32_from_bits(u32((raw ^ u64(0)))),
						math.f32_from_bits(u32((raw ^ u64(2147483648)))), math.f32_from_bits(u32(0)),
						math.f32_from_bits(u32((raw ^ u64(0)))),
						math.f32_from_bits(u32((raw ^ u64(2147483648)))), math.f32_from_bits(u32(0)),
						math.f32_from_bits(u32((raw ^ u64(0)))),
						math.f32_from_bits(u32((raw ^ u64(2147483648))))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(math.f32_bits(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		4 {
			match f[12].int() {
				1 {
					lanes := [math.f64_from_bits(u64((raw ^ u64(0))))]!
					mut parts := []string{}
					for lane in lanes { parts << '${math.f64_bits(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lanes := [math.f64_from_bits(u64((raw ^ u64(0)))),
						math.f64_from_bits(u64((raw ^ u64(9223372036854775808)))),
						math.f64_from_bits(u64(0))]!
					mut parts := []string{}
					for lane in lanes { parts << '${math.f64_bits(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lanes := [math.f64_from_bits(u64((raw ^ u64(0)))),
						math.f64_from_bits(u64((raw ^ u64(9223372036854775808)))),
						math.f64_from_bits(u64(0)), math.f64_from_bits(u64((raw ^ u64(0)))),
						math.f64_from_bits(u64((raw ^ u64(9223372036854775808)))),
						math.f64_from_bits(u64(0)), math.f64_from_bits(u64((raw ^ u64(0)))),
						math.f64_from_bits(u64((raw ^ u64(9223372036854775808))))]!
					mut parts := []string{}
					for lane in lanes { parts << '${math.f64_bits(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		5 {
			match f[12].int() {
				1 {
					lanes := VectorAliasOne([VectorLane((raw + u64(0) * u64(0x9e3779b97f4a7c15)))]!)
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lanes := VectorAliasThree([
						VectorLane((raw + u64(0) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(1) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(2) * u64(0x9e3779b97f4a7c15))),
					]!)
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lanes := VectorAliasEight([
						VectorLane((raw + u64(0) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(1) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(2) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(3) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(4) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(5) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(6) * u64(0x9e3779b97f4a7c15))),
						VectorLane((raw + u64(7) * u64(0x9e3779b97f4a7c15))),
					]!)
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		6 {
			match f[12].int() {
				1 {
					lanes := [(raw + u64(0) * u64(0x9e3779b97f4a7c15))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lanes := [(raw + u64(0) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(1) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(2) * u64(0x9e3779b97f4a7c15))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lanes := [(raw + u64(0) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(1) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(2) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(3) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(4) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(5) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(6) * u64(0x9e3779b97f4a7c15)),
						(raw + u64(7) * u64(0x9e3779b97f4a7c15))]!
					mut parts := []string{}
					for lane in lanes { parts << '${u64(lane)}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		else { panic('invalid lane type') }
	}
}

fn snapshot(status string, writer zigimg.WriteStream, buffer []u8, file bool) string {
	mut contents := []u8{len: 4096}
	n := if file { C.witty_writer_seek_view(contents.data, uint(contents.len)) } else { int(0) }
	if n < 0 { panic('observer failed') }
	valid := if file { C.witty_writer_seek_valid() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { uint(0) } else { uint(unused.data) - uint(buffer.data) }
	return '${status}|${writer.get_pos()}:${writer.unused_capacity_len()}:${writer.buffered().len}:${offset}:${valid}|${buffer.hex()}|${writer.buffered().hex()}|${unused.hex()}|${seen}|${contents[..int(n)].hex()}'
}

fn record(line string, path string) string {
	f := line.split('|')
	kind, cap, start, prefix, binding := f[2].int(), f[3].int(), f[4].u64(), f[5].int(), f[6].int()
	mut buffer := []u8{len: cap, init: u8(index * 17 + 165)}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	if kind > 0 {
		fd := C.witty_writer_seek_setup(path.str)
		if fd < 0 || C.witty_writer_seek_restore((path + '.restored').str, 32) != 0 {
			panic('setup failed')
		}
		writer = if kind == 1 {
			zigimg.WriteStream.init_file(os.File{ fd: fd }, mut buffer)
		} else {
			zigimg.WriteStream.init_file_streaming(os.File{ fd: fd }, mut buffer)
		}
	}
	defer { if kind > 0 && C.witty_writer_seek_cleanup() != 0 { panic('cleanup failed') } }
	writer.seek_to(start) or {}
	writer.write_all([]u8{len: prefix, init: u8(index * 31 + 7)}) or { panic('prefix failed') }
	if kind > 0 {
		if binding == 1 && C.witty_writer_seek_replace(1) != 0 { panic('replace failed') }
		if binding == 2 && C.witty_writer_seek_close() != 0 { panic('close failed') }
	}
	seen = '-'
	mut out := snapshot('ready', writer, buffer, kind > 0) + '~'
	mut status := 'ok'
	mut adapter := writer.writer()
	operate(mut adapter, f) or { status = err.msg() }
	out += snapshot(status, writer, buffer, kind > 0) + '~'
	if buffer.len > 0 { buffer[0] ^= 0x5a }
	out += snapshot('caller', writer, buffer, kind > 0) + '~'
	status = 'skip'
	if f[7] == '1' {
		status = 'ok'
		writer.flush() or { status = err.msg() }
	}
	out += snapshot(status, writer, buffer, kind > 0) + '~'
	mut drain := int(-3)
	mut wire := []u8{}
	if kind > 0 && binding == 1 {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, uint(bytes.len))
			if drain <= 0 { break }
			wire << bytes[..int(drain)]
		}
	}
	return out + '${drain}:${wire.hex()}'
}

fn main() {
	for i, line in (os.read_lines(os.args[1]) or { panic(err) }) {
		println(record(line, os.args[1] + '.${i}.owned'))
	}
}
