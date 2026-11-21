module main

import os
import zigimg as p

type Bytes = [3]u8
type Word = int
type Words = [3]Word
type Views = []Bytes
type Nested = [2][3]int

struct Record {
	value int
}

struct Args {
	value []Bytes
}

struct MaybeArgs {
	value ?Views
}

fn borrowed[E](_ E, raw uint, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn native_optional() ?[][3]u8 {
	zero := [3]u8{}
	return borrowed(zero, uint(0x1234), 0)
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
