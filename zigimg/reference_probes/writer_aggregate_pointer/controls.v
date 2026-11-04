module main

import os
import zigimg as p

struct Record {
	value int
}

enum Choice {
	zero
	high
}

type Sum = Record | bool
type Alias = Record
type Pointer = &Alias

struct Custom {
	value int
}

pub fn (value Custom) format(mut w p.WriteStream) ! {
	w.print_value('d', p.FormatOptions{}, value.value, 0)!
}

struct Args {
	value &Record
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
