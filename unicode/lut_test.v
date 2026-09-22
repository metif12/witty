module unicode

struct LutParityContext {}

fn (_ LutParityContext) get(cp u32) !u8 {
	return u8((cp >> 8) & 1)
}

fn (_ LutParityContext) eql(a u8, b u8) bool {
	return a == b
}

struct LutTestWriter {
mut:
	data []u8
}

fn (mut self LutTestWriter) write(data []u8) !int {
	self.data << data
	return data.len
}

fn test_lut_generator_deduplicates_values_and_blocks() {
	tables := LutGenerator[u8, LutParityContext]{
		ctx: LutParityContext{}
	}.generate()!
	assert tables.stage1.len == 8192
	assert tables.stage2.len == 512
	assert tables.stage3 == [u8(0), 1]
	assert tables.get(0) == 0
	assert tables.get(0xff) == 0
	assert tables.get(0x100) == 1
	assert tables.get(0x200) == 0
	assert tables.get(0x1fffff) == 1
}

fn test_lut_tables_write_zig() {
	tables := LutTables[bool]{
		stage1: [u16(0)]
		stage2: [u16(0)]
		stage3: [true]
	}
	mut writer := LutTestWriter{}
	tables.write_zig(mut writer)!
	output := writer.data.bytestr()
	expected := '//! This file is auto-generated. Do not edit.\n\npub fn Tables(comptime Elem: type) type {\n    return struct {\npub const stage1: [1]u16 = .{\n0,\n};\n\npub const stage2: [1]u16 = .{\n0,};\n\npub const stage3: [1]Elem = .{\ntrue,};\n    };\n}\n'
	assert output == expected

	property_tables := LutTables[Properties]{
		stage1: [u16(0)]
		stage2: [u16(0)]
		stage3: [Properties.from_int(u8(1 | (u8(GraphemeBreak.zwj) << 2) | 0x80))]
	}
	mut property_writer := LutTestWriter{}
	property_tables.write_zig(mut property_writer)!
	property_output := property_writer.data.bytestr()
	assert property_output.contains('.width= 1,')
	assert property_output.contains('.grapheme_break= .zwj,')
	assert property_output.contains('.emoji_vs_base= true,')
}
