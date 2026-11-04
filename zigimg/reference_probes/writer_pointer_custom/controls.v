module main

import os
import zigimg as p

struct Custom {
	value int
	stop  bool
}

pub fn (value Custom) format(mut writer p.WriteStream) ! {
	writer.write_all('custom:'.bytes())!
	if value.stop { return error('WriteFailed') }
	writer.print_value('d', p.FormatOptions{}, value.value, 0)!
}

type Alias = Custom
type Pointer = &Alias

enum Enum {
	zero
	high
}

pub fn (value Enum) format(mut writer p.WriteStream) ! { writer.write_all(value.str().bytes())! }

type Sum = Custom | bool

pub fn (value Sum) format(mut writer p.WriteStream) ! {
	match value {
		Custom { value.format(mut writer)! }
		bool { writer.write_all(if value { 'true'.bytes() } else { 'false'.bytes() })! }
	}
}

struct Missing {}

struct Plain {}

pub fn (value Plain) format(mut writer p.WriteStream) {
	writer.write_all('plain'.bytes()) or { panic(err) }
}

struct Args {
	value ?&Custom
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
