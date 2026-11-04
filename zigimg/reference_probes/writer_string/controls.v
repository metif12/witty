module main

import os
import zigimg as p

type Text = string

struct Record {
	text string
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
