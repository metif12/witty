module main

import os
import zigimg as p

type Slice = []u8
type Ref = &Slice
type Elements = [2]Ref
type OptionalSlice = []?int
type PairSlice = [][2]u16
type NestedSlice = [][]u8
type NestedRef = &NestedSlice

struct Args {
	value Ref
}

fn borrowed[E](_ E) []E {
	return unsafe { array{ data: voidptr(uint(0x1234)), len: 0, cap: 0, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn require(ok bool) { if !ok { panic('control assertion failed') } }

fn run() ! {
	mut backing := []u8{len: 512, init: 0xa5}
	before := backing.clone()
	_ = before
	mut w := p.WriteStream.init_memory(mut backing)
	_ = w
	// BODY
}

fn main() { run() or { panic(err) } }
