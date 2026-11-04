module main

import os
import zigimg as p

type Base0 = u8
type Element0 = &&Base0
type Flat0 = [3]&&Base0
type Values = []Flat0
type OptionalNumbers = [2]?&&Base0
type OptionalNative = [2]?&&u8
type DeepElements = [1]&&&&&&u8

struct Args {
	value Values
}

type Native0 = u8
type NativeOuter0 = [2]&&Native0
type Native1 = u16
type NativeOuter1 = [2]&&Native1
type Native2 = u32
type NativeOuter2 = [2]&&Native2
type Native3 = u64
type NativeOuter3 = [2]&&Native3
type Native4 = usize
type NativeOuter4 = [2]&&Native4
type Native5 = i8
type NativeOuter5 = [2]&&Native5
type Native6 = i16
type NativeOuter6 = [2]&&Native6
type Native7 = int
type NativeOuter7 = [2]&&Native7
type Native8 = i64
type NativeOuter8 = [2]&&Native8
type Native9 = isize
type NativeOuter9 = [2]&&Native9
type Native10 = f32
type NativeOuter10 = [2]&&Native10
type Native11 = f64
type NativeOuter11 = [2]&&Native11
type Native12 = bool
type NativeOuter12 = [2]&&Native12

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
