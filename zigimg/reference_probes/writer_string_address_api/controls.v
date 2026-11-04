module main

import os
import zigimg as p

type Text = string
type Pair = [2]string

struct Args {
	value string
}

fn borrowed(bits usize, length int) string {
	return unsafe { (&u8(voidptr(bits))).vstring_with_len(length) }
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
