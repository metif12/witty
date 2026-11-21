module main

import encoding.hex
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

type Base0 = [3]u8
type Element0 = &Base0
type Flat0 = [3]&Base0
type Nested0 = [2][3]&Base0
type Single0 = [3]Element0
type Base1 = [2]int
type Element1 = &Base1
type Flat1 = [3]&Base1
type Nested1 = [2][3]&Base1
type Single1 = [3]Element1
type Base2 = [2][3]u16
type Element2 = &Base2
type Flat2 = [3]&Base2
type Nested2 = [2][3]&Base2
type Single2 = [3]Element2
type Base3 = [1]bool
type Element3 = &Base3
type Flat3 = [3]&Base3
type Nested3 = [2][3]&Base3
type Single3 = [3]Element3

fn borrowed[E](_ E, raw uint, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	raw := uint(f[8].u64())
	length := f[9].int()
	api := (hex.decode(f[1])!).bytestr()
	options := zigimg.FormatOptions{
		width:     if f[10] == '-' {
			?uint(none)
		} else {
			?uint(uint(f[10].u64()))
		}
		precision: if f[11] == '-' { ?uint(none) } else { ?uint(uint(f[11].u64())) }
		alignment: unsafe { zigimg.Alignment(f[14].int()) }
		fill:      u8(f[15].int())
	}
	depth := uint(f[13].u64())
	match f[0].int() {
		0 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat0(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat0{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				1 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Nested0(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested0{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				2 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Single0(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single0{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				else { panic('invalid shape') }
			}
		}
		1 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat1(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat1{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				1 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Nested1(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested1{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				2 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Single1(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single1{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				else { panic('invalid shape') }
			}
		}
		2 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat2(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat2{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				1 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Nested2(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested2{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				2 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Single2(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single2{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				else { panic('invalid shape') }
			}
		}
		3 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat3(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat3{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				1 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Nested3(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested3{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				2 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Single3(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single3{} }
						view := borrowed(witness, raw, length)
						seen = '${uint(view.data)}:${view.len}'
						if api == 'vs' {
							writer.print_value('*', options, view, depth)!
						} else {
							writer.print_address(view)!
						}
					}
				}
				else { panic('invalid shape') }
			}
		}
		else { panic('invalid family') }
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
