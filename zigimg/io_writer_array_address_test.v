module zigimg

type ArrayAddressBytes = [3]u8
type ArrayAddressWord = int
type ArrayAddressWords = [3]ArrayAddressWord

struct ArrayAddressArgs {
	value &ArrayAddressBytes
}

struct ArrayAddressRecord {
	value int
}

fn test_array_address_prefixes_do_not_read_zero_or_synthetic_pointers() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	options := FormatOptions{ width: ~usize(0), precision: ~usize(0), fill: 0xff }
	writer.print_value('*', options, unsafe { &ArrayAddressBytes(voidptr(usize(0x1234))) }, 0)!
	writer.print_value('*', options, unsafe { &[1]f64(~usize(0)) }, ~usize(0))!
	writer.print_value('*', options, unsafe { &[2][3]int(usize(0)) }, 0)!
	writer.print_value('*', options, unsafe { &ArrayAddressWords(voidptr(usize(1))) }, 0)!
	assert writer.buffered().bytestr() == '[3]u8@1234[1]f64@ffffffffffffffff[2][3]i32@0[3]i32@1'
}

fn test_array_address_uses_owned_pointee_address_and_composes_in_print() ! {
	mut buffer := []u8{len: 256}
	mut writer := WriteStream.init_memory(mut buffer)
	value := ArrayAddressBytes([u8(0), 255, 65]!)
	address := unsafe { usize(voidptr(&value)) }
	writer.print_value('*', FormatOptions{}, &value, 0)!
	assert writer.buffered().bytestr() == '[3]u8@${address:x}'
	writer.seek_to(0)!
	writer.print('a{*}b', ArrayAddressArgs{unsafe { &ArrayAddressBytes(voidptr(usize(0x1234))) }})!
	writer.print_value('x', FormatOptions{}, &value, 0)!
	assert writer.buffered().bytestr() == 'a[3]u8@1234b00ff41'
}

fn test_array_address_partial_writes_keep_type_and_digits_order() ! {
	expected := '[2][3]i32@1234'
	for capacity in 0 .. expected.len + 2 {
		mut buffer := []u8{len: capacity, init: 0xa5}
		mut writer := WriteStream.init_memory(mut buffer)
		mut status := 'ok'
		writer.print_value('*', FormatOptions{ width: ~usize(0) }, unsafe { &[2][3]int(usize(0x1234)) }, 0) or {
			status = err.msg()
		}
		assert status == if capacity < expected.len { 'WriteFailed' } else { 'ok' }
		assert writer.buffered().bytestr() == expected[..if capacity < expected.len {
			capacity
		} else {
			expected.len
		}]
	}
}

fn test_unsupported_array_address_elements_fail_before_writes() ! {
	mut buffer := []u8{len: 128, init: 0xa5}
	before := buffer.clone()
	mut writer := WriteStream.init_memory(mut buffer)
	value := [ArrayAddressRecord{7}]!
	mut rejected := false
	writer.print_value('*', FormatOptions{}, &value, 0) or {
		assert err.msg() == 'unsupported print_value array-pointer address element'
		rejected = true
	}
	assert rejected && writer.buffered().len == 0 && buffer == before
}
