module main

import os
import zigimg as p

type ArrayNumbers = [3]?int
type Values = []?int
type Slice0 = []?u8
type Slice1 = []?u16
type Slice2 = []?u32
type Slice3 = []?u64
type Slice4 = []?usize
type Slice5 = []?i8
type Slice6 = []?i16
type Slice7 = []?int
type Slice8 = []?i64
type Slice9 = []?isize
type Slice10 = []?f32
type Slice11 = []?f64
type Slice12 = []?bool

type Number = int

struct Record {
	value int
}

struct Args {
	value []?int
}

fn borrowed[E](_ E, raw usize, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
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
