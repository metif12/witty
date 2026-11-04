module main

import zigimg as p

type PointerVectorBase = int
type PointerVectorAlias = &PointerVectorBase
type PointerVectorArray = [3]PointerVectorAlias

fn test_vector_pointer_options_aliases_and_opaque_lanes() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	pointer := unsafe { &u8(usize(0x12)) }
	writer.print_vector('any', p.FormatOptions{ width: usize(4), precision: ~usize(0), fill: `_` }, [
		pointer,
		pointer,
	]!, 1)!
	writer.write_byte(`|`)!
	alias_pointer := PointerVectorAlias(unsafe { &PointerVectorBase(voidptr(usize(0x34))) })
	writer.print_vector('', p.FormatOptions{}, PointerVectorArray([alias_pointer, alias_pointer,
		alias_pointer]!), ~usize(0))!
	writer.write_byte(`|`)!
	writer.print_vector('any', p.FormatOptions{}, [voidptr(usize(0)), voidptr(usize(0x56))]!, 1)!
	assert writer.buffered().bytestr() == '{ u8@__12, u8@__12 }|{ i32@34, i32@34, i32@34 }|{ anyopaque@0, anyopaque@56 }'
}

fn test_vector_optional_pointers_preserve_presence_and_address_format() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	present := ?&u8(unsafe { &u8(usize(0x10)) })
	absent := ?&u8(none)
	lanes := [present, absent, present]!
	writer.print_vector('any', p.FormatOptions{ width: usize(6), fill: `_` }, lanes, 1)!
	writer.write_byte(`|`)!
	writer.print_vector('*', p.FormatOptions{ width: ~usize(0), precision: ~usize(0) }, lanes, 1)!
	writer.write_byte(`|`)!
	writer.print_vector('?*', p.FormatOptions{}, lanes, 1)!
	assert writer.buffered().bytestr() == '{ u8@____10, __null, u8@____10 }|{ *u8@10, *u8@0, *u8@10 }|{ u8@10, null, u8@10 }'
}

fn test_vector_pointer_alias_and_optional_same_base_compile_together() ! {
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	alias_pointer := PointerVectorAlias(unsafe { &PointerVectorBase(voidptr(usize(0x20))) })
	present := ?&int(unsafe { &int(usize(0x30)) })
	absent := ?&int(none)
	writer.print_vector('any', p.FormatOptions{}, [alias_pointer, alias_pointer]!, 1)!
	writer.print_vector('any', p.FormatOptions{}, [present, absent]!, 1)!
	assert writer.buffered().bytestr() == '{ i32@20, i32@20 }{ i32@30, null }'
}

fn test_vector_pointer_partial_writes_include_leaf_and_separator_boundaries() ! {
	expected := '{ u8@__12, u8@__12 }'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := p.WriteStream.init_memory(mut buffer)
		pointer := unsafe { &u8(usize(0x12)) }
		mut status := 'ok'
		writer.print_vector('any', p.FormatOptions{ width: usize(4), fill: `_` }, [
			pointer,
			pointer,
		]!, 1) or { status = err.msg() }
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
}

fn test_vector_pointer_depth_and_invalid_leaf_keep_source_order() ! {
	mut buffer := []u8{len: 128}
	mut writer := p.WriteStream.init_memory(mut buffer)
	pointer := unsafe { &u8(usize(0)) }
	writer.print_vector('invalid', p.FormatOptions{ width: ~usize(0) }, [pointer, pointer]!, 0)!
	writer.print_vector('d', p.FormatOptions{}, [pointer, pointer]!, 1) or {
		assert err.msg() == 'unsupported print_value pointer format'
		assert writer.buffered().bytestr() == '{ ... }{ '
		return
	}
	assert false
}

fn run() ! {
	test_vector_pointer_options_aliases_and_opaque_lanes()!
	test_vector_optional_pointers_preserve_presence_and_address_format()!
	test_vector_pointer_alias_and_optional_same_base_compile_together()!
	test_vector_pointer_partial_writes_include_leaf_and_separator_boundaries()!
	test_vector_pointer_depth_and_invalid_leaf_keep_source_order()!
}

fn main() { run() or { panic(err) } }
