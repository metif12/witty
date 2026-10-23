module main

import zigimg

enum Closed0 as u8 {
	first    = 0
	second   = 2
	third    = 131
	long_tag = 255
}

enum Closed1 as u16 {
	first    = 0
	second   = 2
	third    = 32771
	long_tag = 65535
}

enum Closed2 as u32 {
	first    = 0
	second   = 2
	third    = 2147483651
	long_tag = 4294967295
}

enum Closed3 as u64 {
	first    = 0
	second   = 2
	third    = 9223372036854775811
	long_tag = 18446744073709551615
}

enum Closed4 as i8 {
	first    = -128
	second   = -3
	third    = 0
	long_tag = 126
}

enum Closed5 as i16 {
	first    = -32768
	second   = -3
	third    = 0
	long_tag = 32766
}

enum Closed6 {
	first    = -2147483648
	second   = -3
	third    = 0
	long_tag = 2147483646
}

enum Closed7 as i64 {
	first    = -9223372036854775808
	second   = -3
	third    = 0
	long_tag = 9223372036854775806
}

@[nonexhaustive]
enum Open0 as u8 {
	first    = 0
	second   = 2
	third    = 131
	long_tag = 255
}

@[nonexhaustive]
enum Open1 as u16 {
	first    = 0
	second   = 2
	third    = 32771
	long_tag = 65535
}

@[nonexhaustive]
enum Open2 as u32 {
	first    = 0
	second   = 2
	third    = 2147483651
	long_tag = 4294967295
}

@[nonexhaustive]
enum Open3 as u64 {
	first    = 0
	second   = 2
	third    = 9223372036854775811
	long_tag = 18446744073709551615
}

@[nonexhaustive]
enum Open4 as i8 {
	first    = -128
	second   = -3
	third    = 0
	long_tag = 126
}

@[nonexhaustive]
enum Open5 as i16 {
	first    = -32768
	second   = -3
	third    = 0
	long_tag = 32766
}

@[nonexhaustive]
enum Open6 {
	first    = -2147483648
	second   = -3
	third    = 0
	long_tag = 2147483646
}

@[nonexhaustive]
enum Open7 as i64 {
	first    = -9223372036854775808
	second   = -3
	third    = 0
	long_tag = 9223372036854775806
}
type AliasClosed0 = Closed0
type AliasClosed1 = Closed1
type AliasClosed2 = Closed2
type AliasClosed3 = Closed3
type AliasClosed4 = Closed4
type AliasClosed5 = Closed5
type AliasClosed6 = Closed6
type AliasClosed7 = Closed7
type AliasOpen0 = Open0
type AliasOpen1 = Open1
type AliasOpen2 = Open2
type AliasOpen3 = Open3
type AliasOpen4 = Open4
type AliasOpen5 = Open5
type AliasOpen6 = Open6
type AliasOpen7 = Open7

fn check[T](value T, name string) ! {
	mut bytes := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	for format in ['', 'any', 't', 'd', 'b', 'o', 'x', 'X'] {
		writer.print_value(format, zigimg.FormatOptions{}, value, 0)!
		writer.write_byte(`|`)!
	}
	assert writer.buffered().bytestr() == '.${name}|.${name}|${name}|0|0|0|0|0|'
}

fn main() {
	check(Closed0.first, 'first')!
	check(Closed1.first, 'first')!
	check(Closed2.first, 'first')!
	check(Closed3.first, 'first')!
	check(Closed4.third, 'third')!
	check(Closed5.third, 'third')!
	check(Closed6.third, 'third')!
	check(Closed7.third, 'third')!
	check(Open0.first, 'first')!
	check(Open1.first, 'first')!
	check(Open2.first, 'first')!
	check(Open3.first, 'first')!
	check(Open4.third, 'third')!
	check(Open5.third, 'third')!
	check(Open6.third, 'third')!
	check(Open7.third, 'third')!
	check(AliasClosed0(Closed0.first), 'first')!
	check(AliasClosed1(Closed1.first), 'first')!
	check(AliasClosed2(Closed2.first), 'first')!
	check(AliasClosed3(Closed3.first), 'first')!
	check(AliasClosed4(Closed4.third), 'third')!
	check(AliasClosed5(Closed5.third), 'third')!
	check(AliasClosed6(Closed6.third), 'third')!
	check(AliasClosed7(Closed7.third), 'third')!
	check(AliasOpen0(Open0.first), 'first')!
	check(AliasOpen1(Open1.first), 'first')!
	check(AliasOpen2(Open2.first), 'first')!
	check(AliasOpen3(Open3.first), 'first')!
	check(AliasOpen4(Open4.third), 'third')!
	check(AliasOpen5(Open5.third), 'third')!
	check(AliasOpen6(Open6.third), 'third')!
	check(AliasOpen7(Open7.third), 'third')!
	mut bytes := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	writer.print_value('any', zigimg.FormatOptions{}, [AliasClosed0(Closed0.first),
		AliasClosed0(Closed0.second)]!, 1)!
	writer.write_byte(`|`)!
	writer.print_value('any', zigimg.FormatOptions{}, [[Open7.third],
		[Open7.third]], 2)!
	writer.write_byte(`|`)!
	writer.print_value('', zigimg.FormatOptions{}, unsafe { AliasOpen7(i64(-1)) }, 0)!
	assert writer.buffered().bytestr() == '{ .first, .second }|{ { .third }, { .third } }|@enumFromInt(-1)'
}
