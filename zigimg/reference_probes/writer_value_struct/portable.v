module main

import zigimg

struct Empty {}

struct Numbers {
	n     i64
	u     u64
	truth bool
}

struct Sequences {
	bytes []u8
	fixed [2]i16
}

struct Nested {
	child Numbers
	empty Empty
	items []Empty
}

enum Tag {
	zero
	high
}
struct Tagged {
	tag Tag
	n   int
}

struct Custom {
	n int
}

fn (value Custom) format() string {
	return '${value.n}'
}

type AliasEmpty = Empty
type AliasNumbers = Numbers
type AliasSequences = Sequences
type AliasNested = Nested
type AliasTagged = Tagged
type AliasCustom = Custom

fn numbers(raw u64) Numbers {
	return Numbers{unsafe { i64(raw) }, raw, raw & 1 != 0}
}

fn make[T](raw u64, payload []u8) T {
	$if T.unaliased_typ is Empty {
		value := Empty{}
		return T(value)
	} $else $if T.unaliased_typ is Numbers {
		value := numbers(raw)
		return T(value)
	} $else $if T.unaliased_typ is Sequences {
		fixed := [i16(raw), i16(raw >> 16)]!
		value := Sequences{payload[8..11], fixed}
		return T(value)
	} $else $if T.unaliased_typ is Nested {
		value := Nested{numbers(raw), Empty{}, [Empty{}, Empty{}]}
		return T(value)
	} $else $if T.unaliased_typ is Tagged {
		value := Tagged{unsafe { Tag(int(raw & 1)) }, int(raw)}
		return T(value)
	} $else {
		value := Custom{int(raw)}
		return T(value)
	}
}

fn check[T](expected string) ! {
	payload := [u8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	value := make[T](7, payload)
	mut bytes := []u8{len: 1024}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_value('any', zigimg.FormatOptions{}, value, 3)!
	assert writer.buffered().bytestr() == expected
	mut cutoff := []u8{len: 16}
	mut out := zigimg.WriteStream.init_memory(mut cutoff)
	out.print_value('any', zigimg.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, value, 0)!
	assert out.buffered().bytestr() == '.{ ... }'
	mut nested_buffer := []u8{len: 64}
	mut nested_writer := zigimg.WriteStream.init_memory(mut nested_buffer)
	nested_writer.print_value('any', zigimg.FormatOptions{}, [
		[value],
		[]T{},
	], 2)!
	assert nested_writer.buffered().bytestr() == '{ { .{ ... } }, {  } }'
}

fn main() {
	check[Empty]('.{ }') or { panic(err) }
	check[Numbers]('.{ .n = 7, .u = 7, .truth = true }') or { panic(err) }
	check[Sequences]('.{ .bytes = { 8, 9, 10 }, .fixed = { 7, 0 } }') or { panic(err) }
	check[Nested]('.{ .child = .{ .n = 7, .u = 7, .truth = true }, .empty = .{ }, .items = { .{ }, .{ } } }') or {
		panic(err)
	}
	check[Tagged]('.{ .tag = .high, .n = 7 }') or { panic(err) }
	check[Custom]('.{ .n = 7 }') or { panic(err) }
	check[AliasEmpty]('.{ }') or { panic(err) }
	check[AliasNumbers]('.{ .n = 7, .u = 7, .truth = true }') or { panic(err) }
	check[AliasSequences]('.{ .bytes = { 8, 9, 10 }, .fixed = { 7, 0 } }') or { panic(err) }
	check[AliasNested]('.{ .child = .{ .n = 7, .u = 7, .truth = true }, .empty = .{ }, .items = { .{ }, .{ } } }') or {
		panic(err)
	}
	check[AliasTagged]('.{ .tag = .high, .n = 7 }') or { panic(err) }
	check[AliasCustom]('.{ .n = 7 }') or { panic(err) }
}
