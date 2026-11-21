module main

import zigimg

struct Record {
	n     ?int
	bytes ?[]u8
}

enum Tag {
	zero
	high
}

type AliasInt = int
type AliasBytes = []u8
type AliasRecord = Record
type OptionalItems = []?int
type OptionalByteArray = [3]?u8

fn optional[T](value T) ?T {
	return value
}

fn check[T](value ?T, format string, depth uint, expected string) ! {
	mut bytes := []u8{len: 512}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_value(format, zigimg.FormatOptions{}, value, depth)!
	assert writer.buffered().bytestr() == expected
	mut absent := []u8{len: 16}
	mut out := zigimg.WriteStream.init_memory(mut absent)
	out.print_value(format, zigimg.FormatOptions{
		width:     uint(8)
		alignment: .center
		fill:      `_`
		precision: uint(99)
	}, ?T(none), depth)!
	assert out.buffered().bytestr() == '__null__'
}

fn main() {
	check[int](?int(-7), '?', 0, '-7') or { panic(err) }
	check[AliasInt](?AliasInt(AliasInt(7)), '?x', 0, '7') or { panic(err) }
	check[u64](?u64(~u64(0)), '?X', 0, 'FFFFFFFFFFFFFFFF') or { panic(err) }
	check[bool](?bool(true), 'any', 0, 'true') or { panic(err) }
	check[f32](?f32(f32(1.25)), '?e', 0, '1.25e0') or { panic(err) }
	check[f64](?f64(f64(1.25)), '?X', 0, '0x1.4p0') or { panic(err) }
	check[[]u8](?[]u8([u8(0), 255]), '?x', 0, '00ff') or { panic(err) }
	check[AliasBytes](?AliasBytes(AliasBytes([u8(65), 66])), '?s', 0, 'AB') or { panic(err) }
	fixed := [i16(-1), 2]!
	check[[2]i16](fixed, '?any', 1, '{ -1, 2 }') or { panic(err) }
	optional_bytes := [?u8(7), ?u8(none), ?u8(255)]!
	check[OptionalByteArray](optional[OptionalByteArray](optional_bytes), '?any', 1,
		'{ 7, null, 255 }') or { panic(err) }
	check[Tag](?Tag(Tag.high), '?t', 0, 'high') or { panic(err) }
	record := Record{?int(3), ?[]u8([u8(1), 2])}
	check[Record](record, '?any', 2, '.{ .n = 3, .bytes = { 1, 2 } }') or { panic(err) }
	check[AliasRecord](AliasRecord(record), 'any', 0, '.{ ... }') or { panic(err) }
	items := OptionalItems([?int(7), ?int(none)])
	check[OptionalItems](items, '?any', 1, '{ 7, null }') or { panic(err) }
	address := unsafe { &u32(uint(40)) }
	check[&u32](address, '?*', 0, 'u32@28') or { panic(err) }
	mut bytes := []u8{len: 64}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_value('*', zigimg.FormatOptions{}, ?&u32(address), 0) or { panic(err) }
	assert writer.buffered().bytestr() == '*u32@28'
}
