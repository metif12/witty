module main

import os
import zigimg as p

struct Num {}

pub fn (v Num) format_number(mut w p.WriteStream, n p.NumberFormat) ! { w.write_all('N'.bytes())! }

struct BytesHook {}

pub fn (v BytesHook) format_byte_size(mut w p.WriteStream, units p.ByteSizeUnits) ! {
	w.write_all('B'.bytes())!
}

struct DurationHook {}

pub fn (v DurationHook) format_duration(mut w p.WriteStream) ! { w.write_all('D'.bytes())! }

type NumAlias = Num

struct Args {
	value Num
}

struct Empty {}

struct Nonfallible {}

pub fn (v Nonfallible) format_number(mut w p.WriteStream, n p.NumberFormat) {}

pub fn (v Nonfallible) format_byte_size(mut w p.WriteStream, units p.ByteSizeUnits) {}

pub fn (v Nonfallible) format_duration(mut w p.WriteStream) {}

struct WrongNumber {}

pub fn (v WrongNumber) format_number(mut w p.WriteStream, n p.FormatOptions) ! {}

struct WrongBytes {}

pub fn (v WrongBytes) format_byte_size(mut w p.WriteStream, n bool) ! {}

struct WrongDuration {}

pub fn (v WrongDuration) format_duration(mut w p.WriteStream, n bool) ! {}

enum Named {
	zero
	one
}

pub fn (v Named) format_number(mut w p.WriteStream, n p.NumberFormat) ! {
	w.write_all('unexpected'.bytes())!
}

fn require(ok bool) { if !ok { panic('control assertion failed') } }

fn run() ! {
	mut backing := []u8{len: 128, init: 0xa5}
	before := backing.clone()
	_ = before
	mut w := p.WriteStream.init_memory(mut backing)
	_ = w
	// BODY
}

fn main() { run() or { panic(err) } }
