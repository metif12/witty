module main

import os
import zigimg as p

type Base0 = u8
type Element0 = &Base0
type Flat0 = [3]&Base0
type Nested0 = [2][3]&Base0
type Single0 = [3]Element0
type Slice0 = []Element0
type OptionalSlice0 = []?&Base0
type Base1 = u16
type Element1 = &Base1
type Flat1 = [3]&Base1
type Nested1 = [2][3]&Base1
type Single1 = [3]Element1
type Slice1 = []Element1
type OptionalSlice1 = []?&Base1
type Base2 = u32
type Element2 = &Base2
type Flat2 = [3]&Base2
type Nested2 = [2][3]&Base2
type Single2 = [3]Element2
type Slice2 = []Element2
type OptionalSlice2 = []?&Base2
type Base3 = u64
type Element3 = &Base3
type Flat3 = [3]&Base3
type Nested3 = [2][3]&Base3
type Single3 = [3]Element3
type Slice3 = []Element3
type OptionalSlice3 = []?&Base3
type Base4 = uint
type Element4 = &Base4
type Flat4 = [3]&Base4
type Nested4 = [2][3]&Base4
type Single4 = [3]Element4
type Slice4 = []Element4
type OptionalSlice4 = []?&Base4
type Base5 = i8
type Element5 = &Base5
type Flat5 = [3]&Base5
type Nested5 = [2][3]&Base5
type Single5 = [3]Element5
type Slice5 = []Element5
type OptionalSlice5 = []?&Base5
type Base6 = i16
type Element6 = &Base6
type Flat6 = [3]&Base6
type Nested6 = [2][3]&Base6
type Single6 = [3]Element6
type Slice6 = []Element6
type OptionalSlice6 = []?&Base6
type Base7 = int
type Element7 = &Base7
type Flat7 = [3]&Base7
type Nested7 = [2][3]&Base7
type Single7 = [3]Element7
type Slice7 = []Element7
type OptionalSlice7 = []?&Base7
type Base8 = i64
type Element8 = &Base8
type Flat8 = [3]&Base8
type Nested8 = [2][3]&Base8
type Single8 = [3]Element8
type Slice8 = []Element8
type OptionalSlice8 = []?&Base8
type Base9 = int
type Element9 = &Base9
type Flat9 = [3]&Base9
type Nested9 = [2][3]&Base9
type Single9 = [3]Element9
type Slice9 = []Element9
type OptionalSlice9 = []?&Base9
type Base10 = f32
type Element10 = &Base10
type Flat10 = [3]&Base10
type Nested10 = [2][3]&Base10
type Single10 = [3]Element10
type Slice10 = []Element10
type OptionalSlice10 = []?&Base10
type Base11 = f64
type Element11 = &Base11
type Flat11 = [3]&Base11
type Nested11 = [2][3]&Base11
type Single11 = [3]Element11
type Slice11 = []Element11
type OptionalSlice11 = []?&Base11
type Base12 = bool
type Element12 = &Base12
type Flat12 = [3]&Base12
type Nested12 = [2][3]&Base12
type Single12 = [3]Element12
type Slice12 = []Element12
type OptionalSlice12 = []?&Base12
type Element13 = voidptr
type Flat13 = [3]voidptr
type Nested13 = [2][3]voidptr
type Single13 = [3]Element13
type Values = []Flat0
type Number = int
type OptionalNumbers = [2]?&Base7

struct Record {
	value int
}

struct Args {
	value []Flat0
}

fn borrowed[E](_ E, raw uint, length int) []E {
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
