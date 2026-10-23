module main

import zigimg

type Element = i16
type Slice = []Element
type Nested = []Slice

fn main() {
	mut bytes := []u8{len: 128}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	values := Nested([Slice([Element(-12), 3]), Slice([]Element{})])
	writer.print_value('any', zigimg.FormatOptions{ width: usize(4), fill: `_` }, values, 2) or {
		panic(err)
	}
	writer.write_byte(`|`) or { panic(err) }
	writer.print_value('any', zigimg.FormatOptions{ width: ~usize(0), precision: ~usize(0) },
		[][]bool{len: 2}, 1) or { panic(err) }
	assert writer.buffered().bytestr() == '{ { _-12, __+3 }, {  } }|{ { ... }, { ... } }'
}
