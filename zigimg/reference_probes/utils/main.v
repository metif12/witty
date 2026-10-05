module main

import os
import zigimg

enum Code as u16 {
	zero
	one
	large = 0x1234
}
enum Color as u8 {
	zero
	two = 2
	six = 6
}
struct Inner {
	color Color
	flag  bool
	bytes [3]u8
}

struct Header {
	value        u32
	signed_value i16
	code         Code
	inner        Inner
	bytes        [2]u8
}

fn main() {
	if os.args.len > 1 {
		bytes := []u8{len: 5}
		if os.args[1] == 'native' {
			zigimg.to_magic_number_native(bytes)
		} else {
			zigimg.to_magic_number_foreign(bytes)
		}
		eprintln('UNEXPECTED')
		return
	}
	for length in 0 .. 5 {
		for seed in 0 .. 256 {
			mut bytes := []u8{len: length}
			for index in 0 .. length {
				bytes[index] = u8(seed + index * 71)
			}
			println('m:${length}:${seed}|${zigimg.to_magic_number_native(bytes):08x}:${zigimg.to_magic_number_foreign(bytes):08x}:${zigimg.to_magic_number(bytes, zigimg.LittleEndian{}):08x}:${zigimg.to_magic_number(bytes, zigimg.BigEndian{}):08x}')
		}
	}
	assert sizeof(Header) == 16
	for seed in 0 .. 16 {
		for code in [u16(0), 1, 0x1234, 0xabcd] {
			for color in [u8(0), 2, 6, 3] {
				for length in 0 .. 19 {
					mut bytes := []u8{len: 18}
					for i in 0 .. bytes.len {
						bytes[i] = u8(seed * 13 + i * 37)
					}
					bytes[6] = u8(code >> 8)
					bytes[7] = u8(code)
					bytes[8] = color
					bytes[9] = u8(seed & 1)
					for mode in 0 .. 4 {
						mut reader := zigimg.ReadStream.init_memory(bytes[..length])
						mut value := Header{}
						mut status := 'ok'
						if mode == 0 {
							value = zigimg.take_struct_native[Header](mut reader) or {
								status = err.msg()
								Header{}
							}
						} else if mode == 1 {
							value = zigimg.take_struct_foreign[Header](mut reader) or {
								status = err.msg()
								Header{}
							}
						} else if mode == 2 {
							value = zigimg.take_struct[Header, zigimg.BigEndian](mut reader, zigimg.BigEndian{}) or {
								status = err.msg()
								Header{}
							}
						} else {
							value = zigimg.take_struct[Header, zigimg.LittleEndian](mut reader, zigimg.LittleEndian{}) or {
								status = err.msg()
								Header{}
							}
						}
						if status == 'ok' {
							println('s:${seed}:${code}:${color}:${length}:${mode}|${reader.get_pos()}:${value.value}:${value.signed_value}:${u16(value.code)}:${u8(value.inner.color)}:${value.inner.flag}:${value.inner.bytes[0]}:${value.inner.bytes[1]}:${value.inner.bytes[2]}:${value.bytes[0]}:${value.bytes[1]}')
						} else {
							println('s:${seed}:${code}:${color}:${length}:${mode}|${reader.get_pos()}:${status}')
						}
					}
				}
			}
		}
	}
	for compression in 0 .. 256 {
		mut reader := zigimg.ReadStream.init_memory([u8(0), 0, 0, 1, 0, 0, 0, 1, 8, 2,
			u8(compression), u8(255 - compression), 0])
		value := zigimg.take_struct[zigimg.PngHeaderData, zigimg.BigEndian](mut reader, zigimg.BigEndian{}) or {
			panic(err)
		}
		println('p:${compression}|${reader.get_pos()}:${u8(value.compression_method)}:${u8(value.filter_method)}')
	}
}
