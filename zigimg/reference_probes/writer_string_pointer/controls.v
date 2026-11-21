module main

import os
import zigimg as p

type Text = string
type Ref = &Text
type Elements = [2]&string
type OptionalElements = [2]?&string

struct Args {
	value &string
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
