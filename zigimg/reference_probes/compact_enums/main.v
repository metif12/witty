module main

import os
import strings
import zigimg as p

struct PostAlignment {
	marker u8
	value  p.PostConversionBehavior
}

struct FormatAlignment {
	marker u8
	value  p.NetpbmFormat
}

struct TupleAlignment {
	marker u8
	value  p.PamTupleType
}

fn bytes[T](values []T) []u8 {
	mut result := []u8{}
	unsafe {
		result.data = values.data
		result.len = values.len * int(sizeof(T))
		result.cap = result.len
		result.flags = .nofree
	}
	return result
}

fn emit[T](mut output strings.Builder, values []T) {
	output.write_string(bytes(values).hex() + '|')
	for value in values {
		output.write_string('${value},${u8(value)};')
	}
	output.write_string('|')
}

fn changed[T](_ T, raw u8) T {
	return unsafe { T(raw) }
}

fn run[T](mut output strings.Builder, mut values []T, seed int, variants int, alignment u32) {
	for index in 0 .. values.len {
		values[index] = unsafe { T((index + seed) % variants) }
	}
	mut copy := values.clone()
	mut original := unsafe { T(seed % variants) }
	returned := changed(original, u8((seed + 1) % variants))
	old := original
	original = returned
	output.write_string('${sizeof(T)},${alignment}|${old},${u8(old)},${original},${u8(original)},${returned},${u8(returned)}|')
	emit(mut output, values)
	emit(mut output, copy)
	if values.len != 0 {
		index := seed % values.len
		values[index] = unsafe { T((seed + 1) % variants) }
		mut view := bytes(copy)
		view[index] = u8((seed + 2) % variants)
	}
	emit(mut output, values)
	emit(mut output, copy)
}

fn main() {
	if os.args[1] == 'pam' {
		for value in [p.PamTupleType.mono, .mono_a, .gray, .gray_a, .rgb, .rgb_a] {
			println('${sizeof(p.PamTupleType)},${__offsetof(TupleAlignment, value)}|${value},${u8(value)}|${bytes([
				value,
			]).hex()}')
		}
		return
	}
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		count := fields[1].int()
		seed := fields[2].int()
		if fields[0] == '0' {
			mut values := []p.PostConversionBehavior{len: count}
			run(mut output, mut values, seed, 2, __offsetof(PostAlignment, value))
		} else {
			mut values := []p.NetpbmFormat{len: count}
			run(mut output, mut values, seed, 3, __offsetof(FormatAlignment, value))
		}
		output.write_string('\n')
	}
	print(output.str())
}
