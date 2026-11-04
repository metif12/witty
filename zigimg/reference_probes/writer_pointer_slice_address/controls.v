module main

import os
import zigimg as p

type Element0 = &u8
type Slice0 = []Element0
type Element1 = &u16
type Slice1 = []Element1
type Element2 = &u32
type Slice2 = []Element2
type Element3 = &u64
type Slice3 = []Element3
type Element4 = &usize
type Slice4 = []Element4
type Element5 = &i8
type Slice5 = []Element5
type Element6 = &i16
type Slice6 = []Element6
type Element7 = &int
type Slice7 = []Element7
type Element8 = &i64
type Slice8 = []Element8
type Element9 = &isize
type Slice9 = []Element9
type Element10 = &f32
type Slice10 = []Element10
type Element11 = &f64
type Slice11 = []Element11
type Element12 = &bool
type Slice12 = []Element12
type Element13 = voidptr
type Slice13 = []Element13
type Values = []Element0
type Number = int

struct Record {
	value int
}

struct Args {
	value []&u8
}

fn borrowed[E](_ E, raw usize, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn require(ok bool) { if !ok { panic('control assertion failed') } }

fn run() ! {
	mut backing := []u8{len: 4096, init: 0xa5}
	before := backing.clone()
	_ = before
	mut w := p.WriteStream.init_memory(mut backing)
	_ = w
	// BODY
}

fn main() { run() or { panic(err) } }
