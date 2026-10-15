module main

import os
import zigimg

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, usize) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_refs() int
fn C.witty_writer_seek_view(&u8, usize) isize
fn C.witty_writer_seek_drain(&u8, usize) isize

__global (
	observed_path    string
	observed_writer  = &zigimg.WriteStream(unsafe { nil })
	observed_buffer  []u8
	observed_file    bool
	observed_status  string
	observed_payload []u8
	observed_vectors [][]u8
	observed_api     int
	observed_length  int
	observed_tag     int
)

fn state(writer zigimg.WriteStream, buffer []u8) string {
	mut contents := []u8{len: 4096}
	n := if observed_file {
		C.witty_writer_seek_view(contents.data, usize(contents.len))
	} else {
		isize(0)
	}
	if n < 0 { panic('Writer observer failed') }
	valid := if observed_file { C.witty_writer_seek_valid() } else { 0 }
	refs := if observed_file { C.witty_writer_seek_refs() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { usize(0) } else { usize(unused.data) - usize(buffer.data) }
	mut headers := []string{}
	for bytes in observed_vectors {
		headers << '${usize(bytes.data) - usize(observed_payload.data)},${bytes.len}'
	}
	inputs := observed_payload.hex() + '#' + headers.join(';') +
		'#${observed_api}:${observed_tag}:${observed_length}'
	return '${writer.get_pos()}:${writer.unused_capacity_len()}:${writer.buffered().len}:${offset}:${valid}:${refs}|${buffer.hex()}|${writer.buffered().hex()}|${unused.hex()}|${inputs}|${contents[..int(n)].hex()}'
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' + state(*observed_writer, observed_buffer)
	os.write_file(observed_path, retained) or { eprintln('OBSERVER ERROR: ${err}') }
	if observed_file { C.witty_writer_seek_cleanup() }
}

fn change(mut bytes []u8, mode int, mask u8) {
	if mode == 0 || bytes.len == 0 { return }
	index := if mode == 1 { 0 } else { bytes.len - 1 }
	bytes[index] ^= mask
}

type Word0 = u8
type Pointer0 = &Word0
type Slice0 = []Word0
type Word1 = u16
type Pointer1 = &Word1
type Slice1 = []Word1
type Word2 = u32
type Pointer2 = &Word2
type Slice2 = []Word2
type Word3 = u64
type Pointer3 = &Word3
type Slice3 = []Word3
type Word4 = usize
type Pointer4 = &Word4
type Slice4 = []Word4
type Word5 = i8
type Pointer5 = &Word5
type Slice5 = []Word5
type Word6 = i16
type Pointer6 = &Word6
type Slice6 = []Word6
type Word7 = int
type Pointer7 = &Word7
type Slice7 = []Word7
type Word8 = i64
type Pointer8 = &Word8
type Slice8 = []Word8
type Word9 = isize
type Pointer9 = &Word9
type Slice9 = []Word9
type Word10 = f32
type Pointer10 = &Word10
type Slice10 = []Word10
type Word11 = f64
type Pointer11 = &Word11
type Slice11 = []Word11
type Word12 = bool
type Pointer12 = &Word12
type Slice12 = []Word12

fn typed_native_0(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &u8(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&u8(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []u8{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_0(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word0(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word0(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word0{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_1(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &u16(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&u16(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []u16{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_1(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word1(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word1(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word1{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_2(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &u32(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&u32(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []u32{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_2(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word2(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word2(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word2{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_3(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &u64(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&u64(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []u64{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_3(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word3(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word3(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word3{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_4(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &usize(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&usize(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []usize{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_4(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word4(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word4(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word4{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_5(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &i8(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&i8(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []i8{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_5(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word5(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word5(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word5{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_6(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &i16(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&i16(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []i16{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_6(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word6(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word6(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word6{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_7(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &int(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&int(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []int{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_7(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word7(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word7(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word7{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_8(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &i64(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&i64(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []i64{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_8(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word8(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word8(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word8{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_9(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &isize(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&isize(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []isize{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_9(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word9(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word9(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word9{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_10(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &f32(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&f32(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []f32{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_10(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word10(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word10(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word10{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_11(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &f64(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&f64(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []f64{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_11(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word11(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word11(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word11{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_native_12(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &bool(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&bool(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []bool{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn typed_alias_12(mut writer zigimg.WriteStream, raw u64, op int, count int) string {
	pointer := unsafe { &Word12(voidptr(usize(raw))) }
	if op == 1 {
		mut optional := ?&Word12(none)
		if raw != 0 { optional = pointer }
		writer.print_address(optional) or { return err.msg() }
	} else if op == 2 || op == 5 {
		mut values := []Word12{}
		unsafe {
			values.data = voidptr(usize(raw))
			values.len = count
			values.cap = count
		}
		writer.print_address(values) or { return err.msg() }
	} else {
		writer.print_address(pointer) or { return err.msg() }
	}
	return 'ok'
}

fn operate(mut writer zigimg.WriteStream, raw u64, tag int, op int, count int) string {
	if op == 8 {
		writer.print_address(unsafe { voidptr(usize(raw)) }) or { return err.msg() }
		return 'ok'
	}
	return match tag {
		0 {
			if op == 3 {
				typed_alias_0(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer0(unsafe { &Word0(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word0{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice0(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_0(mut writer, raw, op, count)
			}
		}
		1 {
			if op == 3 {
				typed_alias_1(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer1(unsafe { &Word1(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word1{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice1(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_1(mut writer, raw, op, count)
			}
		}
		2 {
			if op == 3 {
				typed_alias_2(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer2(unsafe { &Word2(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word2{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice2(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_2(mut writer, raw, op, count)
			}
		}
		3 {
			if op == 3 {
				typed_alias_3(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer3(unsafe { &Word3(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word3{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice3(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_3(mut writer, raw, op, count)
			}
		}
		4 {
			if op == 3 {
				typed_alias_4(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer4(unsafe { &Word4(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word4{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice4(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_4(mut writer, raw, op, count)
			}
		}
		5 {
			if op == 3 {
				typed_alias_5(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer5(unsafe { &Word5(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word5{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice5(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_5(mut writer, raw, op, count)
			}
		}
		6 {
			if op == 3 {
				typed_alias_6(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer6(unsafe { &Word6(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word6{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice6(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_6(mut writer, raw, op, count)
			}
		}
		7 {
			if op == 3 {
				typed_alias_7(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer7(unsafe { &Word7(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word7{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice7(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_7(mut writer, raw, op, count)
			}
		}
		8 {
			if op == 3 {
				typed_alias_8(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer8(unsafe { &Word8(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word8{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice8(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_8(mut writer, raw, op, count)
			}
		}
		9 {
			if op == 3 {
				typed_alias_9(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer9(unsafe { &Word9(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word9{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice9(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_9(mut writer, raw, op, count)
			}
		}
		10 {
			if op == 3 {
				typed_alias_10(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer10(unsafe { &Word10(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word10{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice10(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_10(mut writer, raw, op, count)
			}
		}
		11 {
			if op == 3 {
				typed_alias_11(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer11(unsafe { &Word11(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word11{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice11(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_11(mut writer, raw, op, count)
			}
		}
		12 {
			if op == 3 {
				typed_alias_12(mut writer, raw, op, count)
			} else if op == 4 {
				writer.print_address(Pointer12(unsafe { &Word12(voidptr(usize(raw))) })) or {
					return err.msg()
				}
				'ok'
			} else if op == 5 {
				mut values := []Word12{}
				unsafe {
					values.data = voidptr(usize(raw))
					values.len = count
					values.cap = count
				}
				writer.print_address(Slice12(values)) or { return err.msg() }
				'ok'
			} else {
				typed_native_12(mut writer, raw, op, count)
			}
		}
		else {
			panic('Invalid tag')
		}
	}
}

// kind|capacity|start|prefix|binding|finish|api|mask|raw|tag|length
fn record(line string, path string) string {
	f := line.split('|')
	kind, cap, start := f[0].int(), f[1].int(), f[2].u64()
	mut buffer := []u8{len: cap, init: u8(index * 17 + 165)}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	if kind > 0 {
		fd := C.witty_writer_seek_setup(path.str)
		restored := path + '.restored'
		if fd < 0 || C.witty_writer_seek_restore(restored.str, 32) != 0 {
			panic('Writer setup failed')
		}
		writer = if kind == 1 { zigimg.WriteStream.init_file(os.File{ fd: fd }, mut buffer) } else { zigimg.WriteStream.init_file_streaming(os.File{
				fd: fd
			}, mut buffer) }
	}
	defer {
		if kind > 0 && C.witty_writer_seek_cleanup() != 0 { panic('Writer cleanup failed') }
	}
	observed_writer = unsafe { &writer }
	observed_buffer = unsafe { buffer }
	observed_file = kind > 0
	raw := f[8].u64()
	mut payload := []u8{len: 8, init: u8(raw >> (index * 8))}
	data := unsafe { payload[..] }
	observed_tag = f[9].int()
	observed_api = f[6].int()
	observed_length = f[10].int()
	observed_payload = unsafe { payload }
	observed_vectors = [][]u8{}
	observed_vectors << unsafe { data }

	observed_status = 'setup'
	writer.seek_to(start) or {}
	writer.write_all([]u8{len: f[3].int(), init: u8(index * 31 + 7)}) or {
		panic('Prefix failed: ${err}')
	}
	if kind > 0 {
		if f[4] == '1' && C.witty_writer_seek_replace(1) != 0 { panic('Writer replacement failed') }
		if f[4] == '2' && C.witty_writer_seek_close() != 0 { panic('Writer close failed') }
	}
	mut out := 'setup|' + state(writer, buffer) + '~'
	mut adapter := writer.writer()
	api := f[6].int()
	out += 'ready|' + state(writer, buffer) + '~'
	observed_status = 'write'
	mut status := 'skip'
	status = operate(mut adapter, raw, f[9].int(), api, f[10].int())
	if status == 'skip' { status = 'ok' }
	out += status + '|' + state(writer, buffer) + '~'
	change(mut buffer, 1, u8(f[7].int()))
	out += 'caller|' + state(writer, buffer) + '~'
	status = 'skip'
	if f[5] == '1' {
		status = 'ok'
		writer.flush() or { status = err.msg() }
	}
	out += status + '|' + state(writer, buffer) + '~'
	mut drain := isize(-3)
	mut wire := []u8{}
	if kind > 0 && f[4] == '1' {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, usize(bytes.len))
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
	for i, line in (os.read_lines(os.args[1]) or { panic(err) }) {
		println(record(line, os.args[1] + '.${i}.owned'))
	}
}
