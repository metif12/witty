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

type Element0 = &u8
type Flat0 = [3]&u8
type Nested0 = [2][3]&u8
type Single0 = [3]Element0
type Element1 = &u16
type Flat1 = [3]&u16
type Nested1 = [2][3]&u16
type Single1 = [3]Element1
type Element2 = &u32
type Flat2 = [3]&u32
type Nested2 = [2][3]&u32
type Single2 = [3]Element2
type Element3 = &u64
type Flat3 = [3]&u64
type Nested3 = [2][3]&u64
type Single3 = [3]Element3
type Element4 = &uint
type Flat4 = [3]&uint
type Nested4 = [2][3]&uint
type Single4 = [3]Element4
type Element5 = &i8
type Flat5 = [3]&i8
type Nested5 = [2][3]&i8
type Single5 = [3]Element5
type Element6 = &i16
type Flat6 = [3]&i16
type Nested6 = [2][3]&i16
type Single6 = [3]Element6
type Element7 = &int
type Flat7 = [3]&int
type Nested7 = [2][3]&int
type Single7 = [3]Element7
type Element8 = &i64
type Flat8 = [3]&i64
type Nested8 = [2][3]&i64
type Single8 = [3]Element8
type Element9 = &int
type Flat9 = [3]&int
type Nested9 = [2][3]&int
type Single9 = [3]Element9
type Element10 = &f32
type Flat10 = [3]&f32
type Nested10 = [2][3]&f32
type Single10 = [3]Element10
type Element11 = &f64
type Flat11 = [3]&f64
type Nested11 = [2][3]&f64
type Single11 = [3]Element11
type Element12 = &bool
type Flat12 = [3]&bool
type Nested12 = [2][3]&bool
type Single12 = [3]Element12
type Element13 = voidptr
type Flat13 = [3]voidptr
type Nested13 = [2][3]voidptr
type Single13 = [3]Element13

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
		4 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat4(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat4{} }
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
						pointer := unsafe { &Nested4(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested4{} }
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
						pointer := unsafe { &Single4(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single4{} }
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
		5 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat5(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat5{} }
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
						pointer := unsafe { &Nested5(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested5{} }
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
						pointer := unsafe { &Single5(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single5{} }
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
		6 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat6(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat6{} }
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
						pointer := unsafe { &Nested6(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested6{} }
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
						pointer := unsafe { &Single6(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single6{} }
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
		7 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat7(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat7{} }
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
						pointer := unsafe { &Nested7(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested7{} }
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
						pointer := unsafe { &Single7(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single7{} }
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
		8 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat8(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat8{} }
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
						pointer := unsafe { &Nested8(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested8{} }
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
						pointer := unsafe { &Single8(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single8{} }
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
		9 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat9(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat9{} }
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
						pointer := unsafe { &Nested9(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested9{} }
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
						pointer := unsafe { &Single9(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single9{} }
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
		10 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat10(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat10{} }
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
						pointer := unsafe { &Nested10(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested10{} }
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
						pointer := unsafe { &Single10(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single10{} }
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
		11 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat11(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat11{} }
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
						pointer := unsafe { &Nested11(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested11{} }
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
						pointer := unsafe { &Single11(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single11{} }
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
		12 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat12(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat12{} }
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
						pointer := unsafe { &Nested12(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested12{} }
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
						pointer := unsafe { &Single12(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single12{} }
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
		13 {
			match f[12].int() {
				0 {
					if api == 'vp' || api == 'dp' {
						pointer := unsafe { &Flat13(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Flat13{} }
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
						pointer := unsafe { &Nested13(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Nested13{} }
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
						pointer := unsafe { &Single13(voidptr(raw)) }
						seen = '${uint(voidptr(pointer))}:-'
						if api == 'vp' {
							writer.print_value('*', options, pointer, depth)!
						} else {
							writer.print_address(pointer)!
						}
					} else {
						witness := unsafe { Single13{} }
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
		else { panic('invalid type') }
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
