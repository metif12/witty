module main

import os
import zigimg as p

type Word0 = u8
type Pointer0 = &Word0
type Word1 = u16
type Pointer1 = &Word1
type Word2 = u32
type Pointer2 = &Word2
type Word3 = u64
type Pointer3 = &Word3
type Word4 = usize
type Pointer4 = &Word4
type Word5 = i8
type Pointer5 = &Word5
type Word6 = i16
type Pointer6 = &Word6
type Word7 = int
type Pointer7 = &Word7
type Word8 = i64
type Pointer8 = &Word8
type Word9 = isize
type Pointer9 = &Word9
type Word10 = f32
type Pointer10 = &Word10
type Word11 = f64
type Pointer11 = &Word11
type Word12 = bool
type Pointer12 = &Word12

struct Args {
	value [2]&Word0
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
