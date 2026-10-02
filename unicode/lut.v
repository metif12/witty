module unicode

// Three-stage Unicode lookup-table generation.
//
// Translated from Ghostty's src/unicode/lut.zig. Zig exposes Generator and
// Tables as comptime type factories; V expresses the same two types with
// generics. Generated arrays are V-managed instead of accepting an explicit
// allocator.

import io

const lut_block_size = 256
const lut_codepoint_count = 0x200000

// LutGenerator builds a deduplicated three-stage table. Context must provide:
//
//   get(codepoint u32) !T
//   eql(a T, b T) bool
pub struct LutGenerator[T, U] {
pub:
	ctx U
}

// generate visits the complete u21 domain, interns result values in stage 3,
// interns 256-entry blocks in stage 2, and maps every high byte through stage
// 1. The resulting indexing expression is identical to Ghostty's table.
pub fn (self &LutGenerator[T, U]) generate() !LutTables[T] {
	mut block_indices := map[string]u16{}
	mut stage1 := []u16{cap: lut_codepoint_count / lut_block_size}
	mut stage2 := []u16{}
	mut stage3 := []T{}
	mut block := [lut_block_size]u16{}
	mut block_len := 0

	for cp in 0 .. lut_codepoint_count {
		elem := self.ctx.get(u32(cp))!
		mut elem_index := -1
		for i, item in stage3 {
			if self.ctx.eql(item, elem) {
				elem_index = i
				break
			}
		}
		if elem_index < 0 {
			if stage3.len > int(max_u16) {
				return error('BlockTooLarge')
			}
			elem_index = stage3.len
			stage3 << elem
		}

		block[block_len] = u16(elem_index)
		block_len++
		if block_len < lut_block_size && cp != lut_codepoint_count - 1 {
			continue
		}
		for i in block_len .. lut_block_size {
			block[i] = 0
		}

		key := lut_block_key(block)
		if existing := block_indices[key] {
			stage1 << existing
		} else {
			if stage2.len > int(max_u16) {
				return error('Stage2TooLarge')
			}
			index := u16(stage2.len)
			block_indices[key] = index
			stage1 << index
			stage2 << block[..block_len]
		}
		block_len = 0
	}

	assert stage1.len <= int(max_u16)
	assert stage2.len <= int(max_u16)
	assert stage3.len <= int(max_u16)
	return LutTables[T]{
		stage1: stage1
		stage2: stage2
		stage3: stage3
	}
}

fn lut_block_key(block [lut_block_size]u16) string {
	mut bytes := []u8{len: lut_block_size * 2}
	for i, value in block {
		bytes[i * 2] = u8(value)
		bytes[i * 2 + 1] = u8(value >> 8)
	}
	return bytes.bytestr()
}

// LutTables is the generated three-stage lookup table.
pub struct LutTables[T] {
pub:
	stage1 []u16
	stage2 []u16
	stage3 []T
}

// get returns the mapping for a u21 codepoint.
@[direct_array_access; inline]
pub fn (self &LutTables[T]) get(cp u32) T {
	assert cp < lut_codepoint_count
	high := cp >> 8
	low := cp & 0xff
	return self.stage3[self.stage2[self.stage1[high] + low]]
}

// write_zig emits the same generated Zig type factory as Ghostty's writeZig.
pub fn (self &LutTables[T]) write_zig(mut writer io.Writer) ! {
	lut_write_all(mut writer, ('//! This file is auto-generated. Do not edit.\n\n'
		+ 'pub fn Tables(comptime Elem: type) type {\n'
		+ '    return struct {\n'
		+ 'pub const stage1: [${self.stage1.len}]u16 = .{').bytes())!
	for entry in self.stage1 {
		lut_write_all(mut writer, '${entry},'.bytes())!
	}

	lut_write_all(mut writer, ('\n};\n\npub const stage2: [${self.stage2.len}]u16 = .{').bytes())!
	for entry in self.stage2 {
		lut_write_all(mut writer, '${entry},'.bytes())!
	}
	lut_write_all(mut writer, '};'.bytes())!

	lut_write_all(mut writer, ('\npub const stage3: [${self.stage3.len}]Elem = .{').bytes())!
	for entry in self.stage3 {
		lut_write_all(mut writer, '${lut_zig_value(entry)},'.bytes())!
	}
	lut_write_all(mut writer, '};\n    };\n}\n'.bytes())!
}

fn lut_zig_value[T](value T) string {
	$if T is $struct {
		$for method in T.methods {
			$if method.name == 'zig_format' && method.return_type is string {
				return value.zig_format()
			}
		}
		return '${value}'
	} $else $if T is $enum {
		return '.${value}'
	} $else $if T is string {
		return "\"${value}\""
	} $else {
		return '${value}'
	}
}

fn lut_write_all(mut writer io.Writer, data []u8) ! {
	mut offset := 0
	for offset < data.len {
		written := writer.write(data[offset..])!
		if written <= 0 || written > data.len - offset {
			return error('lookup-table writer returned an invalid byte count')
		}
		offset += written
	}
}
