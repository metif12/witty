module main

import os
import zigimg as p

type Text = string
type Flat = [3]string
type Rows = []Text
type OptionalRows = []?string
type Pair = [2]string
type OptionalPairs = []?Pair

struct Args {
	value Rows
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
