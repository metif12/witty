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

type LaneWord = bool
type LaneBase = int
type LanePointer = &LaneBase
type LaneArray = [3]LanePointer

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	format := (hex.decode(f[1])!).bytestr()
	raw := f[8].u64()
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
				1 {
					lane0 := unsafe { &u8(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &u8(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u8(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u8(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &u8(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u8(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u8(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &u8(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &u8(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &u8(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &u8(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &u8(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		1 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &u16(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &u16(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u16(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u16(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &u16(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u16(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u16(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &u16(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &u16(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &u16(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &u16(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &u16(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		2 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &u32(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &u32(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u32(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u32(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &u32(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u32(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u32(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &u32(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &u32(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &u32(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &u32(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &u32(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		3 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &u64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &u64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u64(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u64(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &u64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &u64(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &u64(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &u64(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &u64(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &u64(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &u64(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &u64(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		4 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &uint(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &uint(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &uint(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &uint(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &uint(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &uint(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &uint(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &uint(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &uint(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &uint(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &uint(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &uint(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		5 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &i8(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &i8(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &i8(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &i8(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &i8(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &i8(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &i8(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &i8(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &i8(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &i8(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &i8(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &i8(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		6 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &i16(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &i16(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &i16(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &i16(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &i16(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &i16(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &i16(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &i16(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &i16(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &i16(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &i16(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &i16(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		7 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &int(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &int(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &int(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &int(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &int(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &int(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &int(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &int(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &int(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &int(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &int(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &int(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		8 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &i64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &i64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &i64(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &i64(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &i64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &i64(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &i64(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &i64(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &i64(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &i64(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &i64(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &i64(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		9 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &int(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &int(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &int(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &int(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &int(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &int(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &int(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &int(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &int(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &int(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &int(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &int(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		10 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &f32(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &f32(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &f32(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &f32(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &f32(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &f32(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &f32(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &f32(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &f32(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &f32(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &f32(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &f32(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		11 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &f64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &f64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &f64(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &f64(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &f64(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &f64(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &f64(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &f64(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &f64(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &f64(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &f64(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &f64(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		12 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &bool(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &bool(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &bool(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &bool(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &bool(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &bool(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &bool(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &bool(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &bool(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &bool(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &bool(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &bool(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		13 {
			match f[12].int() {
				1 {
					lane0 := voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))
					lane1 := voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))
					lane2 := voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))
					lane1 := voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))
					lane2 := voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))
					lane3 := voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))
					lane4 := voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))
					lane5 := voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))
					lane6 := voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))
					lane7 := voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		14 {
			match f[12].int() {
				1 {
					lane0 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) })
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) })
					lane1 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) })
					lane2 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) })
					lanes := LaneArray([lane0, lane1, lane2]!)
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) })
					lane1 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) })
					lane2 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) })
					lane3 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) })
					lane4 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) })
					lane5 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) })
					lane6 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) })
					lane7 := LanePointer(unsafe { &LaneBase(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) })
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		15 {
			match f[12].int() {
				1 {
					lane0 := unsafe { &LaneWord(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := unsafe { &LaneWord(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &LaneWord(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &LaneWord(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := unsafe { &LaneWord(voidptr(uint((raw + u64(0) * u64(0x9e3779b97f4a7c15))))) }
					lane1 := unsafe { &LaneWord(voidptr(uint((raw + u64(1) * u64(0x9e3779b97f4a7c15))))) }
					lane2 := unsafe { &LaneWord(voidptr(uint((raw + u64(2) * u64(0x9e3779b97f4a7c15))))) }
					lane3 := unsafe { &LaneWord(voidptr(uint((raw + u64(3) * u64(0x9e3779b97f4a7c15))))) }
					lane4 := unsafe { &LaneWord(voidptr(uint((raw + u64(4) * u64(0x9e3779b97f4a7c15))))) }
					lane5 := unsafe { &LaneWord(voidptr(uint((raw + u64(5) * u64(0x9e3779b97f4a7c15))))) }
					lane6 := unsafe { &LaneWord(voidptr(uint((raw + u64(6) * u64(0x9e3779b97f4a7c15))))) }
					lane7 := unsafe { &LaneWord(voidptr(uint((raw + u64(7) * u64(0x9e3779b97f4a7c15))))) }
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		16 {
			match f[12].int() {
				1 {
					lane0 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane1 := ?&u8(none)
					lane2 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(2) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane1 := ?&u8(none)
					lane2 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(2) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane3 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(3) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane4 := ?&u8(none)
					lane5 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(5) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane6 := ?&u8(unsafe { &u8(voidptr(uint((((raw + u64(6) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane7 := ?&u8(none)
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		17 {
			match f[12].int() {
				1 {
					lane0 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane1 := ?&f64(none)
					lane2 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(2) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane1 := ?&f64(none)
					lane2 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(2) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane3 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(3) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane4 := ?&f64(none)
					lane5 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(5) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane6 := ?&f64(unsafe { &f64(voidptr(uint((((raw + u64(6) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane7 := ?&f64(none)
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
			}
		}
		18 {
			match f[12].int() {
				1 {
					lane0 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lanes := [lane0]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				3 {
					lane0 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane1 := ?&bool(none)
					lane2 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(2) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lanes := [lane0, lane1, lane2]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				8 {
					lane0 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(0) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane1 := ?&bool(none)
					lane2 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(2) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane3 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(3) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane4 := ?&bool(none)
					lane5 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(5) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane6 := ?&bool(unsafe { &bool(voidptr(uint((((raw + u64(6) * u64(0x9e3779b97f4a7c15)) & ~u64(7)) | u64(8))))) })
					lane7 := ?&bool(none)
					lanes := [lane0, lane1, lane2, lane3, lane4, lane5, lane6, lane7]!
					mut parts := []string{}
					for lane in lanes { parts << '${uint(voidptr(lane or { unsafe { nil } }))}' }
					seen = parts.join(',')
					writer.print_vector(format, options, lanes, depth)!
				}
				else { panic('invalid length') }
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
