module main

import os
import zigimg as p

type Element0 = &u8
type Slice0 = []?Element0
type Array0 = [2]?&u8
type Element1 = &u16
type Slice1 = []?Element1
type Array1 = [2]?&u16
type Element2 = &u32
type Slice2 = []?Element2
type Array2 = [2]?&u32
type Element3 = &u64
type Slice3 = []?Element3
type Array3 = [2]?&u64
type Element4 = &usize
type Slice4 = []?Element4
type Array4 = [2]?&usize
type Element5 = &i8
type Slice5 = []?Element5
type Array5 = [2]?&i8
type Element6 = &i16
type Slice6 = []?Element6
type Array6 = [2]?&i16
type Element7 = &int
type Slice7 = []?Element7
type Array7 = [2]?&int
type Element8 = &i64
type Slice8 = []?Element8
type Array8 = [2]?&i64
type Element9 = &isize
type Slice9 = []?Element9
type Array9 = [2]?&isize
type Element10 = &f32
type Slice10 = []?Element10
type Array10 = [2]?&f32
type Element11 = &f64
type Slice11 = []?Element11
type Array11 = [2]?&f64
type Element12 = &bool
type Slice12 = []?Element12
type Array12 = [2]?&bool
type Element13 = voidptr
type Slice13 = []?Element13
type Array13 = [2]?voidptr
type Values = []?Element0
type AliasArray = [2]?Element0
type Number = int

struct Record {
	value int
}

struct Args {
	value []?&u8
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
