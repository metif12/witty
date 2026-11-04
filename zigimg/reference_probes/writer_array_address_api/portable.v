module main

import zigimg as p

type Bytes = [3]u8
type Word = int
type Words = [3]Word

struct Record {
	value int
}

fn borrowed[E](_ E, address usize, length int) []E {
	return unsafe { array{ data: voidptr(address), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn test_direct_array_pointer_addresses_never_read_pointees() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	writer.print_address(unsafe { &Bytes(voidptr(usize(0x1234))) })!
	writer.print_address(unsafe { &[2][3]int(usize(0)) })!
	writer.print_address(unsafe { &Words(voidptr(~usize(0))) })!
	assert writer.buffered().bytestr() == '[3]u8@1234[2][3]i32@0[3]i32@ffffffffffffffff'
}

fn test_direct_array_slices_keep_original_storage_and_ignore_length() ! {
	mut buffer := []u8{len: 256}
	mut writer := p.WriteStream.init_memory(mut buffer)
	values := [[u8(1), 2, 3]!, [u8(4), 5, 6]!]
	address := usize(values.data)
	writer.print_address(values)!
	assert writer.buffered().bytestr() == '[3]u8@${address:x}'
	writer.seek_to(0)!
	witness := [i16(0), 0]!
	for length in [0, 1, 3] {
		view := borrowed(witness, usize(0x1234), length)
		writer.print_address(view)!
		assert usize(view.data) == 0x1234 && view.len == length
	}
	assert writer.buffered().bytestr() == '[2]i16@1234[2]i16@1234[2]i16@1234'
	writer.seek_to(0)!
	writer.print_address(borrowed(witness, usize(0), 0))!
	assert writer.buffered().bytestr() == '[2]i16@0'
}

fn test_direct_array_address_failures_preserve_type_and_digit_order() ! {
	expected := '[2][3]i32@1234'
	witness := [[int(0), 0, 0]!, [int(0), 0, 0]!]!
	for capacity in 0 .. expected.len + 2 {
		for carrier in 0 .. 2 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := p.WriteStream.init_memory(mut buffer)
			mut status := 'ok'
			if carrier == 0 {
				writer.print_address(unsafe { &[2][3]int(usize(0x1234)) }) or { status = err.msg() }
			} else {
				writer.print_address(borrowed(witness, usize(0x1234), 0)) or { status = err.msg() }
			}
			assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
			assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
				capacity
			} else {
				expected.len
			}]
		}
	}
}

fn test_direct_unsupported_array_elements_fail_before_writes() ! {
	mut buffer := []u8{len: 128, init: 0xa5}
	before := buffer.clone()
	mut writer := p.WriteStream.init_memory(mut buffer)
	value := [Record{7}]!
	mut rejected := false
	writer.print_address(&value) or {
		assert err.msg() == 'unsupported print_value array-pointer address element'
		rejected = true
	}
	assert rejected && writer.buffered().len == 0 && buffer == before
	rejected = false
	writer.print_address([value]) or {
		assert err.msg() == 'unsupported print_value array-pointer address element'
		rejected = true
	}
	assert rejected && writer.buffered().len == 0 && buffer == before
}

fn main() {
	test_direct_array_pointer_addresses_never_read_pointees() or { panic(err) }
	test_direct_array_slices_keep_original_storage_and_ignore_length() or { panic(err) }
	test_direct_array_address_failures_preserve_type_and_digit_order() or { panic(err) }
	test_direct_unsupported_array_elements_fail_before_writes() or { panic(err) }
}
