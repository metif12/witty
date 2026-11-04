module main

import os
import zigimg as p

type Element0 = &u8
type Flat0 = [3]&u8
type Nested0 = [2][3]&u8
type Single0 = [3]Element0
type Element1 = &u16
type Flat1 = [3]&u16
type Nested1 = [2][3]&u16
type Single1 = [3]Element1
type Element2 = &u32
type Flat2 = [3]&u32
type Nested2 = [2][3]&u32
type Single2 = [3]Element2
type Element3 = &u64
type Flat3 = [3]&u64
type Nested3 = [2][3]&u64
type Single3 = [3]Element3
type Element4 = &usize
type Flat4 = [3]&usize
type Nested4 = [2][3]&usize
type Single4 = [3]Element4
type Element5 = &i8
type Flat5 = [3]&i8
type Nested5 = [2][3]&i8
type Single5 = [3]Element5
type Element6 = &i16
type Flat6 = [3]&i16
type Nested6 = [2][3]&i16
type Single6 = [3]Element6
type Element7 = &int
type Flat7 = [3]&int
type Nested7 = [2][3]&int
type Single7 = [3]Element7
type Element8 = &i64
type Flat8 = [3]&i64
type Nested8 = [2][3]&i64
type Single8 = [3]Element8
type Element9 = &isize
type Flat9 = [3]&isize
type Nested9 = [2][3]&isize
type Single9 = [3]Element9
type Element10 = &f32
type Flat10 = [3]&f32
type Nested10 = [2][3]&f32
type Single10 = [3]Element10
type Element11 = &f64
type Flat11 = [3]&f64
type Nested11 = [2][3]&f64
type Single11 = [3]Element11
type Element12 = &bool
type Flat12 = [3]&bool
type Nested12 = [2][3]&bool
type Single12 = [3]Element12
type Element13 = voidptr
type Flat13 = [3]voidptr
type Nested13 = [2][3]voidptr
type Single13 = [3]Element13
type Values = []Flat0
type Number = int

struct Record {
	value int
}

struct Args {
	value []Flat0
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
