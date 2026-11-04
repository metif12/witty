module main

import os
import zigimg as p

type Payload0_0 = [2]u8
type Slice0_0 = []?Payload0_0
type Payload0_1 = [2][3]u8
type Slice0_1 = []?Payload0_1
type Payload0_2 = [3]?u8
type Slice0_2 = []?Payload0_2
type Payload1_0 = [2]u16
type Slice1_0 = []?Payload1_0
type Payload1_1 = [2][3]u16
type Slice1_1 = []?Payload1_1
type Payload1_2 = [3]?u16
type Slice1_2 = []?Payload1_2
type Payload2_0 = [2]u32
type Slice2_0 = []?Payload2_0
type Payload2_1 = [2][3]u32
type Slice2_1 = []?Payload2_1
type Payload2_2 = [3]?u32
type Slice2_2 = []?Payload2_2
type Payload3_0 = [2]u64
type Slice3_0 = []?Payload3_0
type Payload3_1 = [2][3]u64
type Slice3_1 = []?Payload3_1
type Payload3_2 = [3]?u64
type Slice3_2 = []?Payload3_2
type Payload4_0 = [2]usize
type Slice4_0 = []?Payload4_0
type Payload4_1 = [2][3]usize
type Slice4_1 = []?Payload4_1
type Payload4_2 = [3]?usize
type Slice4_2 = []?Payload4_2
type Payload5_0 = [2]i8
type Slice5_0 = []?Payload5_0
type Payload5_1 = [2][3]i8
type Slice5_1 = []?Payload5_1
type Payload5_2 = [3]?i8
type Slice5_2 = []?Payload5_2
type Payload6_0 = [2]i16
type Slice6_0 = []?Payload6_0
type Payload6_1 = [2][3]i16
type Slice6_1 = []?Payload6_1
type Payload6_2 = [3]?i16
type Slice6_2 = []?Payload6_2
type Payload7_0 = [2]int
type Slice7_0 = []?Payload7_0
type Payload7_1 = [2][3]int
type Slice7_1 = []?Payload7_1
type Payload7_2 = [3]?int
type Slice7_2 = []?Payload7_2
type Payload8_0 = [2]i64
type Slice8_0 = []?Payload8_0
type Payload8_1 = [2][3]i64
type Slice8_1 = []?Payload8_1
type Payload8_2 = [3]?i64
type Slice8_2 = []?Payload8_2
type Payload9_0 = [2]isize
type Slice9_0 = []?Payload9_0
type Payload9_1 = [2][3]isize
type Slice9_1 = []?Payload9_1
type Payload9_2 = [3]?isize
type Slice9_2 = []?Payload9_2
type Payload10_0 = [2]f32
type Slice10_0 = []?Payload10_0
type Payload10_1 = [2][3]f32
type Slice10_1 = []?Payload10_1
type Payload10_2 = [3]?f32
type Slice10_2 = []?Payload10_2
type Payload11_0 = [2]f64
type Slice11_0 = []?Payload11_0
type Payload11_1 = [2][3]f64
type Slice11_1 = []?Payload11_1
type Payload11_2 = [3]?f64
type Slice11_2 = []?Payload11_2
type Payload12_0 = [2]bool
type Slice12_0 = []?Payload12_0
type Payload12_1 = [2][3]bool
type Slice12_1 = []?Payload12_1
type Payload12_2 = [3]?bool
type Slice12_2 = []?Payload12_2
type Pair = [2]int
type StringPair = [2]string
type OptionalStringPairs = []?StringPair
type Values = []?Pair

struct Record {
	value int
}

struct Args {
	value []?Pair
}

fn borrowed[E](_ E, raw usize, length int) []?E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(?E)) } }
}

fn require(ok bool) { if !ok { panic('control assertion failed') } }

fn run() ! {
	mut backing := []u8{len: 1024, init: 0xa5}
	before := backing.clone()
	_ = before
	mut w := p.WriteStream.init_memory(mut backing)
	_ = w
	// BODY
}

fn main() { run() or { panic(err) } }
