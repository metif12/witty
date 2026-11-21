module main

import zigimg

type Byte = u8
type Bytes = [3]Byte
type Element = i16
type Row = [2]Element
type Grid = [2]Row

fn main() {
	mut bytes := []u8{len: 256}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	mut grid := Grid{}
	grid[0] = Row([Element(-12), 3]!)
	grid[1] = Row([Element(0), -4]!)
	writer.print_value('any', zigimg.FormatOptions{ width: uint(4), fill: `_` }, grid, 2)!
	writer.write_byte(`|`)!
	value := Bytes([Byte(0), 127, 255]!)
	writer.print_value('b64', zigimg.FormatOptions{}, value, 0)!
	writer.write_byte(`|`)!
	writer.print_value('any', zigimg.FormatOptions{ width: ~uint(0), precision: ~uint(0) }, [
		[true, false]!,
		[false, true]!,
	]!, 1)!
	assert writer.buffered().bytestr() == '{ { _-12, __+3 }, { __+0, __-4 } }|AH//|{ { ... }, { ... } }'
}
