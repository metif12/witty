module zigimg

struct HookValue {
	value int
	stop  bool
}

fn (value HookValue) format_number(mut writer WriteStream, options NumberFormat) ! {
	writer.write_all('number:'.bytes())!
	if value.stop { return error_with_code('HookStopped', 47) }
	precision := if n := options.precision { '${n}' } else { '-' }
	width := if n := options.width { '${n}' } else { '-' }
	writer.write_all('${int(options.mode)},${int(options.letter_case)},${precision},${width},${int(options.alignment)},${options.fill}:${value.value}'.bytes())!
}

fn (value HookValue) format_byte_size(mut writer WriteStream, units ByteSizeUnits) ! {
	writer.write_all('bytes:'.bytes())!
	if value.stop { return error_with_code('HookStopped', 47) }
	writer.write_all('${int(units)}:${value.value}'.bytes())!
}

fn (value HookValue) format_duration(mut writer WriteStream) ! {
	writer.write_all('duration:'.bytes())!
	if value.stop { return error_with_code('HookStopped', 47) }
	writer.write_all('${value.value}'.bytes())!
}

type HookAlias = HookValue

struct HookArgs {
	value HookValue
}

fn test_numeric_hook_receives_exact_number_options_before_depth_cutoff() {
	formats := ['d', 'b', 'o', 'x', 'X', 'e', 'E']
	modes := [0, 1, 2, 3, 3, 4, 4]
	for i, format in formats {
		mut buffer := []u8{len: 128}
		mut writer := WriteStream.init_memory(mut buffer)
		options := FormatOptions{ precision: ~usize(0), width: usize(0), alignment: .center, fill: 255 }
		writer.print_value(format, options, HookValue{-7, false}, 0)!
		letter_case := if format in ['X', 'E'] { 1 } else { 0 }
		assert writer.buffered().bytestr() == 'number:${modes[i]},${letter_case},${~usize(0)},0,1,255:-7'
		assert options.width == ?usize(0) && options.precision == ?usize(~usize(0))
	}
}

fn test_unit_hooks_ignore_options_and_depth_and_forward_units() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	options := FormatOptions{ precision: ~usize(0), width: ~usize(0), fill: 255 }
	writer.print_value('B', options, HookValue{7, false}, 0)!
	writer.print_value('Bi', options, HookValue{8, false}, ~usize(0))!
	writer.print_value('D', options, HookValue{-9, false}, 0)!
	assert writer.buffered().bytestr() == 'bytes:0:7bytes:1:8duration:-9'
}

fn test_hooks_accept_aliases_optionals_and_print_arguments() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('d', FormatOptions{}, HookAlias(HookValue{1, false}), 0)!
	writer.print_value('?D', FormatOptions{}, ?HookValue(HookValue{2, false}), 0)!
	writer.print_value('?B', FormatOptions{}, ?HookValue(none), 0)!
	writer.print('{X}', HookArgs{HookValue{3, false}})!
	assert writer.buffered().bytestr() == 'number:0,0,-,-,2,32:1duration:2nullnumber:3,1,-,-,2,32:3'
}

fn test_hook_failures_preserve_error_and_partial_writes() {
	for format in ['d', 'B', 'Bi', 'D'] {
		for capacity in 0 .. 10 {
			mut buffer := []u8{len: capacity, init: 0xa5}
			mut writer := WriteStream.init_memory(mut buffer)
			prefix := if format == 'd' {
				'number:'
			} else if format == 'D' {
				'duration:'
			} else {
				'bytes:'
			}
			mut failed := false
			writer.print_value(format, FormatOptions{}, HookValue{7, true}, 0) or {
				failed = true
				assert err.msg() == if capacity < prefix.len {
					'WriteFailed'
				} else {
					'HookStopped'
				}
				if capacity >= prefix.len {
					assert err.code() == 47
				}
			}
			assert failed
			assert writer.buffered().bytestr() == prefix[..if capacity < prefix.len {
				capacity
			} else {
				prefix.len
			}]
		}
	}
}

fn test_default_and_any_bypass_hooks_and_fixed_arrays_stay_intact() {
	mut buffer := []u8{len: 128}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('', FormatOptions{}, HookValue{7, true}, 1)!
	writer.print_value('any', FormatOptions{}, HookAlias(HookValue{8, true}), 0)!
	writer.print_value('any', FormatOptions{}, [u8(1), 255]!, 1)!
	assert writer.buffered().bytestr() == '.{ .value = 7, .stop = true }.{ ... }{ 1, 255 }'
}

enum HookEnum {
	first
	second
}

fn (value HookEnum) format_number(mut writer WriteStream, options NumberFormat) ! {
	writer.write_all('unexpected'.bytes())!
}

fn test_numeric_enum_dispatch_ignores_record_hooks() {
	mut buffer := []u8{len: 32}
	mut writer := WriteStream.init_memory(mut buffer)
	writer.print_value('X', FormatOptions{}, HookEnum.second, 0)!
	assert writer.buffered().bytestr() == '1'
}
