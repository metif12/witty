module main

import os
import zigimg as p

type Bytes = [3]u8
type Pointer = &Bytes

struct Record {
	value int
}

struct Args {
	value &Bytes
}

enum Choice {
	zero
	high
}

type Sum = bool | u8

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
